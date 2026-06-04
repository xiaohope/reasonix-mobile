import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/tool_call.dart';
import '../services/llm_service.dart';
import '../services/tool_engine.dart';

/// 聊天状态管理 — Reasonix 核心对话循环
class ChatProvider extends ChangeNotifier {
  final List<Message> _messages = [];
  Message? _streamingMessage;
  bool _isProcessing = false;
  bool _isStreaming = false;

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

  /// 发送消息 → LLM 回复 → 工具调用 → 执行 → 再回复（循环）
  Future<void> sendMessage(String text) async {
    if (_isProcessing || text.trim().isEmpty) return;
    if (_llmService == null || _toolEngine == null) return;

    _messages.add(Message(role: 'user', content: text.trim()));
    _isProcessing = true;
    notifyListeners();

    // 先非流式请求，获取 tool_calls（如果有）
    final firstResponse = await _llmService!.chatComplete(_messages);
    if (firstResponse.containsKey('error')) {
      _messages.add(Message(role: 'assistant', content: firstResponse['error'] as String));
      _isProcessing = false;
      notifyListeners();
      return;
    }

    final choice = firstResponse['choices']?[0] as Map<String, dynamic>?;
    if (choice == null) {
      _isProcessing = false;
      notifyListeners();
      return;
    }

    final msg = choice['message'] as Map<String, dynamic>?;
    if (msg == null) {
      _isProcessing = false;
      notifyListeners();
      return;
    }

    // 处理 tool_calls
    final toolCalls = msg['tool_calls'] as List<dynamic>?;

    if (toolCalls != null && toolCalls.isNotEmpty) {
      // 先添加 assistant 回复（含 tool_calls 但无文字内容）
      final assistantContent = msg['content'] as String? ?? '';
      if (assistantContent.isNotEmpty) {
        _messages.add(Message(role: 'assistant', content: assistantContent));
      }
      notifyListeners();

      // 逐个执行工具
      for (final tc in toolCalls) {
        final toolCall = ToolCall.fromJson(tc as Map<String, dynamic>);
        final result = await _toolEngine!.execute(toolCall);

        _messages.add(Message(
          role: 'tool',
          content: result,
          toolCallId: toolCall.id,
          toolName: toolCall.name,
        ));
        notifyListeners();
      }

      // 把工具结果发给 LLM，流式获取最终回复
      _streamingMessage = Message(role: 'assistant', content: '', isStreaming: true);
      notifyListeners();

      final fullContent = StringBuffer();
      await for (final chunk in _llmService!.chatStream(_messages)) {
        fullContent.write(chunk);
        _streamingMessage = _streamingMessage!.copyWith(content: fullContent.toString());
        notifyListeners();
      }

      _streamingMessage = null;
      _messages.add(Message(role: 'assistant', content: fullContent.toString()));
      notifyListeners();
    } else {
      // 纯文字回复，流式显示
      final textContent = msg['content'] as String? ?? '';
      if (textContent.isNotEmpty) {
        // 对于短回复直接显示，长回复流式展示
        if (textContent.length < 100) {
          _messages.add(Message(role: 'assistant', content: textContent));
        } else {
          _streamingMessage = Message(role: 'assistant', content: '', isStreaming: true);
          notifyListeners();
          // 模拟逐字输出
          for (int i = 0; i < textContent.length; i += 10) {
            final end = (i + 10).clamp(0, textContent.length);
            _streamingMessage = _streamingMessage!.copyWith(content: textContent.substring(0, end));
            notifyListeners();
            await Future.delayed(const Duration(milliseconds: 5));
          }
          _streamingMessage = null;
          _messages.add(Message(role: 'assistant', content: textContent));
        }
      }
      notifyListeners();
    }

    _isProcessing = false;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
