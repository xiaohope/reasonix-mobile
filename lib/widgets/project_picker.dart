import 'dart:io';
import 'package:flutter/material.dart';

class ProjectPicker extends StatelessWidget {
  final void Function(String path) onPicked;
  const ProjectPicker({super.key, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: () => _browseDirectory(context),
          icon: const Icon(Icons.folder_open),
          label: const Text('浏览并选择目录'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _manualInput(context),
          icon: const Icon(Icons.edit),
          label: const Text('手动输入路径'),
        ),
        const SizedBox(height: 16),
        Text('浏览手机目录并选择项目文件夹',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  void _browseDirectory(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DirectoryBrowser(initialPath: '/storage/emulated/0', onSelected: (p) { Navigator.of(context).pop(); onPicked(p); }),
    ));
  }

  void _manualInput(BuildContext context) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('项目路径'),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: '/storage/emulated/0/...', prefixIcon: Icon(Icons.folder), border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
        FilledButton(onPressed: () { final p = controller.text.trim(); if (p.isNotEmpty) { onPicked(p); Navigator.of(ctx).pop(); } }, child: const Text('确认')),
      ],
    ));
  }
}

class DirectoryBrowser extends StatefulWidget {
  final String initialPath;
  final void Function(String path) onSelected;
  const DirectoryBrowser({required this.initialPath, required this.onSelected});
  @override
  State<DirectoryBrowser> createState() => _DirectoryBrowserState();
}

class _DirectoryBrowserState extends State<DirectoryBrowser> {
  late String _currentPath;
  List<FileSystemEntity> _entries = [];
  String? _error;

  @override
  void initState() { super.initState(); _currentPath = widget.initialPath; _loadDir(); }

  void _loadDir() {
    _error = null;
    try {
      final dir = Directory(_currentPath);
      if (!dir.existsSync()) { _error = '目录不存在'; setState(() {}); return; }
      setState(() { _entries = dir.listSync()..sort((a, b) { final ad = a is Directory, bd = b is Directory; if (ad && !bd) return -1; if (!ad && bd) return 1; return a.path.compareTo(b.path); }); });
    } catch (e) { _error = '无法读取: $e'; setState(() {}); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPath.split('/').last, style: const TextStyle(fontSize: 16)),
        actions: [_currentPath != '/' ? IconButton(icon: const Icon(Icons.check_circle), tooltip: '选此目录', onPressed: () => widget.onSelected(_currentPath)) : const SizedBox()],
      ),
      body: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), color: Theme.of(context).colorScheme.surface, child: Row(children: [
          Expanded(child: Text(_currentPath, style: const TextStyle(fontFamily: 'monospace', fontSize: 12), overflow: TextOverflow.ellipsis)),
          if (_currentPath != '/') TextButton(onPressed: () { setState(() { _currentPath = Directory(_currentPath).parent.path; }); _loadDir(); }, child: const Text('返回上级')),
        ])),
        if (_error != null) Container(padding: const EdgeInsets.all(16), color: Colors.red.shade50, child: Row(children: [const Icon(Icons.warning, size: 16), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)))])),
        Expanded(child: _entries.isEmpty && _error == null
          ? const Center(child: Text('加载中...'))
          : ListView.builder(itemCount: _entries.length, itemBuilder: (c, i) {
            final e = _entries[i], name = e.path.split('/').last, isDir = e is Directory;
            if (name.startsWith('.') || name == 'node_modules' || name == '.git') return const SizedBox();
            return ListTile(dense: true,
              leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file, size: 20, color: isDir ? const Color(0xFFF9E2AF) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              title: Text(name, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              trailing: isDir ? Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)) : null,
              onTap: isDir ? () { setState(() { _currentPath = e.path; }); _loadDir(); } : null,
              onLongPress: isDir ? () => widget.onSelected(e.path) : null,
            );
          }),
        ),
      ]),
    );
  }
}
