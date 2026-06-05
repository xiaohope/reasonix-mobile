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
import 'project_provider.dart';

const String kMemoryFileName = '.reasonix_memory.json';
const int kMemoryFileVersion = 1;

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
  ProjectProvider? _projectProvider;
  StreamSubscription<String>? _streamSub;
  File? _fallbackFile;

  List<Message> get messages => List.unmodifiable(_messages);
  Message? get streamingMessage => _streamingMessage;
  bool get isProcessing => _isProcessing;
  bool get isStreaming => _isStreaming;

  String get usageSummary {
    final parts = <String>[];
    if (_totalPromptTokens > 0) parts.add('in:${_fmt(_totalPromptTokens)}');
    if (_totalCompletionTokens > 0) parts.add('out:${_fmt(_totalCompletionTokens)}');
    if (_totalCacheHitTokens > 0) {
      final pct = (_totalCacheHitTokens * 100 / _totalPromptTokens).toStringAsFixed(0);
      parts.add('cache:${pct}%');
    }
    if (_totalCost > 0) parts.add('¥${_totalCost.toStringAsFixed(4)}');
    return parts.isNotEmpty ? parts.join(' | ') : '';
  }
  static String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  Future<File> _getMemoryFile() async {
    if (_projectProvider != null && _projectProvider!.hasProject) {
      final projectPath = _projectProvider!.memoryFilePath;
      if (projectPath != null) return File(projectPath);
    }
    if (_fallbackFile == null) {
      final dir = await getApplicationDocumentsDirectory();
      _fallbackFile = File('${dir.path}/reasonix_chat.json');
    }
    return _fallbackFile!;
  }

  bool get isUsingProjectMemory => _projectProvider != null && _projectProvider!.hasProject;
  String? get projectMemoryPath => _projectProvider?.memoryFilePath;

  void initProjectProvider(ProjectProvider provider) {
    _projectProvider = provider;
    provider.onProjectOpened = () { load(); };
  }

  void initServices(LlmService llm, ToolEngine engine) {
    _llmService = llm;
    _toolEngine = engine;
  }

  Future<void> _initFallbackFile() async {
    if (_fallbackFile != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _fallbackFile = File('${dir.path}/reasonix_chat.json');
  }

  // ========== 会话管理 ==========

  String? _currentSessionId;
  final Map<String, Map<String, dynamic>> _sessions = {};

  String? get currentSessionId => _currentSessionId;
  List<Map<String, dynamic>> get sessions => _sessions.values.toList()
    ..sort((a, b) => (b['updated_at'] as String).compareTo(a['updated_at'] as String));

  String createSession({String? name}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final session = {
      'id': id,
      'name': name ?? '对话 ${_sessions.length + 1}',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    _sessions[id] = session;
    _currentSessionId = id;
    _messages.clear();
    _totalPromptTokens = 0;
    _totalCompletionTokens = 0;
    _totalCacheHitTokens = 0;
    _totalCost = 0;
    _saveSessionMeta();
    _save();
    notifyListeners();
    return id;
  }

  Future<void> switchSession(String sessionId) async {
    if (!_sessions.containsKey(sessionId)) return;
    await _save();
    _currentSessionId = sessionId;
    _sessions[sessionId]!['updated_at'] = DateTime.now().toIso8601String();
    _saveSessionMeta();
    await load();
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    if (!_sessions.containsKey(sessionId)) return;
    _sessions.remove(sessionId);
    try {
      final sessionFile = await _getSessionFile(sessionId);
      if (await sessionFile.exists()) await sessionFile.delete();
    } catch (_) {}
    _saveSessionMeta();
    if (_currentSessionId == sessionId) {
      if (_sessions.isEmpty) {
        createSession(name: '新对话');
      } else {
        await switchSession(_sessions.keys.last);
      }
    }
    notifyListeners();
  }

  void renameSession(String sessionId, String newName) {
    if (_sessions.containsKey(sessionId)) {
      _sessions[sessionId]!['name'] = newName;
      _saveSessionMeta();
      notifyListeners();
    }
  }

  Future<File> _getSessionFile(String sessionId) async {
    final base = await _getMemoryFile();
    final parent = base.parent;
    return File('${parent.path}/.reasonix_session_$sessionId.json');
  }

  Future<void> _saveSessionMeta() async {
    try {
      final base = await _getMemoryFile();
      final metaFile = File('${base.parent.path}/.reasonix_sessions.json');
      await metaFile.parent.create(recursive: true);
      await metaFile.writeAsString(jsonEncode({
        'sessions': _sessions,
        'current_session_id': _currentSessionId,
      }));
    } catch (_) {}
  }

  Future<void> _loadSessionMeta() async {
    try {
      final base = await _getMemoryFile();
      final metaFile = File('${base.parent.path}/.reasonix_sessions.json');
      if (await metaFile.exists()) {
        final data = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        if (data['sessions'] is Map) {
          _sessions.clear();
          (data['sessions'] as Map).forEach((k, v) => _sessions[k.toString()] = v as Map<String, dynamic>);
        }
        _currentSessionId = data['current_session_id'] as String?;
      }
    } catch (_) {}
    if (_sessions.isEmpty) createSession(name: '默认对话');
  }

  // ========== 记忆加载/保存 ==========

  Future<void> load() async {
    await _loadSessionMeta();
    final file = await _getMemoryFile();
    try {
      if (await file.exists()) {
        final raw = await file.readAsString();
        _parseAndLoad(raw);
        notifyListeners();
        return;
      }
    } catch (_) {}
    if (_projectProvider != null && _projectProvider!.hasProject) {
      await _initFallbackFile();
      if (_fallbackFile != null && await _fallbackFile!.exists()) {
        try {
          final oldRaw = await _fallbackFile!.readAsString();
          final oldJson = jsonDecode(oldRaw) as Map<String, dynamic>;
          if (oldJson.containsKey('messages') && (oldJson['messages'] as List).isNotEmpty) {
            _parseAndLoad(oldRaw);
            await _save();
            await _fallbackFile!.delete();
            notifyListeners();
            return;
          }
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  void _parseAndLoad(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _messages.clear();
    _totalPromptTokens = 0;
    _totalCompletionTokens = 0;
    _totalCacheHitTokens = 0;
    _totalCost = 0;
    final List<dynamic> msgs;
    if (json.containsKey('version')) {
      msgs = json['messages'] as List<dynamic>? ?? [];
      final usage = json['usage'] as Map<String, dynamic>?;
      if (usage != null) {
        _totalPromptTokens = usage['total_prompt_tokens'] as int? ?? 0;
        _totalCompletionTokens = usage['total_completion_tokens'] as int? ?? 0;
        _totalCacheHitTokens = usage['total_cache_hit_tokens'] as int? ?? 0;
        _totalCost = usage['total_cost'] as double? ?? 0;
      }
    } else {
      msgs = json['messages'] as List<dynamic>? ?? [];
      _totalPromptTokens = json['total_prompt_tokens'] as int? ?? 0;
      _totalCompletionTokens = json['total_completion_tokens'] as int? ?? 0;
      _totalCacheHitTokens = json['total_cache_hit_tokens'] as int? ?? 0;
      _totalCost = json['total_cost'] as double? ?? 0;
    }
    for (final m in msgs) {
      final msg = m as Map<String, dynamic>;
      UsageInfo? usage;
      if (msg['usage'] is Map) {
        usage = UsageInfo.fromJson(msg['usage'] as Map<String, dynamic>);
      }
      _messages.add(Message(
        role: msg['role'] as String, content: msg['content'] as String? ?? '',
        toolCallId: msg['tool_call_id'] as String?, toolName: msg['tool_name'] as String?,
        toolCalls: (msg['tool_calls'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
        usage: usage,
      ));
    }
    _fixIncompleteToolCalls();
  }

  void _fixIncompleteToolCalls() {
    final respondedIds = <String>{};
    for (final m in _messages) {
      if (m.role == 'tool' && m.toolCallId != null) respondedIds.add(m.toolCallId!);
    }
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.role == 'assistant' && m.toolCalls != null && m.toolCalls!.isNotEmpty) {
        if (!m.toolCalls!.every((tc) => respondedIds.contains(tc['id'] as String?))) {
          _messages.removeAt(i);
        }
      }
    }
  }

  Future<void> _save() async {
    final file = await _getMemoryFile();
    try {
      final data = {
        'version': kMemoryFileVersion,
        'last_updated': DateTime.now().toIso8601String(),
        'messages': _messages.map((m) => {
          'role': m.role, 'content': m.content,
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
        'usage': {
          'total_prompt_tokens': _totalPromptTokens,
          'total_completion_tokens': _totalCompletionTokens,
          'total_cache_hit_tokens': _totalCacheHitTokens,
          'total_cost': _totalCost,
        },
      };
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  void stop() {
    _stopRequested = true;
    _streamSub?.cancel();
    if (_streamingMessage != null) {
      final msg = _streamingMessage!;
      _streamingMessage = null;
      _messages.add(Message(role: 'assistant', content: msg.content));
    }
    _isProcessing = false; _isStreaming = false;
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
        _save(); break;
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
        _totalCost = (_totalPromptTokens - _totalCacheHitTokens).clamp(0, _totalPromptTokens) * 0.000001 + _totalCompletionTokens * 0.000002 + _totalCacheHitTokens * 0.0000005;
      }
      final toolCalls = msg['tool_calls'] as List<dynamic>?;
      if (toolCalls != null && toolCalls.isNotEmpty && !_stopRequested) {
        _messages.add(Message(role: 'assistant', content: msg['content'] as String? ?? '', toolCalls: toolCalls.cast<Map<String, dynamic>>()));
        notifyListeners();
        for (final tc in toolCalls) {
          if (_stopRequested) break;
          final toolCall = ToolCall.fromJson(tc as Map<String, dynamic>);
          _addToolResult(toolCall, await _toolEngine!.execute(toolCall));
        }
        _save(); notifyListeners();
      } else {
        final textContent = msg['content'] as String? ?? '';
        if (textContent.isNotEmpty) {
          _messages.add(Message(role: 'assistant', content: textContent));
          _save(); notifyListeners();
        }
        break;
      }
    }
    _isProcessing = false; _isStreaming = false;
    notifyListeners();
  }

  void _addToolResult(ToolCall call, String result) {
    _messages.add(Message(role: 'tool', content: result, toolCallId: call.id, toolName: call.name));
    _save();
  }

  void clearMessages() {
    stop();
    _messages.clear();
    _totalPromptTokens = 0; _totalCompletionTokens = 0; _totalCacheHitTokens = 0; _totalCost = 0;
    _save();
    notifyListeners();
  }

  // ========== 导出/导入 ==========

  Future<String> exportChatAsJson() async {
    final file = await _getMemoryFile();
    if (await file.exists()) return await file.readAsString();
    return jsonEncode({
      'version': kMemoryFileVersion,
      'last_updated': DateTime.now().toIso8601String(),
      'messages': _messages.map((m) => {
        'role': m.role, 'content': m.content,
        if (m.toolCallId != null) 'tool_call_id': m.toolCallId,
        if (m.toolName != null) 'tool_name': m.toolName,
        if (m.toolCalls != null) 'tool_calls': m.toolCalls,
      }).toList(),
      'usage': {
        'total_prompt_tokens': _totalPromptTokens,
        'total_completion_tokens': _totalCompletionTokens,
        'total_cache_hit_tokens': _totalCacheHitTokens,
        'total_cost': _totalCost,
      },
    });
  }

  Future<String> exportChatAsText() async {
    final buf = StringBuffer();
    buf.writeln('=== Reasonix 对话导出 ===');
    buf.writeln('导出时间: ${DateTime.now().toIso8601String()}');
    if (_currentSessionId != null && _sessions.containsKey(_currentSessionId)) {
      buf.writeln('会话: ${_sessions[_currentSessionId]!['name']}');
    }
    buf.writeln('Token用量: 输入=${_fmt(_totalPromptTokens)}, 输出=${_fmt(_totalCompletionTokens)}');
    buf.writeln('=== 对话内容 ===\n');
    for (final m in _messages) {
      switch (m.role) {
        case 'system': break;
        case 'user':
          buf.writeln('👤 用户:\n${m.content}\n');
          break;
        case 'assistant':
          if (m.toolCalls != null && m.toolCalls!.isNotEmpty) {
            for (final tc in m.toolCalls!) {
              buf.writeln('🔧 调用工具: ${tc['function']?['name'] ?? 'unknown'}');
            }
          } else if (m.content.isNotEmpty) {
            buf.writeln('🤖 Reasonix:\n${m.content}\n');
          }
          break;
        case 'tool':
          buf.writeln('⚙️ 工具结果 (${m.toolName ?? ''}):');
          buf.writeln('${m.content.length > 200 ? "${m.content.substring(0, 200)}..." : m.content}\n');
          break;
      }
    }
    buf.writeln('=== 导出结束 ===');
    return buf.toString();
  }

  Future<bool> importChatFromJson(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (!data.containsKey('messages')) return false;
      createSession(name: '导入的对话');
      _parseAndLoad(jsonStr);
      await _save();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('导入失败: $e');
      return false;
    }
  }

  Map<String, dynamic> get usageStats => {
    'prompt_tokens': _totalPromptTokens,
    'completion_tokens': _totalCompletionTokens,
    'cache_hit_tokens': _totalCacheHitTokens,
    'total_cost': _totalCost,
    'message_count': _messages.length,
    'session_count': _sessions.length,
  };
}
