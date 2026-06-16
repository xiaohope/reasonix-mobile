import 'dart:io';
import 'package:flutter/material.dart';
import '../models/skill.dart';
import '../services/skill_service.dart';

/// 技能管理页面 — 查看、添加、编辑、删除、重置技能
class SkillsManagePage extends StatefulWidget {
  final SkillService skillService;
  const SkillsManagePage({super.key, required this.skillService});

  @override
  State<SkillsManagePage> createState() => _SkillsManagePageState();
}

class _SkillsManagePageState extends State<SkillsManagePage> {
  List<Skill> _skills = [];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    await widget.skillService.init();
    setState(() {
      _skills = widget.skillService.skills;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('技能管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open_outlined),
            tooltip: '导入 .skill.md 文件',
            onPressed: _importSkillFile,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: '恢复默认',
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _skills.isEmpty
              ? const Center(child: Text('暂无技能'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _skills.length,
                  itemBuilder: (context, index) {
                    final skill = _skills[index];
                    return Card(
                      child: ListTile(
                        leading: Text(skill.icon ?? '🧠', style: const TextStyle(fontSize: 28)),
                        title: Text(skill.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(skill.description, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              skill.prompt.length > 60
                                  ? '${skill.prompt.substring(0, 60)}...'
                                  : skill.prompt,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _editSkill(skill);
                            } else if (value == 'delete') {
                              await _deleteSkill(skill);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'edit', child: ListTile(
                              leading: Icon(Icons.edit, size: 20),
                              title: Text('编辑', style: TextStyle(fontSize: 14)),
                              dense: true,
                            )),
                            const PopupMenuItem(value: 'delete', child: ListTile(
                              leading: Icon(Icons.delete, size: 20, color: Colors.red),
                              title: Text('删除', style: TextStyle(fontSize: 14, color: Colors.red)),
                              dense: true,
                            )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSkill(),
        icon: const Icon(Icons.add),
        label: const Text('新建技能'),
      ),
    );
  }

  /// 导入 .skill.md 文件 — 粘贴 markdown 内容，自动解析并保存
  /// 文件浏览器 — 选择 .skill.md 文件
  Future<String?> _pickSkillFile() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _SkillFilePicker(initialPath: '/storage/emulated/0'),
      ),
    );
    return result;
  }

  Future<void> _importSkillFile() async {
    // 选择导入方式
    final method = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('浏览文件'),
            subtitle: const Text('从手机目录选择 .skill.md 文件'),
            onTap: () => Navigator.pop(ctx, 'file'),
          ),
          ListTile(
            leading: const Icon(Icons.content_paste),
            title: const Text('粘贴内容'),
            subtitle: const Text('手动粘贴 .skill.md 内容'),
            onTap: () => Navigator.pop(ctx, 'paste'),
          ),
        ]),
      ),
    );
    if (method == null) return;

    // ── 浏览文件 ──
    if (method == 'file') {
      final path = await _pickSkillFile();
      if (path == null) return;
      final file = File(path);
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final id = file.uri.pathSegments.last.replaceAll('.skill.md', '');
      Skill skill;
      try {
        skill = Skill.fromMarkdown(content, id: id);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ 解析失败: $e')));
        return;
      }
      if (skill.name.isEmpty || skill.prompt.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ 缺少 name 或 prompt')));
        return;
      }
      await widget.skillService.upsertSkill(skill);
      await _loadSkills();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ 已导入: ${skill.name}')));
      return;
    }

    // ── 粘贴内容 ──
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入 .skill.md'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('粘贴 .skill.md 文件的内容：', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl, maxLines: 10, minLines: 6,
                decoration: const InputDecoration(
                  hintText: '---\nname: 技能名称\ndescription: ...\nicon: 🔍\n---\n\n指令内容...',
                  border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: const Text('导入')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;

    // 尝试解析
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    Skill skill;
    try {
      skill = Skill.fromMarkdown(result, id: id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 解析失败，请检查格式: $e')),
      );
      return;
    }

    // 验证必填字段
    if (skill.name.isEmpty || skill.prompt.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ 缺少 name 或 prompt，请检查 frontmatter 格式')),
      );
      return;
    }

    await widget.skillService.upsertSkill(skill);
    await _loadSkills();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ 已导入: ${skill.name}')),
    );
  }

  Future<void> _addSkill() async {
    final result = await _showSkillDialog();
    if (result != null) {
      await widget.skillService.upsertSkill(result);
      await _loadSkills();
    }
  }

  Future<void> _editSkill(Skill skill) async {
    final result = await _showSkillDialog(existing: skill);
    if (result != null) {
      await widget.skillService.upsertSkill(result);
      await _loadSkills();
    }
  }

  Future<void> _deleteSkill(Skill skill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除技能'),
        content: Text('确定删除「${skill.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.skillService.deleteSkill(skill.id);
      await _loadSkills();
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认技能'),
        content: const Text('将删除所有自定义技能，恢复为 8 个默认技能。确定吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.skillService.resetToDefaults();
      await _loadSkills();
    }
  }

  /// 添加/编辑技能的对话框
  Future<Skill?> _showSkillDialog({Skill? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final promptCtrl = TextEditingController(text: existing?.prompt ?? '');
    final iconCtrl = TextEditingController(text: existing?.icon ?? '🧠');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? '编辑技能' : '新建技能'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: iconCtrl,
                decoration: const InputDecoration(
                  labelText: '图标（Emoji）',
                  hintText: '🔍 🐛 📖 🛠️',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLength: 6,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '代码审查',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: '描述',
                  hintText: '审查当前项目代码，找出问题',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: promptCtrl,
                decoration: const InputDecoration(
                  labelText: '指令内容（发给 AI 的 prompt）',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                minLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final prompt = promptCtrl.text.trim();
              if (name.isEmpty || prompt.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('名称和指令内容不能为空')),
                );
                return;
              }
              Navigator.of(ctx).pop({
                'icon': iconCtrl.text.trim(),
                'name': name,
                'description': descCtrl.text.trim(),
                'prompt': prompt,
              });
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == null) return null;

    final id = existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    return Skill(
      id: id,
      name: result['name']!,
      description: result['description'] ?? '',
      prompt: result['prompt']!,
      icon: result['icon']?.isNotEmpty == true ? result['icon'] : null,
    );
  }
}

/// 技能文件选择器
class _SkillFilePicker extends StatefulWidget {
  final String initialPath;
  const _SkillFilePicker({required this.initialPath});
  @override
  State<_SkillFilePicker> createState() => _SkillFilePickerState();
}

class _SkillFilePickerState extends State<_SkillFilePicker> {
  late String _currentPath;
  List<FileSystemEntity> _entries = [];

  @override
  void initState() { super.initState(); _currentPath = widget.initialPath; _load(); }

  void _load() {
    try {
      final dir = Directory(_currentPath);
      if (!dir.existsSync()) return;
      setState(() { _entries = dir.listSync()..sort((a, b) {
        final ad = a is Directory, bd = b is Directory;
        if (ad && !bd) return -1; if (!ad && bd) return 1;
        return a.path.compareTo(b.path);
      }); });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPath.split('/').last, style: const TextStyle(fontSize: 16)),
        actions: [
          if (_currentPath != '/')
            TextButton(onPressed: () { setState(() { _currentPath = Directory(_currentPath).parent.path; }); _load(); }, child: const Text('返回上级')),
        ],
      ),
      body: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), color: Theme.of(context).colorScheme.surface,
          child: Text(_currentPath, style: const TextStyle(fontFamily: 'monospace', fontSize: 12), overflow: TextOverflow.ellipsis)),
        Expanded(child: ListView.builder(itemCount: _entries.length, itemBuilder: (c, i) {
          final e = _entries[i];
          final name = e.uri.pathSegments.last;
          final isDir = e is Directory;
          final isSkillFile = name.endsWith('.skill.md');
          if (name.startsWith('.') || (isDir && (name == 'node_modules' || name == '.git' || name == '.dart_tool'))) return const SizedBox();
          return ListTile(dense: true,
            leading: Icon(isDir ? Icons.folder : (isSkillFile ? Icons.auto_awesome : Icons.insert_drive_file),
                size: 20,
                color: isDir ? const Color(0xFFF9E2AF) : (isSkillFile ? const Color(0xFF6C63FF) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))),
            title: Text(name, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            subtitle: isSkillFile ? const Text('点击导入此技能', style: TextStyle(fontSize: 11)) : null,
            trailing: isDir ? const Icon(Icons.chevron_right, size: 18) : null,
            onTap: () {
              if (isDir) { setState(() { _currentPath = e.path; }); _load(); }
              else if (isSkillFile) { Navigator.of(context).pop(e.path); }
            },
          );
        })),
      ]),
    );
  }
}
