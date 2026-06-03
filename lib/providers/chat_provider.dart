import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/tool_call.dart';
import '../services/llm_service.dart';
import '../services/tool_engine.dart';
import '../services/file_service.dart';
import '../services/terminal_service.dart';

/// 聊天状态管理 — Reasonix 核心对话循环
class ChatProvider extends ChangeNotifier {
  final List<Message> _messages = [];
  Message? _streamingMessage;
  bool _isProcessing = false;
  bool _isStreaming = false;

  // 服务引用（由外部注入）
  LlmService? _llmService;
  ToolEngine? _toolEngine;

  List<Message> get messages => List.unmodifiable(_messages);
  Message? get streamingMessage => _streamingMessage;
  bool get isProcessing => _isProcessing;
  bool get isStreaming => _isStreaming;

  void initServices(LlmService llm, ToolEngine engine) {
    _llmService = llm;
    _toolEngine = engine;
  }

  void addMessage(Message msg) {
    _messages.add(msg);
    notifyListeners();
  }

  /// 发送用户消息 → LLM 回复 → 工具执行 → LLM 再回复（循环）
  Future<void> sendMessage(String text) async {
    if (_isProcessing || text.trim().isEmpty) return;
    if (_llmService == null || _toolEngine == null) return;

    // 加用户消息
    _messages.add(Message(role: 'user', content: text.trim()));
    _isProcessing = true;
    notifyListeners();

    final maxTurns = 10; // 防止无限工具循环
    for (int turn = 0; turn < maxTurns; turn++) {
      // 流式接收 LLM 回复
      _streamingMessage = Message(role: 'assistant', content: '', isStreaming: true);
      notifyListeners();

      final fullContent = StringBuffer();
      await for (final chunk in _llmService!.chatStream(_messages)) {
        fullContent.write(chunk);
        _streamingMessage = _streamingMessage!.copyWith(
          content: fullContent.toString(),
        );
        notifyListeners();
      }

      final assistantMsg = Message(
        role: 'assistant',
        content: fullContent.toString(),
      );
      _streamingMessage = null;
      _messages.add(assistantMsg);
      notifyListeners();

      // 检查是否有 tool_calls — 这里用简化方式：看返回内容
      // 生产环境应该解析完整 JSON response
      // 简单启发：检查是否包含工具名关键词
      final content = fullContent.toString().toLowerCase();

      // 尝试检测工具调用
      final toolCall = _detectToolCall(content, fullContent.toString());

      if (toolCall == null) break; // 纯文字回复，结束

      // 执行工具
      final result = await _toolEngine!.execute(toolCall);
      _messages.add(Message(
        role: 'tool',
        content: result,
        toolCallId: toolCall.id,
        toolName: toolCall.name,
      ));
      notifyListeners();
    }

    _isProcessing = false;
    notifyListeners();
  }

  /// 简单的工具调用检测
  /// 真正的实现应该解析 LLM 返回的 tool_calls JSON
  ToolCall? _detectToolCall(String lower, String original) {
    // 从 Markdown 代码块中提取工具调用
    // 格式: tool_name(path="...", ...) 或 JSON
    final toolPatterns = [
      (name: 'read_file', args: (String s) => _parseArgs(s, ['path'])),
      (name: 'write_file', args: (String s) => _parseArgs(s, ['path', 'content'])),
      (name: 'edit_file', args: (String s) => _parseArgs(s, ['path', 'search', 'replace'])),
      (name: 'search_content', args: (String s) => _parseArgs(s, ['pattern'])),
    ];

    for (final t in toolPatterns) {
      final regex = RegExp('${t.name}\\s*\\(([^)]+)\\)', caseSensitive: false);
      final match = regex.firstMatch(original);
      if (match != null) {
        return ToolCall(
          id: 'call_${DateTime.now().millisecondsSinceEpoch}',
          name: t.name,
          arguments: t.args(match.group(1) ?? ''),
        );
      }
    }
    return null;
  }

  Map<String, dynamic> _parseArgs(String argStr, List<String> keys) {
    final result = <String, dynamic>{};
    for (final key in keys) {
      final regex = RegExp('$key\\s*=\\s*"([^"]*)"', caseSensitive: false);
      final match = regex.firstMatch(argStr);
      if (match != null) {
        result[key] = match.group(1) ?? '';
      }
    }
    return result;
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
