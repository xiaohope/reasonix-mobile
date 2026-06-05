import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message.dart';

/// 聊天气泡 — 支持 Markdown、折叠工具调用、代码块样式
class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isTool = message.role == 'tool';
    final hasToolCalls = message.role == 'assistant' && message.toolCalls != null && message.toolCalls!.isNotEmpty;

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
                // 工具调用折叠卡片
                if (hasToolCalls)
                  _buildToolCallsCard(context),
                // 文本内容
                if (message.content.isNotEmpty)
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
                // 复制按钮
                if (!hasToolCalls)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 4),
                    child: GestureDetector(
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

  /// 工具调用折叠卡片
  Widget _buildToolCallsCard(BuildContext context) {
    return _ExpandableCard(
      icon: Icons.build_circle_outlined,
      title: '使用了 ${message.toolCalls!.length} 个工具',
      color: Theme.of(context).colorScheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: message.toolCalls!.map<Widget>((tc) {
          final name = tc['function']?['name'] ?? 'unknown';
          final args = tc['function']?['arguments'];
          String argsStr = '';
          if (args is String) {
            argsStr = args.length > 80 ? '${args.substring(0, 80)}...' : args;
          } else if (args is Map) {
            argsStr = args.toString();
            if (argsStr.length > 80) argsStr = '${argsStr.substring(0, 80)}...';
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(Icons.chevron_right, size: 14, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 4),
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.secondary,
                    fontFamily: 'monospace',
                  ),
                ),
                if (argsStr.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      argsStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Tool 结果折叠卡片
  Widget _buildToolResult(BuildContext context) {
    return _ExpandableCard(
      icon: Icons.handyman_outlined,
      title: message.toolName ?? '工具结果',
      color: Theme.of(context).colorScheme.tertiary,
      child: SelectableText(
        message.content,
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          height: 1.4,
        ),
      ),
    );
  }

  /// Markdown 渲染
  Widget _buildMarkdown(BuildContext context, String text) {
    final children = <Widget>[];
    final lines = text.split('\n');
    final codeLines = <String>[];
    bool inCodeBlock = false;
    String codeLang = '';

    for (final line in lines) {
      if (line.trimLeft().startsWith('```')) {
        if (inCodeBlock) {
          children.add(_buildCodeBlock(context, codeLines, codeLang));
          codeLines.clear();
          inCodeBlock = false;
          codeLang = '';
        } else {
          inCodeBlock = true;
          codeLang = line.trimLeft().substring(3).trim();
        }
        continue;
      }

      if (inCodeBlock) {
        codeLines.add(line);
        continue;
      }

      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }

      children.add(_buildInlineText(context, line));
    }

    if (inCodeBlock && codeLines.isNotEmpty) {
      children.add(_buildCodeBlock(context, codeLines, codeLang));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// 代码块 — 更明显的背景色
  Widget _buildCodeBlock(BuildContext context, List<String> lines, String lang) {
    final code = lines.join('\n');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : const Color(0xFFECF0F4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // 语言标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lang.isNotEmpty ? lang : 'code',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const Spacer(),
                // 复制按钮
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('代码已复制'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 14, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A)),
                      const SizedBox(width: 4),
                      Text(
                        '复制',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 代码内容
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: TextStyle(
                color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2328),
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
            ),
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
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (match.group(3) != null) {
        spans.add(WidgetSpan(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              match.group(3)!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ));
      } else if (match.group(4) != null) {
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.5,
          ),
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
}

/// 可折叠卡片 — 用于工具调用和工具结果
class _ExpandableCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;

  const _ExpandableCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<_ExpandableCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: widget.color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行（可点击展开/收起）
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 16, color: widget.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: widget.color,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: widget.color.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
            // 展开内容
            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: widget.child,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
