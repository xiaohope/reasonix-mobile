import 'dart:io';
import 'package:flutter/material.dart';

/// 项目目录选择器 — 支持浏览目录和手动输入
class ProjectPicker extends StatelessWidget {
  final void Function(String path) onPicked;

  const ProjectPicker({super.key, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: () => _browseDirectory(context, '/'),
          icon: const Icon(Icons.folder_open),
          label: const Text('浏览并选择目录'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _showPathDialog(context),
          icon: const Icon(Icons.edit),
          label: const Text('手动输入路径'),
        ),
        const SizedBox(height: 16),
        Text(
          '浏览手机目录并选择项目文件夹',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  /// 浏览目录
  void _browseDirectory(BuildContext context, String path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectoryBrowser(
          initialPath: path,
          onSelected: (selectedPath) {
            Navigator.of(context).pop();
            onPicked(selectedPath);
          },
        ),
      ),
    );
  }

  void _showPathDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('项目路径'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '/storage/emulated/0/Documents/...',
            prefixIcon: Icon(Icons.folder),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final path = controller.text.trim();
              if (path.isNotEmpty) {
                onPicked(path);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

/// 目录浏览器页面
class DirectoryBrowser extends StatefulWidget {
  final String initialPath;
  final void Function(String path) onSelected;

  const _DirectoryBrowser({
    required this.initialPath,
    required this.onSelected,
  });

  @override
  State<_DirectoryBrowser> createState() => _DirectoryBrowserState();
}

class _DirectoryBrowserState extends State<DirectoryBrowser> {
  late String _currentPath;
  List<FileSystemEntity> _entries = [];

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _loadDirectory();
  }

  void _loadDirectory() {
    final dir = Directory(_currentPath);
    if (!dir.existsSync()) return;
    setState(() {
      _entries = dir.listSync()
        ..sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return a.path.compareTo(b.path);
        });
    });
  }

  void _enterDirectory(String path) {
    setState(() {
      _currentPath = path;
    });
    _loadDirectory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentPath.split('/').last,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_currentPath != '/')
            IconButton(
              icon: const Icon(Icons.check_circle),
              tooltip: '选此目录',
              onPressed: () => widget.onSelected(_currentPath),
            ),
        ],
      ),
      body: Column(
        children: [
          // 路径栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _currentPath,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_currentPath != '/')
                  TextButton(
                    onPressed: () {
                      final parent = Directory(_currentPath).parent.path;
                      _enterDirectory(parent);
                    },
                    child: const Text('返回上级'),
                  ),
              ],
            ),
          ),
          // 文件列表
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Text(
                      '(空目录)',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      final name = entry.path.split('/').last;
                      final isDir = entry is Directory;

                      // 过滤隐藏文件和常见无关目录
                      if (name.startsWith('.') ||
                          name == 'node_modules' ||
                          name == '.git') return const SizedBox.shrink();

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isDir ? Icons.folder : Icons.insert_drive_file,
                          size: 20,
                          color: isDir
                              ? const Color(0xFFF9E2AF)
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        ),
                        trailing: isDir
                            ? Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))
                            : null,
                        onTap: isDir
                            ? () => _enterDirectory(entry.path)
                            : null,
                        onLongPress: isDir
                            ? () => widget.onSelected(entry.path)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
