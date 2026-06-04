import 'dart:async';
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

  // 累计用量
  int _totalPromptTokens = 0;
  int _totalCompletionTokens = 0;
  int _totalCacheHitTokens = 0;
  double _totalCost = 0;

  LlmService? _llmService;
  ToolEngine? _toolEngine;
  StreamSubscription<String>? _streamSub;

  List<Message> get messages => List.unmodifiable(_messages);
  Message? get streamingMessage => _streamingMessage;
  bool get isProcessing => _isProcessing;
  bool get isStreaming => _isStreaming;

  String get usageSummary {
    final parts = <String>[];
    if (_totalPromptTokens > 0) parts.add('⇧${_fmt(_totalPromptTokens)}');
    if (_totalCompletionTokens > 0) parts.add('⇩${_fmt(_totalCompletionTokens)}');
    if (_totalCacheHitTokens > 0) {
      final pct = (_totalCacheHitTokens * 100 / _totalPromptTokens).toStringAsFixed(0);
      parts.add('📦$pct%');
    }
    if (_totalCost > 0) parts.add('¥${_totalCost.toStringAsFixed(4)}');
    return parts.isNotEmpty ? parts.join(' · ') : '';
  }

  static String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

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

    // 首次对话加入系统提示词
    if (_messages.isEmpty) {
      _messages.add(Message(role: 'system', content: '你是 Reasonix，一个手机上的 AI 编程助手。你由 DeepSeek 提供底层 AI 能力，但你叫 Reasonix。你擅长阅读代码、编辑文件、执行命令、管理 Git 仓库。请用中文回答，使用工具时直接调用工具，不要说“让我看看”。'));
    }

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

      // 累加用量
      if (firstResponse['usage'] is Map) {
        final u = firstResponse['usage'] as Map<String, dynamic>;
        _totalPromptTokens += u['prompt_tokens'] as int? ?? 0;
        _totalCompletionTokens += u['completion_tokens'] as int? ?? 0;
        _totalCacheHitTokens += u['prompt_cache_hit_tokens'] as int? ?? 0;
        // 估算费用
        final input = (_totalPromptTokens - _totalCacheHitTokens).clamp(0, _totalPromptTokens) * 0.000001;
        final output = _totalCompletionTokens * 0.000002;
        final cached = _totalCacheHitTokens * 0.0000005;
        _totalCost = input + output + cached;
      }

      final toolCalls = msg['tool_calls'] as List<dynamic>?;

      if (toolCalls != null && toolCalls.isNotEmpty && !_stopRequested) {
        final assistantContent = msg['content'] as String? ?? '';
        _messages.add(Message(
          role: 'assistant', content: assistantContent,
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
        final textContent = msg['content'] as String? ?? '';
        if (textContent.isNotEmpty) {
          _messages.add(Message(role: 'assistant', content: textContent));
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
    _messages.add(Message(role: 'tool', content: result, toolCallId: call.id, toolName: call.name));
  }

  void clearMessages() {
    stop();
    _messages.clear();
    _totalPromptTokens = 0;
    _totalCompletionTokens = 0;
    _totalCacheHitTokens = 0;
    _totalCost = 0;
    notifyListeners();
  }
}
