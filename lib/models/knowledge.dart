/// 知识库条目
/// 以 .md 格式存储在磁盘上：
/// ```markdown
/// ---
/// title: Flutter 开发规范
/// description: 团队 Flutter 最佳实践
/// tags: flutter, dart
/// ---
/// 正文内容...
/// ```
class Knowledge {
  final String id;
  final String title;
  final String description;
  final String content;       /// 完整的知识正文
  final String tags;          /// 逗号分隔的标签

  const Knowledge({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    this.tags = '',
  });

  /// 序列化为 .md 格式
  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('---');
    buf.writeln('title: $title');
    if (description.isNotEmpty) buf.writeln('description: $description');
    if (tags.isNotEmpty) buf.writeln('tags: $tags');
    buf.writeln('---');
    buf.write(content);
    return buf.toString();
  }

  /// 从 .md 格式解析
  factory Knowledge.fromMarkdown(String markdown, {required String id}) {
    String title = id;
    String description = '';
    String content = markdown;
    String tags = '';

    final lines = markdown.split('\n');
    if (lines.isNotEmpty && lines[0].trim() == '---') {
      int endIdx = -1;
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim() == '---') {
          endIdx = i;
          break;
        }
      }
      if (endIdx > 0) {
        for (int i = 1; i < endIdx; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          final colon = line.indexOf(':');
          if (colon > 0) {
            final key = line.substring(0, colon).trim().toLowerCase();
            final value = line.substring(colon + 1).trim();
            switch (key) {
              case 'title': title = value; break;
              case 'description': description = value; break;
              case 'tags': tags = value; break;
            }
          }
        }
        final bodyLines = lines.sublist(endIdx + 1);
        while (bodyLines.isNotEmpty && bodyLines.first.trim().isEmpty) {
          bodyLines.removeAt(0);
        }
        content = bodyLines.join('\n').trim();
      }
    }

    return Knowledge(
      id: id,
      title: title,
      description: description,
      content: content,
      tags: tags,
    );
  }
}
