import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/project_provider.dart';
import '../providers/chat_provider.dart';
import '../services/terminal_service.dart';
import '../services/git_service.dart';
import '../services/llm_service.dart';
import '../widgets/project_picker.dart';
import 'package:url_launcher/url_launcher.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _envInfo = '';

  @override
  void initState() {
    super.initState();
    _loadEnv();
  }

  Future<void> _loadEnv() async {
    final info = await TerminalService.getEnvironmentInfo();
    if (mounted) {
      setState(() => _envInfo = info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final project = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── API 配置 ──
          _sectionTitle(context, 'API 配置'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SecuredTextField(
                    label: 'API Key',
                    hint: 'sk-...',
                    icon: Icons.key,
                    value: settings.apiKey,
                    onChanged: (v) => settings.setApiKey(v.trim()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'API 地址',
                      hintText: 'https://api.deepseek.com/v1',
                      prefixIcon: Icon(Icons.link),
                    ),
                    controller: TextEditingController(text: settings.apiBaseUrl),
                    onChanged: (v) => settings.setApiBaseUrl(v.trim()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '模型',
                      hintText: 'deepseek-chat',
                      prefixIcon: Icon(Icons.memory),
                    ),
                    controller: TextEditingController(text: settings.apiModel),
                    onChanged: (v) => settings.setApiModel(v.trim()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        settings.hasApiKey ? Icons.check_circle : Icons.error_outline,
                        size: 14,
                        color: settings.hasApiKey ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        settings.hasApiKey ? '已配置' : '未配置 API Key',
                        style: TextStyle(
                          fontSize: 12,
                          color: settings.hasApiKey ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 项目 ──
          _sectionTitle(context, '项目'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (project.hasProject) ...[
                    Row(
                      children: [
                        const Icon(Icons.folder, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            project.rootPath,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => project.closeProject(),
                          child: const Text('关闭'),
                        ),
                      ],
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickProject,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('选择项目目录'),
                      ),
                    ),
                  ],
                  if (settings.lastProjectPath.isNotEmpty && !project.hasProject)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: InkWell(
                        onTap: () {
                          project.openProject(settings.lastProjectPath);
                        },
                        child: Row(
                          children: [
                            Icon(Icons.history, size: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                            const SizedBox(width: 6),
                            Text(
                              '上次: ${settings.lastProjectPath.split(Platform.pathSeparator).last}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 主题 ──
          _sectionTitle(context, '外观'),
          Card(
            child: SwitchListTile(
              title: const Text('深色模式'),
              subtitle: Text(
                settings.themeMode == ThemeMode.dark ? '当前: 深色' : '当前: 浅色',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              value: settings.themeMode == ThemeMode.dark,
              onChanged: (v) {
                settings.setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ),
          const SizedBox(height: 24),

          // ── 运行环境 ──
          _sectionTitle(context, '运行环境'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_envInfo.isNotEmpty)
                    Text(
                      _envInfo,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Android 上需要安装 Termux 才能执行 shell 命令。\n聊天和文件操作不需要。',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 文件权限 ──
          _sectionTitle(context, '文件权限'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Android 11+ 需要授予「所有文件访问权限」才能读写项目文件。'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openAppSettings,
                      icon: const Icon(Icons.settings),
                      label: const Text('前往设置授予权限'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 用量 ──
          _sectionTitle(context, '用量'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('查询余额'),
              subtitle: const Text('查看 API 账户余额'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _checkBalance(),
            ),
          ),
          const SizedBox(height: 24),

          // ── 记忆管理 ──
          _sectionTitle(context, '记忆管理'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Consumer<ChatProvider>(
                builder: (context, chat, _) {
                  final stats = chat.usageStats;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('用量统计', style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      )),
                      const SizedBox(height: 8),
                      _statRow(Icons.input, '输入 Tokens', '${stats['prompt_tokens']}'),
                      _statRow(Icons.output, '输出 Tokens', '${stats['completion_tokens']}'),
                      _statRow(Icons.attach_money, '预估费用',
                          '\$${(stats['total_cost'] as double).toStringAsFixed(4)}'),
                      _statRow(Icons.message, '消息数', '${stats['message_count']}'),
                      _statRow(Icons.history, '会话数', '${stats['session_count']}'),
                      if (chat.projectMemoryPath != null) ...[
                        const SizedBox(height: 8),
                        _statRow(Icons.folder, '记忆文件',
                            chat.projectMemoryPath!.split('/').last),
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.file_download_outlined, size: 18),
                              label: const Text('导出 JSON', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final json = await chat.exportChatAsJson();
                                await Clipboard.setData(ClipboardData(text: json));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('✅ JSON 已复制到剪贴板')),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.text_snippet_outlined, size: 18),
                              label: const Text('导出文本', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final text = await chat.exportChatAsText();
                                await Clipboard.setData(ClipboardData(text: text));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('✅ 文本已复制到剪贴板')),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.file_upload_outlined, size: 18),
                              label: const Text('导入', style: TextStyle(fontSize: 12)),
                              onPressed: () => _importChat(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.delete_sweep, size: 18),
                              label: const Text('清空对话', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('清空对话'),
                                    content: const Text('确定清空当前对话？'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                                      FilledButton(
                                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () {
                                          context.read<ChatProvider>().clearMessages();
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text('清空'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 关于 ──
          _sectionTitle(context, '关于'),
          Card(
            child: ListTile(
              title: const Text('Reasonix Mobile'),
              subtitle: const Text('v0.2.0 · 手机端 AI 编程助手'),
              leading: const Icon(Icons.auto_awesome, color: Color(0xFF6C63FF)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _importChat(BuildContext context) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入对话'),
        content: TextField(
          controller: c, maxLines: 6,
          decoration: const InputDecoration(
            hintText: '粘贴 JSON...',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (c.text.trim().isEmpty) return;
              final ok = await context.read<ChatProvider>().importChatFromJson(c.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '✅ 导入成功' : '❌ 失败，请检查 JSON 格式')),
                );
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAppSettings() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 5),
        content: Text('请手动操作: 系统设置 → 应用 → Reasonix → 权限 → 所有文件访问权限 → 允许'),
      ),
    );
  }

  Future<void> _checkBalance() async {
    final settings = context.read<SettingsProvider>();
    final llm = LlmService();
    final balanceBaseUrl = settings.apiBaseUrl;
    llm.configure(apiKey: settings.apiKey, baseUrl: balanceBaseUrl, model: settings.apiModel);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('查询余额'),
        content: const SizedBox(
          width: 60, height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    final result = await llm.checkBalance();
    if (!mounted) return;
    Navigator.of(context).pop();

    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result['error']}')),
      );
      return;
    }

    final balanceInfo = StringBuffer();
    if (result['balance_infos'] is List) {
      for (final b in result['balance_infos'] as List) {
        final m = b as Map<String, dynamic>;
        balanceInfo.writeln('${m['total_balance'] ?? '?'} ${m['currency'] ?? '元'}');
      }
    } else {
      balanceInfo.writeln('余额: ${result['balance'] ?? '未知'}');
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('账户余额'),
        content: Text(balanceInfo.toString()),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('确定')),
        ],
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
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

/// 安全输入框 — 支持切换显示/隐藏
/// 隐藏时使用 obscureText，显示时关闭 obscureText（使用用户设置的键盘）
class _SecuredTextField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final String value;
  final ValueChanged<String> onChanged;

  const _SecuredTextField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SecuredTextField> createState() => _SecuredTextFieldState();
}

class _SecuredTextFieldState extends State<_SecuredTextField> {
  bool _visible = true;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SecuredTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      obscureText: !_visible,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: Icon(widget.icon),
        suffixIcon: IconButton(
          icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
          tooltip: _visible ? '隐藏' : '显示',
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}
