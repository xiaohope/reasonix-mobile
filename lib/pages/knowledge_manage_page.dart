import 'package:flutter/material.dart';
import '../models/knowledge.dart';
import '../services/knowledge_service.dart';

/// 知识库管理页面 — 查看、添加、编辑、删除、导入知识条目
class KnowledgeManagePage extends StatefulWidget {
  final KnowledgeService service;
  const KnowledgeManagePage({super.key, required this.service});

  @override
  State<KnowledgeManagePage> createState() => _KnowledgeManagePageState();
}

class _KnowledgeManagePageState extends State<KnowledgeManagePage> {
  List<Knowledge> _items = [];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    await widget.service.init();
    setState(() {
      _items = widget.service.items;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('知识库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open_outlined),
            tooltip: '导入 .md 文件',
            onPressed: _importFile,
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('知识库为空', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _importFile,
                        icon: const Icon(Icons.file_open_outlined),
                        label: const Text('导入知识文件'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _items.length,
                  itemBuilder: (ctx, index) {
                    final item = _items[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.menu_book, color: Color(0xFF6C63FF)),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.description.isNotEmpty)
                              Text(item.description, style: const TextStyle(fontSize: 12)),
                            if (item.tags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: item.tags.split(',').map((t) => Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(t.trim(), style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.primary,
                                  )),
                                )).toList(),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '${item.content.length} 字',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') await _edit(item);
                            else if (v == 'delete') await _delete(item);
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'edit', child: ListTile(
                              leading: Icon(Icons.edit, size: 20), title: Text('编辑', style: TextStyle(fontSize: 14)), dense: true,
                            )),
                            const PopupMenuItem(value: 'delete', child: ListTile(
                              leading: Icon(Icons.delete, size: 20, color: Colors.red), title: Text('删除', style: TextStyle(fontSize: 14, color: Colors.red)), dense: true,
                            )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(),
        icon: const Icon(Icons.add),
        label: const Text('新建知识'),
      ),
    );
  }

  Future<void> _add() async {
    final result = await _showDialog();
    if (result != null) {
      await widget.service.upsert(result);
      await _load();
    }
  }

  Future<void> _edit(Knowledge item) async {
    final result = await _showDialog(existing: item);
    if (result != null) {
      await widget.service.upsert(result);
      await _load();
    }
  }

  Future<void> _delete(Knowledge item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除知识'),
        content: Text('确定删除「${item.title}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await widget.service.delete(item.id);
      await _load();
    }
  }

  Future<Knowledge?> _showDialog({Knowledge? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final tagsCtrl = TextEditingController(text: existing?.tags ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? '编辑知识' : '新建知识'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtrl,
              decoration: const InputDecoration(labelText: '标题', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: descCtrl,
              decoration: const InputDecoration(labelText: '描述', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: tagsCtrl,
              decoration: const InputDecoration(labelText: '标签（逗号分隔）', hintText: 'flutter, dart', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: contentCtrl,
              decoration: const InputDecoration(labelText: '正文内容', border: OutlineInputBorder(), alignLabelWithHint: true),
              maxLines: 8, minLines: 4),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('标题和正文不能为空')));
              return;
            }
            Navigator.pop(ctx, {
              'title': titleCtrl.text.trim(),
              'description': descCtrl.text.trim(),
              'tags': tagsCtrl.text.trim(),
              'content': contentCtrl.text.trim(),
            });
          }, child: const Text('保存')),
        ],
      ),
    );

    if (result == null) return null;
    final id = existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    return Knowledge(
      id: id,
      title: result['title']!,
      description: result['description'] ?? '',
      tags: result['tags'] ?? '',
      content: result['content']!,
    );
  }

  Future<void> _importFile() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入知识文件'),
        content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('粘贴 .md 文件的内容：', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          TextField(controller: ctrl, maxLines: 10, minLines: 6,
            decoration: const InputDecoration(
              hintText: '---\ntitle: 知识标题\ndescription: ...\ntags: ...\n---\n\n正文...',
              border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('导入')),
        ],
      ),
    );

    if (text == null || text.isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    Knowledge item;
    try { item = Knowledge.fromMarkdown(text, id: id); }
    catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ 解析失败: $e')));
      return;
    }
    if (item.title.isEmpty || item.content.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ 缺少 title 或正文')));
      return;
    }
    await widget.service.upsert(item);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ 已导入: ${item.title}')));
  }
}
