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

/// 聊天页面 — Reasonix 核心对话界面
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _scrollController = ScrollController();
  final LlmService _llmService = LlmService();
  ToolEngine? _toolEngine;

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

    return Scaffold(
      appBar: AppBar(
        title: Row(
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
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空对话',
            onPressed: () => context.read<ChatProvider>().clearMessages(),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
        children: [
          // 提示条
          if (!hasProject || !hasApiKey)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                !hasProject
                    ? '📁 先去「文件」页选一个项目目录'
                    : '🔑 先去「设置」页配置 API Key',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
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
            enabled: hasProject && hasApiKey && !context.watch<ChatProvider>().isProcessing,
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
              '先选项目目录、配好 API Key\n然后在这里下指令就好',
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
}
