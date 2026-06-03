import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// 项目目录选择器 — 支持系统文件选择器
class ProjectPicker extends StatelessWidget {
  final void Function(String path) onPicked;

  const ProjectPicker({super.key, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: () => _pickDirectory(context),
          icon: const Icon(Icons.folder_open),
          label: const Text('选择项目目录'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _manualInput(context),
          icon: const Icon(Icons.edit),
          label: const Text('手动输入路径'),
        ),
        const SizedBox(height: 16),
        Text(
          '选择代码目录作为工作区\n或手动输入完整路径',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDirectory(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择项目目录',
    );
    if (result != null && context.mounted) {
      onPicked(result);
    }
  }

  void _manualInput(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('输入路径'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '/storage/emulated/0/...',
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
                Navigator.of(ctx).pop();
                onPicked(path);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

/// 快速打开最近项目
class RecentProjectsList extends StatelessWidget {
  final List<String> recentPaths;
  final void Function(String path) onTap;

  const RecentProjectsList({
    super.key,
    required this.recentPaths,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (recentPaths.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
          child: Text(
            '最近项目',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        ...recentPaths.map((path) {
          final exists = Directory(path).existsSync();
          return ListTile(
            leading: Icon(
              exists ? Icons.folder : Icons.folder_off,
              color: exists ? const Color(0xFFF9E2AF) : Colors.red,
            ),
            title: Text(
              path.split(Platform.pathSeparator).last,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              path,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            enabled: exists,
            onTap: exists ? () => onTap(path) : null,
          );
        }),
      ],
    );
  }
}
