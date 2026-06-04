import 'dart:async';
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
  bool _stopRequested = false;

  LlmService? _llmService;
  ToolEngine? _toolEngine;
  StreamSubscription<String>? _streamSub;

  List<Message> get messages => List.unmodifiable(_messages);
  Message? get streamingMessage => _streamingMessage;
  bool get isProcessing => _isProcessing;
  bool get isStreaming => _isStreaming;

  void initServices(LlmService llm, ToolEngine engine) {
    _llmService = llm;
    _toolEngine = engine;
  }

  /// 停止当前生成
  void stop() {
    _stopRequested = true;
    _streamSub?.cancel();
    if (_streamingMessage != null) {
      final msg = _streamingMessage!;
      _streamingMessage = null;
      _messages.add(Message(role: 'assistant', content: msg.content));
    }
    _isProcessing = false;
    _isStreaming = false;
    notifyListeners();
  }

  void addMessage(Message msg) {
    _messages.add(msg);
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (_isProcessing || text.trim().isEmpty) return;
    if (_llmService == null || _toolEngine == null) return;

    _messages.add(Message(role: 'user', content: text.trim()));
    _isProcessing = true;
    _stopRequested = false;
    notifyListeners();

    final maxTurns = 10;
    for (int turn = 0; turn < maxTurns; turn++) {
      if (_stopRequested) break;

      final firstResponse = await _llmService!.chatComplete(_messages);
      if (firstResponse.containsKey('error')) {
        _messages.add(Message(role: 'assistant', content: firstResponse['error'] as String));
        break;
      }

      final choice = firstResponse['choices']?[0] as Map<String, dynamic>?;
      if (choice == null) break;

      final msg = choice['message'] as Map<String, dynamic>?;
      if (msg == null) break;

      final toolCalls = msg['tool_calls'] as List<dynamic>?;

      if (toolCalls != null && toolCalls.isNotEmpty && !_stopRequested) {
        final assistantContent = msg['content'] as String? ?? '';
        _messages.add(Message(
          role: 'assistant',
          content: assistantContent,
          toolCalls: toolCalls.cast<Map<String, dynamic>>(),
        ));
        notifyListeners();

        for (final tc in toolCalls) {
          if (_stopRequested) break;
          final toolCall = ToolCall.fromJson(tc as Map<String, dynamic>);
          _addToolResult(toolCall, await _toolEngine!.execute(toolCall));
        }
        notifyListeners();
      } else {
        // 纯文字回复
        final textContent = msg['content'] as String? ?? '';
        if (textContent.isNotEmpty) {
          final responseMsg = Message(role: 'assistant', content: textContent, usage: usage);
          _messages.add(responseMsg);
          notifyListeners();
        }
        break;
      }
    }

    _isProcessing = false;
    _isStreaming = false;
    notifyListeners();
  }

  void _addToolResult(ToolCall call, String result) {
    _messages.add(Message(
      role: 'tool',
      content: result,
      toolCallId: call.id,
      toolName: call.name,
    ));
  }

  void clearMessages() {
    stop();
    _messages.clear();
    notifyListeners();
  }
}
