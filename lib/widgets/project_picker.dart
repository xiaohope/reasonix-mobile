import 'dart:io';
import 'package:flutter/material.dart';

/// 项目目录选择器 — 使用手动输入路径
class ProjectPicker extends StatelessWidget {
  final void Function(String path) onPicked;

  const ProjectPicker({super.key, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: () => _showPathDialog(context),
          icon: const Icon(Icons.folder_open),
          label: const Text('输入项目路径'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '输入代码目录的完整路径作为工作区',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
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
