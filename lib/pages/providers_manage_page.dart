import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/model_provider.dart';

/// 大模型管理页面 — 添加/编辑/删除 Provider
class ProvidersManagePage extends StatefulWidget {
  const ProvidersManagePage({super.key});

  @override
  State<ProvidersManagePage> createState() => _ProvidersManagePageState();
}

class _ProvidersManagePageState extends State<ProvidersManagePage> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('大模型管理')),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          ...settings.providers.map((p) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: p.id == settings.selectedProviderId
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(Icons.smart_toy, size: 20,
                    color: p.id == settings.selectedProviderId ? Colors.white : null),
              ),
              title: Row(children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (p.id == settings.selectedProviderId)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('当前', style: TextStyle(fontSize: 10,
                          color: Theme.of(context).colorScheme.primary)),
                    ),
                  ),
              ]),
              subtitle: Text('${p.model}\n${p.apiBaseUrl}', style: const TextStyle(fontSize: 11)),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'select') {
                    await settings.selectProvider(p.id);
                  } else if (v == 'edit') {
                    await _editProvider(context, settings, p);
                  } else if (v == 'delete') {
                    await _deleteProvider(context, settings, p);
                  }
                },
                itemBuilder: (ctx) => [
                  if (p.id != settings.selectedProviderId)
                    const PopupMenuItem(value: 'select', child: ListTile(
                      leading: Icon(Icons.check_circle, size: 20), title: Text('设为当前', style: TextStyle(fontSize: 14)), dense: true)),
                  const PopupMenuItem(value: 'edit', child: ListTile(
                      leading: Icon(Icons.edit, size: 20), title: Text('编辑', style: TextStyle(fontSize: 14)), dense: true)),
                  const PopupMenuItem(value: 'delete', child: ListTile(
                      leading: Icon(Icons.delete, size: 20, color: Colors.red), title: Text('删除', style: TextStyle(fontSize: 14, color: Colors.red)), dense: true)),
                ],
              ),
            ),
          )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _addProvider(context),
            icon: const Icon(Icons.add),
            label: const Text('添加 Provider'),
          ),
        ],
      ),
    );
  }

  Future<void> _addProvider(BuildContext context) async {
    final result = await _showEditDialog(context);
    if (result != null) {
      await context.read<SettingsProvider>().addProvider(result);
    }
  }

  Future<void> _editProvider(BuildContext context, SettingsProvider settings, ModelProvider p) async {
    final result = await _showEditDialog(context, existing: p);
    if (result != null) {
      await settings.updateProvider(result);
    }
  }

  Future<void> _deleteProvider(BuildContext context, SettingsProvider settings, ModelProvider p) async {
    if (settings.providers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少保留一个 Provider')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除 Provider'),
        content: Text('确定删除「${p.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) await settings.deleteProvider(p.id);
  }

  Future<ModelProvider?> _showEditDialog(BuildContext context, {ModelProvider? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.apiBaseUrl ?? 'https://api.deepseek.com/v1');
    final keyCtrl = TextEditingController(text: existing?.apiKey ?? '');
    final modelCtrl = TextEditingController(text: existing?.model ?? 'deepseek-v4-flash');
    bool keyVisible = false;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? '编辑 Provider' : '添加 Provider'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl,
                decoration: const InputDecoration(labelText: '名称', hintText: 'DeepSeek', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'API 地址', hintText: 'https://api.deepseek.com/v1', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              TextField(
                controller: keyCtrl,
                obscureText: !keyVisible,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(keyVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => keyVisible = !keyVisible),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(controller: modelCtrl,
                decoration: const InputDecoration(labelText: '模型', hintText: 'deepseek-v4-flash', border: OutlineInputBorder(), isDense: true)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(onPressed: () {
              if (nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('名称不能为空')));
                return;
              }
              Navigator.pop(ctx, {
                'name': nameCtrl.text.trim(),
                'url': urlCtrl.text.trim(),
                'key': keyCtrl.text.trim(),
                'model': modelCtrl.text.trim(),
              });
            }, child: const Text('保存')),
          ],
        ),
      ),
    );

    if (result == null) return null;
    final id = existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    return ModelProvider(
      id: id,
      name: result['name']!,
      apiBaseUrl: result['url']!.isNotEmpty ? result['url']! : 'https://api.deepseek.com/v1',
      apiKey: result['key']!,
      model: result['model']!.isNotEmpty ? result['model']! : 'deepseek-v4-flash',
    );
  }
}
