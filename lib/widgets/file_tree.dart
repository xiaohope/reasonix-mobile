import 'package:flutter/material.dart';
import '../models/file_node.dart';

/// 文件树组件
class FileTree extends StatelessWidget {
  final List<FileNode> nodes;
  final Function(FileNode)? onTap;
  final Widget Function(FileNode)? trailingBuilder;

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
      leading: Icon(
        node.isDirectory ? Icons.folder : Icons.insert_drive_file,
        size: 18,
        color: node.isDirectory
            ? const Color(0xFFF9E2AF)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      title: Text(
        node.name,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
      trailing: node.isDirectory
          ? Icon(Icons.chevron_right, size: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))
          : trailing,
      onTap: onTap,
    );
  }
}
