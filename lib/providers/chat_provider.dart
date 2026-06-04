import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/tool_call.dart';
import '../models/usage_info.dart';
import '../services/llm_service.dart';
import '../services/tool_engine.dart';

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

      // 解析 usage
      UsageInfo? usage;
      if (firstResponse['usage'] is Map) {
        usage = UsageInfo.fromJson(firstResponse['usage'] as Map<String, dynamic>);
      }

      final toolCalls = msg['tool_calls'] as List<dynamic>?;

      if (toolCalls != null && toolCalls.isNotEmpty && !_stopRequested) {
        final assistantContent = msg['content'] as String? ?? '';
        _messages.add(Message(
          role: 'assistant',
          content: assistantContent,
          toolCalls: toolCalls.cast<Map<String, dynamic>>(),
          usage: usage,
        ));
        notifyListeners();

        for (final tc in toolCalls) {
          if (_stopRequested) break;
          final toolCall = ToolCall.fromJson(tc as Map<String, dynamic>);
          _addToolResult(toolCall, await _toolEngine!.execute(toolCall));
        }
        notifyListeners();
      } else {
        final textContent = msg['content'] as String? ?? '';
        if (textContent.isNotEmpty) {
          _messages.add(Message(role: 'assistant', content: textContent, usage: usage));
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
