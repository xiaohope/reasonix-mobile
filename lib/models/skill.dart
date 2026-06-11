/// 技能（Skill）— 可复用的指令模板
/// 以 .skill.md 格式存储在磁盘上：
/// ```markdown
/// ---
/// name: 代码审查
/// description: 审查当前项目代码，找出问题
/// icon: 🔍
/// ---
/// 请审查我当前项目的代码...
/// ```
class Skill {
  final String id;
  final String name;
  final String description;
  final String prompt;       /// 注入到对话的指令文本
  final String? icon;        /// Emoji 图标，如 '🔍'

  const Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.prompt,
    this.icon,
  });

  // ── 序列化 → .skill.md 格式 ──

  /// 将 Skill 写入为 .skill.md 格式字符串
  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('---');
    buf.writeln('name: $name');
    if (description.isNotEmpty) buf.writeln('description: $description');
    if (icon != null) buf.writeln('icon: $icon');
    buf.writeln('---');
    buf.write(prompt);
    return buf.toString();
  }

  /// 从 .skill.md 格式解析为 Skill
  /// id 由文件名决定（不含扩展名）
  factory Skill.fromMarkdown(String content, {required String id}) {
    String name = id;
    String description = '';
    String prompt = content;
    String? icon;

    // 解析 frontmatter（--- 包围的 YAML 风格键值对）
    final lines = content.split('\n');
    if (lines.isNotEmpty && lines[0].trim() == '---') {
      // 找到结束的 ---
      int endIdx = -1;
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim() == '---') {
          endIdx = i;
          break;
        }
      }

      if (endIdx > 0) {
        // 解析 frontmatter 行
        for (int i = 1; i < endIdx; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          final colon = line.indexOf(':');
          if (colon > 0) {
            final key = line.substring(0, colon).trim().toLowerCase();
            final value = line.substring(colon + 1).trim();
            switch (key) {
              case 'name': name = value; break;
              case 'description': description = value; break;
              case 'icon': icon = value.isNotEmpty ? value : null; break;
            }
          }
        }
        // 剩下的部分是 prompt（跳过 frontmatter 和空行）
        final promptLines = lines.sublist(endIdx + 1);
        while (promptLines.isNotEmpty && promptLines.first.trim().isEmpty) {
          promptLines.removeAt(0);
        }
        prompt = promptLines.join('\n').trim();
      }
    }

    return Skill(
      id: id,
      name: name,
      description: description,
      prompt: prompt,
      icon: icon,
    );
  }

  // 保留 toJson/fromJson 用于内存中的序列化（如导出聊天时可能用到）
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'prompt': prompt,
    if (icon != null) 'icon': icon,
  };

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    prompt: json['prompt'] as String,
    icon: json['icon'] as String?,
  );
}
