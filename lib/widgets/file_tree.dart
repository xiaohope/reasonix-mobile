import 'package:flutter/material.dart';
import '../models/file_node.dart';

/// 文件树组件
class FileTree extends StatelessWidget {
  final List<FileNode> nodes;
  final Function(FileNode)? onTap;
  final String Function(FileNode)? trailingBuilder;

  const FileTree({
    super.key,
    required this.nodes,
    this.onTap,
    this.trailingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return _FileTile(
          node: node,
          onTap: onTap != null ? () => onTap!(node) : null,
          trailing: trailingBuilder?.call(node),
        );
      },
    );
  }
}

class _FileTile extends StatelessWidget {
  final FileNode node;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _FileTile({required this.node, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: _icon(context),
      title: Text(
        node.name,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
      subtitle: node.size != null
          ? Text(
              _formatSize(node.size!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _icon(BuildContext context) {
    IconData icon;
    Color color;

    switch (node.iconType) {
      case IconType.folder:
        icon = Icons.folder;
        color = const Color(0xFFF9E2AF);
      case IconType.dart:
        icon = Icons.code;
        color = const Color(0xFF74C7EC);
      case IconType.go:
        icon = Icons.code;
        color = const Color(0xFF89DCEB);
      case IconType.python:
        icon = Icons.code;
        color = const Color(0xFFF9E2AF);
      case IconType.typescript:
      case IconType.javascript:
        icon = Icons.javascript;
        color = const Color(0xFFF9E2AF);
      case IconType.config:
        icon = Icons.settings;
        color = const Color(0xFF94E2D5);
      case IconType.markdown:
        icon = Icons.description;
        color = const Color(0xFFCDD6F4);
      case IconType.image:
        icon = Icons.image;
        color = const Color(0xFFA6E3A1);
      case IconType.git:
        icon = Icons.branch;
        color = const Color(0xFFF38BA8);
      case IconType.file:
        icon = Icons.insert_drive_file;
        color = const Color(0xFF6C7086);
    }

    return Icon(icon, size: 18, color: color);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
