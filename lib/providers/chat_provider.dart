import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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

  int _totalPromptTokens = 0;
  int _totalCompletionTokens = 0;
  int _totalCacheHitTokens = 0;
  double _totalCost = 0;

  LlmService? _llmService;
  ToolEngine? _toolEngine;
  StreamSubscription<String>? _streamSub;
  File? _file;

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

  Future<void> _initFile() async {
    if (_file != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/reasonix_chat.json');
  }

  /// 保存聊天记录到文件
  Future<void> _save() async {
    await _initFile();
    try {
      final data = {
        'messages': _messages.map((m) => {
          'role': m.role,
          'content': m.content,
          if (m.toolCallId != null) 'tool_call_id': m.toolCallId,
          if (m.toolName != null) 'tool_name': m.toolName,
          if (m.toolCalls != null) 'tool_calls': m.toolCalls,
          if (m.usage != null) 'usage': {
            'prompt_tokens': m.usage!.promptTokens,
            'completion_tokens': m.usage!.completionTokens,
            'total_tokens': m.usage!.totalTokens,
            'prompt_cache_hit_tokens': m.usage!.promptCacheHitTokens,
          },
        }).toList(),
        'total_prompt_tokens': _totalPromptTokens,
        'total_completion_tokens': _totalCompletionTokens,
        'total_cache_hit_tokens': _totalCacheHitTokens,
        'total_cost': _totalCost,
      };
      await _file!.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  /// 加载聊天记录
  Future<void> load() async {
    await _initFile();
    try {
      if (!await _file!.exists()) return;
      final json = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
      final msgs = json['messages'] as List<dynamic>? ?? [];
      for (final m in msgs) {
        final msg = m as Map<String, dynamic>;
        UsageInfo? usage;
        if (msg['usage'] is Map) {
          usage = UsageInfo.fromJson(msg['usage'] as Map<String, dynamic>);
        }
        _messages.add(Message(
          role: msg['role'] as String,
          content: msg['content'] as String? ?? '',
          toolCallId: msg['tool_call_id'] as String?,
          toolName: msg['tool_name'] as String?,
          toolCalls: (msg['tool_calls'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
          usage: usage,
        ));
      }
      _totalPromptTokens = json['total_prompt_tokens'] as int? ?? 0;
      _totalCompletionTokens = json['total_completion_tokens'] as int? ?? 0;
      _totalCacheHitTokens = json['total_cache_hit_tokens'] as int? ?? 0;
      _totalCost = json['total_cost'] as double? ?? 0;

      // 清理不完整的 tool_calls（assistant 的 tool_calls 必须被 tool 响应配对）
      _fixIncompleteToolCalls();
    } catch (_) {}
    notifyListeners();
  }

  /// 移除未被 tool 响应配对的 assistant tool_calls 消息
  void _fixIncompleteToolCalls() {
    // 先收集所有 tool 消息的 tool_call_id
    final respondedIds = <String>{};
    for (final m in _messages) {
      if (m.role == 'tool' && m.toolCallId != null) {
        respondedIds.add(m.toolCallId!);
      }
    }

    // 倒序遍历，移除缺少对应 tool 响应的 assistant 消息
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.role == 'assistant' && m.toolCalls != null && m.toolCalls!.isNotEmpty) {
        final allResponded = m.toolCalls!.every(
          (tc) => respondedIds.contains(tc['id'] as String?),
        );
        if (!allResponded) {
          _messages.removeAt(i);
        }
      }
    }
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
    _save();
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (_isProcessing || text.trim().isEmpty) return;
    if (_llmService == null || _toolEngine == null) return;

    if (!_messages.any((m) => m.role == 'system')) {
      _messages.add(Message(role: 'system', content: '你是 Reasonix，一个手机上的 AI 编程助手。你由 DeepSeek 提供底层 AI 能力，但你叫 Reasonix。你擅长阅读代码、编辑文件、执行命令、管理 Git 仓库。请用中文回答，使用工具时直接调用工具，不要说"让我看看"。'));
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
        _save();
        break;
      }

      final choice = firstResponse['choices']?[0] as Map<String, dynamic>?;
      if (choice == null) break;

      final msg = choice['message'] as Map<String, dynamic>?;
      if (msg == null) break;

      if (firstResponse['usage'] is Map) {
        final u = firstResponse['usage'] as Map<String, dynamic>;
        _totalPromptTokens += u['prompt_tokens'] as int? ?? 0;
        _totalCompletionTokens += u['completion_tokens'] as int? ?? 0;
        _totalCacheHitTokens += u['prompt_cache_hit_tokens'] as int? ?? 0;
        final input = (_totalPromptTokens - _totalCacheHitTokens).clamp(0, _totalPromptTokens) * 0.000001;
        final output = _totalCompletionTokens * 0.000002;
        final cached = _totalCacheHitTokens * 0.0000005;
        _totalCost = input + output + cached;
      }

      final toolCalls = msg['tool_calls'] as List<dynamic>?;

      if (toolCalls != null && toolCalls.isNotEmpty && !_stopRequested) {
        final assistantContent = msg['content'] as String? ?? '';
        _messages.add(Message(role: 'assistant', content: assistantContent, toolCalls: toolCalls.cast<Map<String, dynamic>>()));
        notifyListeners();

        for (final tc in toolCalls) {
          if (_stopRequested) break;
          final toolCall = ToolCall.fromJson(tc as Map<String, dynamic>);
          _addToolResult(toolCall, await _toolEngine!.execute(toolCall));
        }
        _save();
        notifyListeners();
      } else {
        final textContent = msg['content'] as String? ?? '';
        if (textContent.isNotEmpty) {
          _messages.add(Message(role: 'assistant', content: textContent));
          _save();
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
    _save();
  }

  void clearMessages() {
    stop();
    _messages.clear();
    _totalPromptTokens = 0;
    _totalCompletionTokens = 0;
    _totalCacheHitTokens = 0;
    _totalCost = 0;
    _save();
    notifyListeners();
  }
}
