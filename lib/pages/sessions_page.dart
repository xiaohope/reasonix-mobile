import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import 'package:flutter/services.dart';

/// 会话管理页面 — 创建、切换、重命名、删除会话
class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('对话管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建对话',
            onPressed: () {
              final mode = chatProvider.isProgrammingMode ? 'programming' : 'chat';
              chatProvider.createSession(name: '新对话 ${chatProvider.sessions.length + 1}', mode: mode);
              chatProvider.onSwitchToChat?.call();
            },
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.import_export),
                  title: Text('导出当前对话'),
                  dense: true,
                ),
                onTap: () => _exportCurrentChat(context, chatProvider),
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.import_export),
                  title: Text('导入对话'),
                  dense: true,
                ),
                onTap: () => _importChat(context, chatProvider),
              ),
            ],
          ),
        ],
      ),
      body: chatProvider.sessions.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无对话', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: chatProvider.sessions.length,
              itemBuilder: (context, index) {
                final session = chatProvider.sessions[index];
                final isCurrent = session['id'] == chatProvider.currentSessionId;
                return Card(
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.chat,
                        color: isCurrent ? Colors.white : null,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      session['name'] as String? ?? '未命名',
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      _formatTime(session['updated_at'] as String? ?? ''),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isCurrent
                        ? const Chip(
                            label: Text('当前', style: TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                    onTap: () async {
                      if (!isCurrent) {
                        await chatProvider.switchSession(session['id'] as String);
                        chatProvider.onSwitchToChat?.call();
                      }
                    },
                    onLongPress: () => _showSessionMenu(context, chatProvider, session),
                  ),
                );
              },
            ),
    );
  }

  void _showSessionMenu(
      BuildContext context, ChatProvider chatProvider, Map<String, dynamic> session) {
    final id = session['id'] as String;
    final isCurrent = id == chatProvider.currentSessionId;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.of(ctx).pop();
                _renameSession(context, chatProvider, id, session['name'] as String? ?? '');
              },
            ),
            if (!isCurrent)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('切换到该对话'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await chatProvider.switchSession(id);
                  chatProvider.onSwitchToChat?.call();
                },
              ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('导出为 JSON'),
              onTap: () {
                Navigator.of(ctx).pop();
                _exportCurrentChat(context, chatProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDelete(context, chatProvider, id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _renameSession(BuildContext context, ChatProvider chatProvider,
      String sessionId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入新名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                chatProvider.renameSession(sessionId, controller.text.trim());
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, ChatProvider chatProvider, String sessionId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: const Text('确定要删除这个对话吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await chatProvider.deleteSession(sessionId);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCurrentChat(
      BuildContext context, ChatProvider chatProvider) async {
    try {
      final json = await chatProvider.exportChatAsJson();
      await Clipboard.setData(ClipboardData(text: json));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 对话已复制到剪贴板 (JSON 格式)'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _importChat(
      BuildContext context, ChatProvider chatProvider) async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入对话'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '粘贴 JSON 格式的对话内容...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final success = await chatProvider.importChatFromJson(controller.text.trim());
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '✅ 导入成功' : '❌ 导入失败，请检查 JSON 格式'),
                  ),
                );
                if (success) chatProvider.onSwitchToChat?.call();
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoTime) {
    if (isoTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
      if (diff.inDays < 1) return '${diff.inHours} 小时前';
      if (diff.inDays < 7) return '${diff.inDays} 天前';
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
