import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/project_provider.dart';
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
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      hintText: 'sk-...',
                      prefixIcon: Icon(Icons.key),
                    ),
                    obscureText: true,
                    controller: TextEditingController(text: settings.apiKey),
                    onSubmitted: (v) => settings.setApiKey(v.trim()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'API 地址',
                      hintText: 'https://api.deepseek.com/v1',
                      prefixIcon: Icon(Icons.link),
                    ),
                    controller: TextEditingController(text: settings.apiBaseUrl),
                    onSubmitted: (v) => settings.setApiBaseUrl(v.trim()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '模型',
                      hintText: 'deepseek-chat',
                      prefixIcon: Icon(Icons.memory),
                    ),
                    controller: TextEditingController(text: settings.apiModel),
                    onSubmitted: (v) => settings.setApiModel(v.trim()),
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
                  // 最近项目历史
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

          // ── 关于 ──
          _sectionTitle(context, '关于'),
          Card(
            child: ListTile(
              title: const Text('Reasonix Mobile'),
              subtitle: const Text('v0.1.0 · 手机端 AI 编程助手'),
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

  Future<void> _openAppSettings() async {
    try {
      await launchUrl(Uri.parse('android.settings.MANAGE_APPLICATIONS_SETTINGS'));
    } catch (_) {
      try {
        await launchUrl(Uri.parse('android.settings.APPLICATION_DETAILS_SETTINGS'));
      } catch (_) {}
    }
  }

  Future<void> _checkBalance() async {
    final settings = context.read<SettingsProvider>();
    final llm = LlmService();
    llm.configure(apiKey: settings.apiKey, baseUrl: settings.apiBaseUrl, model: settings.apiModel);

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
    Navigator.of(context).pop(); // 关闭加载弹窗

    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result['error']}')),
      );
      return;
    }

    // 显示余额信息
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
