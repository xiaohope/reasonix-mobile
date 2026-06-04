import 'dart:convert';

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
    final rawArgs = func['arguments'];
    
    Map<String, dynamic> args;
    if (rawArgs is Map) {
      args = Map<String, dynamic>.from(rawArgs);
    } else if (rawArgs is String) {
      args = Map<String, dynamic>.from(jsonDecode(rawArgs) as Map);
    } else {
      args = {};
    }

    return ToolCall(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'function',
      name: func['name'] as String,
      arguments: args,
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
}
