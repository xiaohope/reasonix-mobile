import 'dart:convert';
import 'dart:io';

/// 终端命令执行服务
/// 在 Android 上通过 Process 启动 shell 执行命令
/// 在 iOS 上仅提供提示信息（iOS 无通用 shell）
class TerminalService {
  Process? _process;
  String _lastOutput = '';
  bool _isRunning = false;

  bool get isRunning => _isRunning;
  String get lastOutput => _lastOutput;

  /// 执行单条命令并返回输出
  Future<String> executeCommand(String command) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? 'cmd' : 'sh',
        [
          Platform.isWindows ? '/c' : '-c',
          command,
        ],
        runInShell: true,
        workingDirectory: _cwd,
      );

      final out = (result.stdout as String).trim();
      final err = (result.stderr as String).trim();
      _lastOutput = out + (err.isNotEmpty ? '\n$err' : '');
      return _lastOutput;
    } catch (e) {
      final msg = '命令执行失败: $e\n'
          '提示: Android 上需要安装 Termux。\n'
          'iOS 上此功能不可用。';
      _lastOutput = msg;
      return msg;
    }
  }

  String _cwd = '/';

  set workingDirectory(String path) {
    _cwd = path;
  }

  /// 检测环境是否支持运行命令
  static Future<bool> checkEnvironment() async {
    if (Platform.isIOS) return false;
    try {
      final result = await Process.run('sh', ['-c', 'echo ok']);
      return (result.stdout as String).trim() == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// 获取环境信息
  static Future<String> getEnvironmentInfo() async {
    final buf = StringBuffer();
    buf.writeln('平台: ${Platform.operatingSystem}');
    buf.writeln('版本: ${Platform.operatingSystemVersion}');
    try {
      final result = await Process.run('sh', ['-c', 'echo "$SHELL"']);
      buf.writeln('Shell: ${(result.stdout as String).trim()}');
    } catch (_) {
      buf.writeln('Shell: 不可用');
    }
    return buf.toString();
  }

  void dispose() {
    _process?.kill();
    _process = null;
    _isRunning = false;
  }
}
