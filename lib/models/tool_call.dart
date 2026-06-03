/// LLM 返回的工具调用
class ToolCall {
  final String id;
  final String type;   // 'function'
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCall({
    required this.id,
    this.type = 'function',
    required this.name,
    required this.arguments,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final func = json['function'] as Map<String, dynamic>;
    return ToolCall(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'function',
      name: func['name'] as String,
      arguments: Map<String, dynamic>.from(
        func['arguments'] is Map
            ? func['arguments'] as Map
            : {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'function': {
      'name': name,
      'arguments': arguments,
    },
  };

  /// 将参数中的 path / pattern 等解析为相对于项目根路径的绝对路径
  String resolvePath(String? projectRoot, String key) {
    final raw = arguments[key] as String? ?? '';
    if (raw.isEmpty) return raw;
    if (raw.startsWith('/') && projectRoot != null) {
      return '$projectRoot$raw';
    }
    if (projectRoot != null) {
      return '$projectRoot/$raw';
    }
    return raw;
  }
}
