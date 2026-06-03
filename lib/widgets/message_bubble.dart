import 'package:flutter/material.dart';
import '../models/message.dart';

/// 聊天气泡 — 简单 Markdown 文本渲染（不使用 flutter_markdown 包）
class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isTool = message.role == 'tool';

    if (isTool) {
      return _buildToolResult(context);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _avatar(context, isUser),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                  : _buildRichContent(context, message.content),
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) _avatar(context, isUser),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, bool isUser) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: isUser
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.secondary,
      child: Icon(
        isUser ? Icons.person : Icons.auto_awesome,
        size: 16,
        color: Colors.white,
      ),
    );
  }

  /// 简单 Markdown 渲染：支持 **加粗**、`代码`、```代码块```、普通文本
  Widget _buildRichContent(BuildContext context, String text) {
    final spans = <TextSpan>[];
    final lines = text.split('\n');
    final isCodeBlock = <bool>[];

    for (final line in lines) {
      // 代码块
      if (line.trimLeft().startsWith('```')) {
        if (isCodeBlock.isEmpty || !isCodeBlock.last) {
          isCodeBlock.add(true);
          spans.add(TextSpan(
            text: '\n',
            style: TextStyle(
              color: const Color(0xFF00D9B0),
              fontFamily: 'monospace',
              fontSize: 13,
              backgroundColor: const Color(0xFF1E1E2E),
            ),
          ));
          continue;
        } else {
          isCodeBlock.add(false);
          spans.add(TextSpan(text: '\n'));
          continue;
        }
      }

      if (isCodeBlock.isNotEmpty && isCodeBlock.last) {
        spans.add(TextSpan(
          text: '$line\n',
          style: TextStyle(
            color: const Color(0xFFCDD6F4),
            fontFamily: 'monospace',
            fontSize: 13,
            backgroundColor: const Color(0xFF1E1E2E),
          ),
        ));
        continue;
      }

      // 行内解析：**粗壮** `行内代码`
      _parseInline(line, spans, context);
      spans.add(TextSpan(text: '\n'));
    }

    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }

  void _parseInline(String line, List<TextSpan> spans, BuildContext context) {
    final regex = RegExp(r'(\*\*(.+?)\*\*|`([^`]+)`|(\[.+?\]\(.+?\)))');
    int lastEnd = 0;

    for (final match in regex.allMatches(line)) {
      // 普通文本
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: line.substring(lastEnd, match.start)));
      }

      if (match.group(1)?.startsWith('**') == true) {
        // 加粗
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (match.group(3) != null) {
        // 行内代码
        spans.add(TextSpan(
          text: match.group(3),
          style: TextStyle(
            color: const Color(0xFF00D9B0),
            fontFamily: 'monospace',
            fontSize: 13,
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
        ));
      } else if (match.group(4) != null) {
        // 链接 [text](url)
        final linkText = match.group(0)!;
        final textMatch = RegExp(r'\[(.+?)\]').firstMatch(linkText);
        spans.add(TextSpan(
          text: textMatch?.group(1) ?? linkText,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < line.length) {
      spans.add(TextSpan(text: line.substring(lastEnd)));
    }
  }

  Widget _buildToolResult(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.build_circle_outlined,
              size: 14,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '🔧 ${message.toolName ?? '工具'}: ${message.content.length > 100 ? '${message.content.substring(0, 100)}...' : message.content}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
