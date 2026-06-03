import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/terminal_provider.dart';
import '../services/terminal_service.dart';

/// 终端页面 — 命令执行界面
class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _outputLines = <String>[];
  bool _envChecked = false;
  bool _hasShell = true;

  @override
  void initState() {
    super.initState();
    _checkEnv();
  }

  Future<void> _checkEnv() async {
    final hasShell = await TerminalService.checkEnvironment();
    if (mounted) {
      setState(() {
        _hasShell = hasShell;
        _envChecked = true;
        _outputLines.addAll([
          '══ Reasonix Mobile Terminal ══',
          hasShell
              ? '✅ Shell 可用'
              : '⚠️ 未检测到 Shell（Android 需安装 Termux，iOS 不可用）',
          '',
        ]);
      });
    }
  }

  void _execute() async {
    final cmd = _controller.text.trim();
    if (cmd.isEmpty) return;

    setState(() {
      _outputLines.add('\$ $cmd');
    });
    _controller.clear();

    final terminal = context.read<TerminalProvider>();
    final result = await terminal.executeCommand(cmd);

    setState(() {
      _outputLines.addAll(result.split('\n'));
      _outputLines.add('');
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollPosition,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('终端'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '清屏',
            onPressed: () {
              setState(() {
                _outputLines.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 输出区域
          Expanded(
            child: Container(
              color: const Color(0xFF0D1117),
              child: _envChecked
                  ? ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _outputLines.length,
                      itemBuilder: (context, index) {
                        final line = _outputLines[index];
                        final isPrompt = line.startsWith('\$ ');
                        return Text(
                          line,
                          style: TextStyle(
                            color: isPrompt
                                ? const Color(0xFF00D9B0)
                                : const Color(0xFFCDD6F4),
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.5,
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
            ),
          ),

          // 输入区域
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            color: const Color(0xFF161B22),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Icon(
                    Icons.chevron_right,
                    color: const Color(0xFF00D9B0),
                    size: 20,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: _hasShell,
                      onSubmitted: (_) => _execute(),
                      style: const TextStyle(
                        color: Color(0xFFCDD6F4),
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        hintText: '输入命令...',
                        hintStyle: TextStyle(
                          color: Color(0xFF484F58),
                          fontFamily: 'monospace',
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
