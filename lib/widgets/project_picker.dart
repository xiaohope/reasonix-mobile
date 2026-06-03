import 'dart:io';
import 'package:flutter/material.dart';

/// 项目目录选择器 — 使用手动输入路径（替代 file_picker）
class ProjectPicker extends StatelessWidget {
  final void Function(String path) onPicked;

  const ProjectPicker({super.key, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PathInputButton(onPicked: onPicked),
        const SizedBox(height: 16),
        Text(
          '输入代码目录的完整路径作为工作区\n例如: /storage/emulated/0/Documents/myapp',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _PathInputButton extends StatelessWidget {
  final void Function(String path) onPicked;

  const _PathInputButton({required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showPathDialog(context),
      icon: const Icon(Icons.folder_open),
      label: const Text('输入项目路径'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
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
