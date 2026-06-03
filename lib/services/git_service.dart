import 'dart:io';
import 'dart:convert';

/// Git 操作服务 — 通过系统 git 命令实现
class GitService {
  String? _projectRoot;

  set projectRoot(String? path) => _projectRoot = path;
  String? get projectRoot => _projectRoot;

  bool get isAvailable {
    try {
      final result = Process.runSync('git', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  bool get isRepo {
    if (_projectRoot == null) return false;
    return Directory('$_projectRoot/.git').existsSync();
  }

  Future<String> _git(List<String> args) async {
    try {
      final result = await Process.run(
        'git',
        args,
        workingDirectory: _projectRoot,
        runInShell: true,
      );
      final out = (result.stdout as String).trim();
      final err = (result.stderr as String).trim();
      if (result.exitCode != 0) {
        return 'Git 错误: $err';
      }
      return out;
    } catch (e) {
      return 'Git 执行失败: $e';
    }
  }

  Future<String> status() => _git(['status', '--short']);
  Future<String> log({int count = 10}) => _git(['log', '--oneline', '-n', '$count']);
  Future<String> diff() => _git(['diff']);
  Future<String> diffStaged() => _git(['diff', '--staged']);
  Future<String> branch() => _git(['branch', '-a']);
  Future<String> remote() => _git(['remote', '-v']);

  Future<String> add(String path) => _git(['add', path]);
  Future<String> commit(String message) => _git(['commit', '-m', message]);
  Future<String> push() => _git(['push']);
  Future<String> pull() => _git(['pull']);

  Future<String> showFile(String path) => _git(['show', 'HEAD:$path']);

  Future<String> init() async {
    if (_projectRoot == null) return '错误: 未设置项目根';
    try {
      await Process.run('git', ['init'], workingDirectory: _projectRoot);
      return 'Git 仓库已初始化';
    } catch (e) {
      return '初始化失败: $e';
    }
  }

  /// 当前分支名
  Future<String> currentBranch() async {
    return await _git(['rev-parse', '--abbrev-ref', 'HEAD']);
  }
}
