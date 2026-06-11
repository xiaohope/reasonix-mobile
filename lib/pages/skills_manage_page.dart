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
  Future<void> _importSkillFile() async {
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
              Text(
                '粘贴 .skill.md 文件的内容：',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                maxLines: 10,
                minLines: 6,
                decoration: const InputDecoration(
                  hintText: '---\nname: 技能名称\ndescription: ...\nicon: 🔍\n---\n\n指令内容...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('导入'),
          ),
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
