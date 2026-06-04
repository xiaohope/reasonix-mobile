import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message.dart';

/// 聊天气泡 — 支持 Markdown、链接点击、代码复制
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
          if (!isUser) _avatar(context),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
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
                      ? SelectableText(
                          message.content,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        )
                      : _buildMarkdown(context, message.content),
                ),
                // 复制按钮 + token 消耗
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: message.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                          );
                        },
                        child: Text(
                          '复制',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      if (message.usage != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            message.usage!.summary,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) _avatar(context),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    final isUser = message.role == 'user';
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

  /// Markdown 渲染：支持代码块、行内代码、加粗、链接
  Widget _buildMarkdown(BuildContext context, String text) {
    final children = <Widget>[];
    final lines = text.split('\n');
    final codeLines = <String>[];
    bool inCodeBlock = false;
    String codeLang = '';

    for (final line in lines) {
      if (line.trimLeft().startsWith('```')) {
        if (inCodeBlock) {
          // 结束代码块
          children.add(_buildCodeBlock(context, codeLines, codeLang));
          codeLines.clear();
          inCodeBlock = false;
          codeLang = '';
        } else {
          // 开始代码块
          inCodeBlock = true;
          codeLang = line.trimLeft().substring(3).trim();
        }
        continue;
      }

      if (inCodeBlock) {
        codeLines.add(line);
        continue;
      }

      // 空行
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }

      // 普通行
      children.add(_buildInlineText(context, line));
    }

    // 未闭合的代码块
    if (inCodeBlock && codeLines.isNotEmpty) {
      children.add(_buildCodeBlock(context, codeLines, codeLang));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildCodeBlock(BuildContext context, List<String> lines, String lang) {
    final code = lines.join('\n');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 语言标签 + 复制按钮
          if (lang.isNotEmpty)
            Row(
              children: [
                Text(lang, style: const TextStyle(color: Color(0xFF6C7086), fontSize: 11, fontFamily: 'monospace')),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('代码已复制'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: const Text('复制代码', style: TextStyle(color: Color(0xFF6C7086), fontSize: 11)),
                ),
              ],
            ),
          const SizedBox(height: 4),
          // 代码内容
          SelectableText(
            code,
            style: const TextStyle(color: Color(0xFFCDD6F4), fontFamily: 'monospace', fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineText(BuildContext context, String line) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(\*\*(.+?)\*\*|`([^`]+)`|\[(.+?)\]\((.+?)\)|https?://[^\s<]+)');
    int lastEnd = 0;

    for (final match in regex.allMatches(line)) {
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
        spans.add(WidgetSpan(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              match.group(3)!,
              style: const TextStyle(color: Color(0xFF00D9B0), fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ));
      } else if (match.group(4) != null) {
        // 链接 [text](url)
        final url = match.group(5)!;
        spans.add(WidgetSpan(
          child: GestureDetector(
            onTap: () => _openUrl(url),
            child: Text(
              match.group(4)!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline),
            ),
          ),
        ));
      } else {
        // 裸 URL
        final url = match.group(0)!;
        spans.add(WidgetSpan(
          child: GestureDetector(
            onTap: () => _openUrl(url),
            child: Text(
              url,
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13, decoration: TextDecoration.underline),
            ),
          ),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < line.length) {
      spans.add(TextSpan(text: line.substring(lastEnd)));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface, height: 1.5),
          children: spans,
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Widget _buildToolResult(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 2),
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: message.content));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.build_circle_outlined, size: 14, color: Theme.of(context).colorScheme.secondary),
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
      ),
    );
  }
}
