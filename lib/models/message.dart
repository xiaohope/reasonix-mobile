/// 聊天消息
class Message {
  final String role;    // 'user' | 'assistant' | 'system' | 'tool'
  final String content;
  final String? toolCallId; // 如果是 tool 结果，关联的 tool_call id
  final String? toolName;   // 如果是 tool 结果，工具名
  final DateTime timestamp;
  final bool isStreaming;   // 正在流式输出

  Message({
    required this.role,
    required this.content,
    this.toolCallId,
    this.toolName,
    DateTime? timestamp,
    this.isStreaming = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Message copyWith({
    String? role,
    String? content,
    String? toolCallId,
    String? toolName,
    DateTime? timestamp,
    bool? isStreaming,
  }) {
    return Message(
      role: role ?? this.role,
      content: content ?? this.content,
      toolCallId: toolCallId ?? this.toolCallId,
      toolName: toolName ?? this.toolName,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    if (toolCallId != null) 'tool_call_id': toolCallId,
    if (toolName != null) 'tool_name': toolName,
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    role: json['role'] as String,
    content: json['content'] as String? ?? '',
    toolCallId: json['tool_call_id'] as String?,
    toolName: json['tool_name'] as String?,
  );

  /// 用于 LLM API 请求
  Map<String, dynamic> toApiMessage() => {
    'role': role == 'tool' ? 'tool' : role,
    'content': content,
    if (toolCallId != null && role == 'tool') 'tool_call_id': toolCallId,
  };
}
