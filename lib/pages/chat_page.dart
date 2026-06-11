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
    final skills = _skillService.skills;
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
    final hasProject = context.watch<ProjectProvider>().hasProject;
    final hasApiKey = context.watch<SettingsProvider>().hasApiKey;

    final project = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: hasProject ? _pickProject : null,
          child: hasProject
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
        ),
        actions: [
          if (!hasProject)
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
          if (!hasProject || !hasApiKey)
            GestureDetector(
              onTap: !hasProject ? _pickProject : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      !hasProject ? Icons.folder_open : Icons.key,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      !hasProject
                          ? '点击选择项目目录'
                          : '🔑 先去「设置」页配置 API Key',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: !hasProject ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (!hasProject) ...[
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
          // 输入框
          ChatInput(
            onSend: _sendMessage,
            onSendWithImage: _sendWithImage,
            onSkillTap: _showSkillPicker,
            enabled: hasProject && hasApiKey && !context.watch<ChatProvider>().isProcessing,
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final hasProject = context.watch<ProjectProvider>().hasProject;
    final hasApiKey = context.watch<SettingsProvider>().hasApiKey;

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
            '手机上的 AI 编程助手',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              !hasProject
                  ? '先选一个项目目录，然后就可以\n用 AI 帮你读代码、改文件了'
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
