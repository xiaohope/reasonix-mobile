/// 技能（Skill）— 可复用的指令模板
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
