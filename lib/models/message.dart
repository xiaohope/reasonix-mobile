/// 聊天消息
class Message {
  final String role;    // 'user' | 'assistant' | 'system' | 'tool'
  final String content;
  final String? toolCallId; // 如果是 tool 结果，关联的 tool_call id
  final String? toolName;   // 如果是 tool 结果，工具名
  final List<Map<String, dynamic>>? toolCalls; // assistant 消息中的工具调用
  final DateTime timestamp;
  final bool isStreaming;   // 正在流式输出

  Message({
    required this.role,
    required this.content,
    this.toolCallId,
    this.toolName,
    this.toolCalls,
    DateTime? timestamp,
    this.isStreaming = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Message copyWith({
    String? role,
    String? content,
    String? toolCallId,
    String? toolName,
    List<Map<String, dynamic>>? toolCalls,
    DateTime? timestamp,
    bool? isStreaming,
  }) {
    return Message(
      role: role ?? this.role,
      content: content ?? this.content,
      toolCallId: toolCallId ?? this.toolCallId,
      toolName: toolName ?? this.toolName,
      toolCalls: toolCalls ?? this.toolCalls,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  /// 用于 LLM API 请求（必须包含 tool_calls 才能接 tool 消息）
  Map<String, dynamic> toApiMessage() {
    final map = <String, dynamic>{
      'role': role == 'tool' ? 'tool' : role,
      'content': content,
    };
    if (toolCallId != null && role == 'tool') {
      map['tool_call_id'] = toolCallId;
    }
    if (toolCalls != null && role == 'assistant') {
      map['tool_calls'] = toolCalls;
    }
    return map;
  }
}
