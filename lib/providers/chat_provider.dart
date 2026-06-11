import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message.dart';
import '../models/tool_call.dart';
import '../models/usage_info.dart';
import '../models/skill.dart';
import '../models/knowledge.dart';
import '../services/llm_service.dart';
import '../services/tool_engine.dart';
import 'project_provider.dart';

const int kMemoryFileVersion = 2;

class ChatProvider extends ChangeNotifier {
  final List<Message> _messages = [];
  Message? _streamingMessage;
  bool _isProcessing = false;
  bool _isStreaming = false;
  bool _stopRequested = false;
  bool _isProgrammingMode = false;  // 默认聊天模式
  int _totalPromptTokens = 0;
  int _totalCompletionTokens = 0;
  int _totalCacheHitTokens = 0;
  double _totalCost = 0;
  LlmService? _llmService;
  ToolEngine? _toolEngine;
  ProjectProvider? _projectProvider;
  StreamSubscription<String>? _streamSub;

  /// App 数据目录（所有 session 数据的根目录）
  Directory? _dataDir;

  /// 切换到聊天 Tab 的回调（由 AppShell 设置）
  VoidCallback? onSwitchToChat;

  List<Message> get messages => List.unmodifiable(_messages);
  Message? get streamingMessage => _streamingMessage;
  bool get isProcessing => _isProcessing;
  bool get isStreaming => _isStreaming;
  bool get isProgrammingMode => _isProgrammingMode;

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

  bool get isUsingProjectMemory => _projectProvider != null && _projectProvider!.hasProject;
  String? get projectMemoryPath => _projectProvider?.memoryFilePath;

  void initProjectProvider(ProjectProvider provider) {
    _projectProvider = provider;
    provider.onProjectOpened = () { _onProjectChanged(); };
  }

  /// 切换聊天/编程模式（查找已有同模式对话，避免重复新建）
  void setMode(bool isProgramming) {
    if (_isProgrammingMode == isProgramming) return;
    _isProgrammingMode = isProgramming;
    final modeLabel = isProgramming ? 'programming' : 'chat';
    // 查找是否已有该模式的对话
    final existing = _sessions.values
        .where((s) => s['mode'] == modeLabel || (s['name'] as String?)?.startsWith(isProgramming ? '编程' : '聊天') == true)
        .toList();
    existing.sort((a, b) => (b['updated_at'] as String).compareTo(a['updated_at'] as String));

    if (existing.isNotEmpty) {
      // 复用最近的同模式对话
      switchSession(existing.first['id'] as String);
    } else {
      // 没有则新建，继承当前项目路径
      final label = isProgramming ? '编程' : '聊天';
      final currentProject = _projectProvider?.rootPath ?? '';
      createSession(name: '$label 对话', mode: modeLabel, projectPath: currentProject);
    }
    // 切模式时更新 system prompt
    if (_isProgrammingMode) {
      _updateSystemPrompt();
    } else {
      _updateSystemPrompt(isProgramming: false);
    }
    notifyListeners();
  }

  void initServices(LlmService llm, ToolEngine engine) {
    _llmService = llm;
    _toolEngine = engine;
  }

  // ========== 数据目录 ==========

  /// 获取 App 固定数据目录，所有 session 文件都在这里
  Future<Directory> _getDataDir() async {
    if (_dataDir != null) return _dataDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _dataDir = Directory('${appDir.path}/reasonix');
    if (!await _dataDir!.exists()) {
      await _dataDir!.create(recursive: true);
    }
    return _dataDir!;
  }

  // ========== 会话管理 ==========

  String? _currentSessionId;
  final Map<String, Map<String, dynamic>> _sessions = {};

  String? get currentSessionId => _currentSessionId;
  List<Map<String, dynamic>> get sessions => _sessions.values.toList()
    ..sort((a, b) => (b['updated_at'] as String).compareTo(a['updated_at'] as String));

  String createSession({String? name, String? mode, String? projectPath}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final session = {
      'id': id,
      'name': name ?? '对话 ${_sessions.length + 1}',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'project_path': projectPath ?? '',
      if (mode != null) 'mode': mode,
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
    // 先保存当前会话
    await _save();
    _currentSessionId = sessionId;
    _sessions[sessionId]!['updated_at'] = DateTime.now().toIso8601String();
    _saveSessionMeta();
    // 切换项目 —— 每个对话绑定一个项目
    final sessionProjectPath = _sessions[sessionId]?['project_path'] as String?;
    if (_projectProvider == null) {
      // 什么都不做
    } else if (sessionProjectPath != null && sessionProjectPath.isNotEmpty
        && _projectProvider!.rootPath != sessionProjectPath) {
      // 会话有绑定项目且不同 → 切换项目
      _projectProvider!.openProject(sessionProjectPath);
    }
    // 加载目标会话的消息
    await _loadSessionMessages();
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
        createSession(name: '新对话', mode: _isProgrammingMode ? 'programming' : 'chat');
      } else {
        await switchSession(_sessions.keys.last);
      }
    }
    notifyListeners();
  }

  void setCurrentSessionProjectPath(String path) {
    if (_currentSessionId != null && _sessions.containsKey(_currentSessionId)) {
      _sessions[_currentSessionId]!['project_path'] = path;
      _saveSessionMeta();
    }
  }

  void renameSession(String sessionId, String newName) {
    if (_sessions.containsKey(sessionId)) {
      _sessions[sessionId]!['name'] = newName;
      _saveSessionMeta();
      notifyListeners();
    }
  }

  /// 获取指定 session 的数据文件路径（始终在 App 数据目录下）
  Future<File> _getSessionFile(String sessionId) async {
    final dir = await _getDataDir();
    return File('${dir.path}/session_$sessionId.json');
  }

  /// 获取当前 session 对应的文件
  Future<File> _getCurrentSessionFile() async {
    if (_currentSessionId != null) {
      return _getSessionFile(_currentSessionId!);
    }
    // 没有 session 时用临时文件
    final dir = await _getDataDir();
    return File('${dir.path}/session_default.json');
  }

  /// session meta 文件路径（始终在 App 数据目录下）
  Future<File> _getSessionMetaFile() async {
    final dir = await _getDataDir();
    return File('${dir.path}/sessions.json');
  }

  Future<void> _saveSessionMeta() async {
    try {
      final metaFile = await _getSessionMetaFile();
      await metaFile.parent.create(recursive: true);
      await metaFile.writeAsString(jsonEncode({
        'version': kMemoryFileVersion,
        'sessions': _sessions,
        'current_session_id': _currentSessionId,
      }));
    } catch (_) {}
  }

  Future<void> _loadSessionMeta() async {
    try {
      final metaFile = await _getSessionMetaFile();
      if (await metaFile.exists()) {
        final data = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        if (data['sessions'] is Map) {
          _sessions.clear();
          (data['sessions'] as Map).forEach((k, v) => _sessions[k.toString()] = Map<String, dynamic>.from(v as Map));
        }
        _currentSessionId = data['current_session_id'] as String?;
      }
    } catch (_) {}
    if (_sessions.isEmpty) {
      createSession(name: '默认对话', mode: 'chat');
    }
  }

  /// 加载当前 session 的消息
  Future<void> _loadSessionMessages() async {
    final file = await _getCurrentSessionFile();
    try {
      if (await file.exists()) {
        _parseAndLoad(await file.readAsString());
        return;
      }
    } catch (_) {}
    // 没有数据，保持空状态
    _messages.clear();
    _totalPromptTokens = 0;
    _totalCompletionTokens = 0;
    _totalCacheHitTokens = 0;
    _totalCost = 0;
  }

  /// 尝试从旧格式迁移数据
  Future<void> _migrateOldFormat() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      // 旧格式: reasonix_chat.json
      final oldFile = File('${appDir.path}/reasonix_chat.json');
      if (await oldFile.exists()) {
        final raw = await oldFile.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (json.containsKey('messages') && (json['messages'] as List).isNotEmpty) {
          // 迁移到当前 session
          _parseAndLoad(raw);
          await _save();
          await oldFile.delete();
          debugPrint('旧格式数据迁移成功');
        }
      }

      // 旧格式: 项目目录下的 .reasonix_memory.json
      if (_projectProvider != null && _projectProvider!.hasProject) {
        final projectMemory = File(_projectProvider!.memoryFilePath!);
        if (await projectMemory.exists()) {
          final raw = await projectMemory.readAsString();
          final json = jsonDecode(raw) as Map<String, dynamic>;
          if (json.containsKey('messages') && (json['messages'] as List).isNotEmpty) {
            // 创建新 session 并迁入
            createSession(name: '迁移的对话', mode: 'chat');
            _parseAndLoad(raw);
            await _save();
            debugPrint('项目记忆迁移成功');
          }
        }
      }

      // 旧格式: 项目目录下的 .reasonix_sessions.json 和 .reasonix_session_*.json
      if (_projectProvider != null && _projectProvider!.hasProject) {
        final projectDir = _projectProvider!.rootPath;
        final oldMetaFile = File('$projectDir/.reasonix_sessions.json');
        if (await oldMetaFile.exists()) {
          final raw = await oldMetaFile.readAsString();
          final data = jsonDecode(raw) as Map<String, dynamic>;
          if (data['sessions'] is Map) {
            final oldSessions = data['sessions'] as Map;
            for (final entry in oldSessions.entries) {
              final oldId = entry.key.toString();
              final oldSessionFile = File('$projectDir/.reasonix_session_$oldId.json');
              if (await oldSessionFile.exists()) {
                // 复制到新位置
                final newFile = await _getSessionFile(oldId);
                await newFile.writeAsString(await oldSessionFile.readAsString());
                await oldSessionFile.delete();
              }
              // 添加到当前 sessions 列表（如果 ID 不重复）
              if (!_sessions.containsKey(oldId)) {
                _sessions[oldId] = Map<String, dynamic>.from(entry.value as Map);
              }
            }
            // 更新 current session id
            if (data['current_session_id'] != null) {
              _currentSessionId = data['current_session_id'] as String;
            }
            await _saveSessionMeta();
            await oldMetaFile.delete();
            debugPrint('旧 session 数据迁移成功');
          }
        }
      }
    } catch (e) {
      debugPrint('旧格式迁移失败: $e');
    }
  }

  /// 项目切换时的处理
  Future<void> _onProjectChanged() async {
    // 保存当前会话
    await _save();
    // 更新系统提示中的项目路径
    _updateSystemPrompt();
    notifyListeners();
  }

  // ========== 初始化和加载 ==========

  /// App 启动时调用，加载会话列表和上次的对话
  Future<void> init() async {
    await _loadSessionMeta();
    // 尝试迁移旧格式数据
    await _migrateOldFormat();
    // 加载当前 session 的消息
    if (_currentSessionId != null && _sessions.containsKey(_currentSessionId)) {
      await _loadSessionMessages();
      // 恢复当前对话绑定的项目
      final savedPath = _sessions[_currentSessionId]?['project_path'] as String?;
      if (savedPath != null && savedPath.isNotEmpty && _projectProvider != null) {
        if (!_projectProvider!.hasProject || _projectProvider!.rootPath != savedPath) {
          _projectProvider!.openProject(savedPath);
        }
      }
    }
    notifyListeners();
  }

  /// load() 用于项目切换等场景
  Future<void> load() async {
    await _loadSessionMeta();
    await _loadSessionMessages();
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
        imageBase64: msg['image_base64'] as String?,
      ));
    }
    _fixIncompleteToolCalls();
  }

  void _fixIncompleteToolCalls() {
    // 收集每个 assistant tool_calls 对应的 tool_call_id
    final assistantToolIds = <String>{};
    final validAssistantIndices = <int>{};
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (m.role == 'assistant' && m.toolCalls != null && m.toolCalls!.isNotEmpty) {
        final ids = m.toolCalls!.map((tc) => tc['id'] as String?).toSet();
        final allResponded = ids.every((id) {
          if (id == null) return false;
          return _messages.any((msg) => msg.role == 'tool' && msg.toolCallId == id);
        });
        if (allResponded) {
          validAssistantIndices.add(i);
          assistantToolIds.addAll(ids.whereType<String>());
        }
      }
    }

    // 移除不完整的 assistant 消息 + 孤立的 tool 结果
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.role == 'assistant' && m.toolCalls != null && m.toolCalls!.isNotEmpty) {
        if (!validAssistantIndices.contains(i)) {
          _messages.removeAt(i);
        }
      } else if (m.role == 'tool') {
        if (m.toolCallId != null && !assistantToolIds.contains(m.toolCallId)) {
          _messages.removeAt(i);
        }
      }
    }
  }

  Future<void> _save() async {
    final file = await _getCurrentSessionFile();
    try {
      final data = {
        'version': kMemoryFileVersion,
        'last_updated': DateTime.now().toIso8601String(),
        'messages': _messages.map((m) => {
          'role': m.role, 'content': m.content,
          if (m.toolCallId != null) 'tool_call_id': m.toolCallId,
          if (m.toolName != null) 'tool_name': m.toolName,
          if (m.toolCalls != null) 'tool_calls': m.toolCalls,
          if (m.imageBase64 != null) 'image_base64': m.imageBase64,
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
    _fixIncompleteToolCalls();
    _isProcessing = false; _isStreaming = false;
    _save();
    notifyListeners();
  }

  void addMessage(Message msg) {
    _messages.add(msg);
    _save();
    notifyListeners();
  }

  /// 更新系统提示
  /// [isProgramming] 可选覆盖，不传则用当前模式
  void _updateSystemPrompt({bool? isProgramming}) {
    final programming = isProgramming ?? _isProgrammingMode;
    final systemPrompt = programming
        ? _buildProgrammingPrompt()
        : '';

    final idx = _messages.indexWhere((m) => m.role == 'system');
    if (programming) {
      if (idx >= 0) {
        _messages[idx] = Message(role: 'system', content: systemPrompt);
      } else if (_messages.isNotEmpty) {
        _messages.insert(0, Message(role: 'system', content: systemPrompt));
      }
    } else {
      // 聊天模式 → 移除 system prompt
      if (idx >= 0) {
        _messages.removeAt(idx);
      }
    }
  }

  String _buildProgrammingPrompt() {
    final projectPath = _projectProvider?.rootPath ?? '';
    return projectPath.isNotEmpty
        ? '你是 Reasonix，一个手机上的 AI 编程助手。你擅长阅读代码、编辑文件、执行命令、管理 Git 仓库。请用中文回答，使用工具时直接调用工具，不要说"让我看看"。\n\n当前项目根目录: $projectPath\n所有文件操作都基于此目录，使用相对路径即可。'
        : '你是 Reasonix，一个手机上的 AI 编程助手。你擅长阅读代码、编辑文件、执行命令、管理 Git 仓库。请用中文回答，使用工具时直接调用工具，不要说"让我看看"。';
  }

  Future<void> sendMessage(String text, {String? imageBase64}) async {
    if (text.trim().isEmpty && imageBase64 == null) return;
    // 如果卡住了，强制重置
    if (_isProcessing) {
      _isProcessing = false;
      notifyListeners();
    }
    if (_llmService == null) return;

    _messages.add(Message(role: 'user', content: text.trim(), imageBase64: imageBase64));
    _isProcessing = true;
    _stopRequested = false;
    notifyListeners();

    if (!_isProgrammingMode) {
      // ── 聊天模式：纯聊天，不带工具，不加 system prompt ──
      try {
        final response = await _llmService!.chatComplete(_messages, includeTools: false);
        if (response.containsKey('error')) {
          _messages.add(Message(role: 'assistant', content: response['error'] as String));
        } else {
          final choice = response['choices']?[0] as Map<String, dynamic>?;
          final msg = choice?['message'] as Map<String, dynamic>?;
          final content = msg?['content'] as String? ?? '';
          if (content.isNotEmpty) {
            _messages.add(Message(role: 'assistant', content: content));
          }
        }
        _save();
      } catch (e) {
        _messages.add(Message(role: 'assistant', content: '出错: $e'));
        _save();
      } finally {
        _isProcessing = false;
        notifyListeners();
      }
      return;
    }

    // ── 编程模式：带 system prompt + 工具调用 ──
    if (_toolEngine == null) { _isProcessing = false; notifyListeners(); return; }
    _updateSystemPrompt();
    try {
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
      _fixIncompleteToolCalls();
    } catch (e) {
      _messages.add(Message(role: 'assistant', content: '执行出错: $e'));
      _fixIncompleteToolCalls();
      _save();
    } finally {
      _isProcessing = false; _isStreaming = false;
      _save();
      notifyListeners();
    }
  }

  /// 注入技能指令 — 将技能的 prompt 作为用户消息自动发送
  void injectSkill(Skill skill) {
    sendMessage(skill.prompt);
  }

  /// 注入知识文档 — 将知识内容作为参考信息发送
  void injectKnowledge(Knowledge knowledge) {
    sendMessage('请参考以下知识来回答：\n\n${knowledge.content}');
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

  Future<void> sendMessageWithImage(String text, File? image) async {
    if (image == null) {
      await sendMessage(text);
      return;
    }
    final bytes = await image.readAsBytes();
    final b64 = base64Encode(bytes);
    final msg = text.isNotEmpty ? text : '请分析这张图片';
    await sendMessage(msg, imageBase64: b64);
  }

  Future<String> exportChatAsJson() async {
    final file = await _getCurrentSessionFile();
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
      createSession(name: '导入的对话', mode: 'chat');
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
