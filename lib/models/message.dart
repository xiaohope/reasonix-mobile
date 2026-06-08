import '../models/usage_info.dart';

class Message {
import '../models/usage_info.dart';

class
  final String role;
  final String content;
  final String? toolCallId;
  final String? toolName;
  final List<Map<String, dynamic>>? toolCalls;
  final UsageInfo? usage;
  final String? imageBase64;
  final DateTime timestamp;
  final bool isStreaming;

  Message({
    required this.role,
    required this.content,
    this.toolCallId,
    this.toolName,
    this.toolCalls,
    this.usage,
    this.imageBase64,
    DateTime? timestamp,
    this.isStreaming = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Message copyWith({
    String? role,
    String? content,
    String? toolCallId,
    String? toolName,
    List<Map<String, dynamic>>? toolCalls,
    UsageInfo? usage,
    DateTime? timestamp,
    bool? isStreaming,
  }) {
    return Message(
      role: role ?? this.role,
      content: content ?? this.content,
      toolCallId: toolCallId ?? this.toolCallId,
      toolName: toolName ?? this.toolName,
      toolCalls: toolCalls ?? this.toolCalls,
      usage: usage ?? this.usage,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  /// 用于 LLM API 请求
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
