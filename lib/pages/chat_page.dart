import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/project_provider.dart';
import '../providers/terminal_provider.dart';
import '../services/llm_service.dart';
import '../services/tool_engine.dart';
import '../services/skill_service.dart';
import '../models/skill.dart';
import '../widgets/project_picker.dart';

/// 聊天页面 — Reasonix 核心对话界面
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _scrollController = ScrollController();
  final LlmService _llmService = LlmService();
  final SkillService _skillService = SkillService();
  ToolEngine? _toolEngine;
  bool _skillsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final settings = context.read<SettingsProvider>();
    _llmService.configure(
      apiKey: settings.apiKey,
      baseUrl: settings.apiBaseUrl,
      model: settings.apiModel,
    );

    final chatProvider = context.read<ChatProvider>();
    final projectProvider = context.read<ProjectProvider>();

    _toolEngine = ToolEngine(
      fileService: projectProvider.fileService,
      terminalService: context.read<TerminalProvider>().service,
    );

    chatProvider.initServices(_llmService, _toolEngine!);

    if (!_skillsLoaded) {
      _skillsLoaded = true;
      _skillService.init();
    }
  }

  void _sendMessage(String text) async {
    final chat = context.read<ChatProvider>();
    await chat.sendMessage(text);
    _scrollToBottom();
  }

  void _sendWithImage({String? text, dynamic image}) async {
    final chat = context.read<ChatProvider>();
    await chat.sendMessageWithImage(text ?? '', image);
    _scrollToBottom();
  }

  Future<void> _showSkillPicker() async {
    await _skillService.refresh();
    final isProgramming = context.read<ChatProvider>().isProgrammingMode;
    final skills = _skillService.skills.where((s) =>
        isProgramming || s.category == 'general').toList();
    if (skills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可用的技能'), duration: Duration(seconds: 2)),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 18),
                  const SizedBox(width: 8),
                  Text('选择技能', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 技能列表
            ...skills.map((skill) => ListTile(
              leading: Text(skill.icon ?? '🧠', style: const TextStyle(fontSize: 24)),
              title: Text(skill.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(skill.description, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.of(ctx).pop();
                context.read<ChatProvider>().injectSkill(skill);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _pickProject() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectoryBrowser(
          initialPath: '/storage/emulated/0',
          onSelected: (path) {
            context.read<ProjectProvider>().openProject(path);
            context.read<SettingsProvider>().setLastProjectPath(path);
            // 绑定项目到当前对话
            context.read<ChatProvider>().setCurrentSessionProjectPath(path);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final isProgramming = chatProvider.isProgrammingMode;
    final hasProject = context.watch<ProjectProvider>().hasProject;
    final hasApiKey = context.watch<SettingsProvider>().hasApiKey;
    final needsProject = isProgramming && !hasProject;

    final project = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(context, isProgramming, hasProject, project),
        actions: [
          if (isProgramming && !hasProject)
            TextButton.icon(
              onPressed: _pickProject,
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('选择项目', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
        children: [
          // 提示条
          if (needsProject || !hasApiKey)
            GestureDetector(
              onTap: needsProject ? _pickProject : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      needsProject ? Icons.folder_open : Icons.key,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      needsProject
                          ? '点击选择项目目录'
                          : '🔑 先去「设置」页配置 API Key',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: needsProject ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (needsProject) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 14,
                          color: Theme.of(context).colorScheme.primary),
                    ],
                  ],
                ),
              ),
            ),

          // 用量统计栏
          Consumer<ChatProvider>(
            builder: (context, chat, _) {
              final summary = chat.usageSummary;
              if (summary.isEmpty) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bar_chart, size: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        summary,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // 消息列表
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chat, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                if (chat.messages.isEmpty && chat.streamingMessage == null) {
                  return _buildEmptyState(context);
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: chat.messages.length + (chat.streamingMessage != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == chat.messages.length && chat.streamingMessage != null) {
                      return MessageBubble(message: chat.streamingMessage!);
                    }
                    return MessageBubble(message: chat.messages[index]);
                  },
                );
              },
            ),
          ),

          // 停止按钮
          Consumer<ChatProvider>(
            builder: (context, chat, _) {
              if (!chat.isProcessing) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => chat.stop(),
                    icon: const Icon(Icons.stop_circle, color: Colors.red),
                    label: const Text('停止生成', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              );
            },
          ),
          // 模式切换栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                _buildModeTab(context, '💬 聊天', false),
                const SizedBox(width: 4),
                _buildModeTab(context, '💻 编程', true),
              ],
            ),
          ),
          // 输入框
          ChatInput(
            onSend: _sendMessage,
            onSendWithImage: _sendWithImage,
            onSkillTap: _showSkillPicker,
            enabled: (isProgramming ? hasProject : true) && hasApiKey && !chatProvider.isProcessing,
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, bool isProgramming, bool hasProject, ProjectProvider project) {
    return GestureDetector(
      onTap: isProgramming && hasProject ? _pickProject : null,
      child: isProgramming && hasProject
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        project.rootPath.split('/').last,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                  ],
                ),
                Text(
                  project.rootPath,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          : Row(
              children: [
                const Text('Reasonix'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Mobile',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildModeTab(BuildContext context, String label, bool isProgramming) {
    final active = context.watch<ChatProvider>().isProgrammingMode == isProgramming;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          context.read<ChatProvider>().setMode(isProgramming);
          // 切换到编程模式且没有项目 → 弹出项目选择
          if (isProgramming && !context.read<ProjectProvider>().hasProject) {
            _pickProject();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isProgramming = context.watch<ChatProvider>().isProgrammingMode;
    final hasProject = context.watch<ProjectProvider>().hasProject;
    final hasApiKey = context.watch<SettingsProvider>().hasApiKey;

    if (!isProgramming) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 48,
                color: Color(0xFF6C63FF)),
            const SizedBox(height: 16),
            Text(
              '💬 聊天模式',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                !hasApiKey
                    ? '配好 API Key 后就可以聊天了'
                    : '有什么想问的吗？直接输入就好',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '💻 编程模式',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              !hasProject
                  ? '先选一个项目目录，让 AI 帮你\n读代码、改文件'
                  : !hasApiKey
                      ? '配好 API Key 后\n在这里下指令就好'
                      : '选一个项目，开始编程吧',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          if (!hasProject) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _pickProject,
              icon: const Icon(Icons.folder_open),
              label: const Text('选择项目目录'),
            ),
          ],
        ],
      ),
    );
  }
}
