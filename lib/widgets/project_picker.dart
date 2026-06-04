import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _manualInput(context),
          icon: const Icon(Icons.edit),
          label: const Text('手动输入路径'),
        ),
        const SizedBox(height: 16),
        Text('选择代码目录作为工作区\n或手动输入完整路径',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDirectory(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择项目目录');
    if (result != null && context.mounted) onPicked(result);
  }

  void _manualInput(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('输入路径'),
        content: TextField(
          controller: controller, autofocus: true,
          decoration: const InputDecoration(
            hintText: '/storage/emulated/0/...',
            prefixIcon: Icon(Icons.folder),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final path = controller.text.trim();
              if (path.isNotEmpty) { onPicked(path); Navigator.of(ctx).pop(); }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}
