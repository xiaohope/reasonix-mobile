import 'dart:io';
import 'dart:convert';
import '../models/file_node.dart';

class FileService {
  String? _projectRoot;

  set projectRoot(String? path) => _projectRoot = path;
  String? get projectRoot => _projectRoot;

  String _resolve(String path) {
    if (_projectRoot == null) return path;
    // 如果是项目根路径本身，直接返回
    if (path == _projectRoot) return _projectRoot!;
    // 空路径或 / = 项目根
    if (path.isEmpty || path == '/') return _projectRoot!;
    // 去掉开头的 /，拼接到项目根
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$_projectRoot/$cleanPath';
  }

  Future<String> readFile(String path) async {
    final file = File(_resolve(path));
    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }
    return await file.readAsString();
  }

  Future<void> writeFile(String path, String content) async {
    final file = File(_resolve(path));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  Future<void> editFile(String path, String search, String replace) async {
    final content = await readFile(path);
    final idx = content.indexOf(search);
    if (idx == -1) {
      throw Exception('SEARCH text not found in $path');
    }
    final newContent = content.replaceFirst(search, replace);
    await File(_resolve(path)).writeAsString(newContent);
  }

  List<FileNode> listDirectory(String path) {
    final dir = Directory(_resolve(path));
    if (!dir.existsSync()) return [];
    return dir.listSync().map(FileNode.fromEntity).toList()
      ..sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  List<Map<String, dynamic>> searchContent(String pattern, {String? path, bool caseSensitive = false, int context = 0}) {
    final root = path != null ? _resolve(path) : _projectRoot;
    if (root == null) return [];
    final results = <Map<String, dynamic>>[];
    final regex = RegExp(pattern, caseSensitive: caseSensitive, multiLine: true);
    _grep(Directory(root), regex, results, context);
    return results;
  }

  void _grep(Directory dir, RegExp regex, List<Map<String, dynamic>> results, int context) {
    try {
      for (final entity in dir.listSync()) {
        final name = entity.uri.pathSegments.last;
        if (FileNode.isIgnored(name)) continue;
        if (entity is File) {
          _searchInFile(entity, regex, results, context);
        } else if (entity is Directory) {
          _grep(entity, regex, results, context);
        }
      }
    } catch (_) {}
  }

  void _searchInFile(File file, RegExp regex, List<Map<String, dynamic>> results, int context) {
    try {
      final lines = file.readAsLinesSync();
      int hitCount = 0;
      for (int i = 0; i < lines.length; i++) {
        if (regex.hasMatch(lines[i])) {
          hitCount++;
          results.add({'path': file.path, 'line': i + 1, 'text': lines[i]});
          if (hitCount >= 30) break;
        }
      }
    } catch (_) {}
  }

  List<String> searchFiles(String pattern) {
    final root = _projectRoot;
    if (root == null) return [];
    final results = <String>[];
    _walkFiles(Directory(root), results, pattern.toLowerCase());
    return results;
  }

  void _walkFiles(Directory dir, List<String> results, String pattern) {
    try {
      for (final entity in dir.listSync()) {
        final name = entity.uri.pathSegments.last;
        if (FileNode.isIgnored(name)) continue;
        if (name.toLowerCase().contains(pattern)) results.add(entity.path);
        if (entity is Directory) _walkFiles(entity, results, pattern);
      }
    } catch (_) {}
  }

  Map<String, dynamic>? getFileInfo(String path) {
    final file = File(_resolve(path));
    if (!file.existsSync()) return null;
    final stat = file.statSync();
    return {'path': path, 'size': stat.size, 'modified': stat.modified.toIso8601String(), 'type': stat.type == FileSystemEntityType.directory ? 'directory' : 'file'};
  }

  Future<void> deleteFile(String path) async {
    final resolved = _resolve(path);
    final file = File(resolved);
    final dir = Directory(resolved);
    if (await file.exists()) { await file.delete(); }
    else if (await dir.exists()) { await dir.delete(recursive: true); }
  }

  Future<void> createDirectory(String path) async {
    await Directory(_resolve(path)).create(recursive: true);
  }

  Future<void> moveFile(String from, String to) async {
    await File(_resolve(from)).rename(_resolve(to));
  }
}
