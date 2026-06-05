import 'dart:io';
import 'dart:convert';
import '../models/file_node.dart';

class FileService {
  String? _projectRoot;

  set projectRoot(String? path) => _projectRoot = path;
  String? get projectRoot => _projectRoot;

  String _resolve(String path) {
    if (_projectRoot == null) return path;
    if (path.isEmpty || path == '/') return _projectRoot!;
    if (path.startsWith('/')) return path;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$_projectRoot/$cleanPath';
  }

  Future<String> readFile(String path) async {
    final file = File(_resolve(path));
    if (!await file.exists()) throw Exception('File not found: $path');
    return await file.readAsString();
  }

  Future<void> writeFile(String path, String content) async {
    final file = File(_resolve(path));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  Future<void> editFile(String path, String search, String replace) async {
    final content = await readFile(path);
    if (content.indexOf(search) == -1) throw Exception('SEARCH text not found in $path');
    await File(_resolve(path)).writeAsString(content.replaceFirst(search, replace));
  }

  List<FileNode> listDirectory(String path) {
    final dir = Directory(_resolve(path));
    if (!dir.existsSync()) return [];
    return dir.listSync()
      .where((e) => !_isIgnored(e.uri.pathSegments.last))
      .map(_toFileNode).toList()
      ..sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  bool _isIgnored(String name) {
    const ignored = ['.git', '.dart_tool', '.packages', '.pub-cache', 'node_modules', '.reasonix_memory.json'];
    return ignored.contains(name) || name.startsWith('.');
  }

  FileNode _toFileNode(FileSystemEntity entity) {
    final stat = entity.statSync();
    return FileNode(
      name: entity.uri.pathSegments.last,
      path: _toRelativePath(entity.path),
      isDirectory: entity is Directory,
    );
  }

  List<Map<String, dynamic>> searchContent(String pattern, {String? path, bool caseSensitive = false, int context = 0}) {
    final root = path != null ? _resolve(path) : _projectRoot;
    if (root == null) return [];
    final regex = RegExp(pattern, caseSensitive: caseSensitive, multiLine: true);
    final results = <Map<String, dynamic>>[];
    _grep(Directory(root), regex, results, context);
    return results;
  }

  void _grep(Directory dir, RegExp regex, List<Map<String, dynamic>> results, int context) {
    try {
      for (final entity in dir.listSync()) {
        final name = entity.uri.pathSegments.last;
        if (_isIgnored(name)) continue;
        if (entity is File) _searchInFile(entity, regex, results, context);
        else if (entity is Directory) _grep(entity, regex, results, context);
      }
    } catch (_) {}
  }

  void _searchInFile(File file, RegExp regex, List<Map<String, dynamic>> results, int context) {
    try {
      final lines = file.readAsLinesSync();
      int hitCount = 0;
      for (int i = 0; i < lines.length && hitCount < 30; i++) {
        if (regex.hasMatch(lines[i])) {
          hitCount++;
          // 返回相对路径
          final relativePath = _toRelativePath(file.path);
          results.add({'path': relativePath, 'line': i + 1, 'text': lines[i]});
        }
      }
    } catch (_) {}
  }

  /// 将绝对路径转为相对于项目根的路径
  String _toRelativePath(String absolutePath) {
    if (_projectRoot != null && absolutePath.startsWith(_projectRoot!)) {
      return absolutePath.substring(_projectRoot!.length);
    }
    return absolutePath;
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
        if (_isIgnored(name)) continue;
        if (name.toLowerCase().contains(pattern)) results.add(_toRelativePath(entity.path));
        if (entity is Directory) _walkFiles(entity, results, pattern);
      }
    } catch (_) {}
  }

  Future<void> deleteFile(String path) async {
    final file = File(_resolve(path));
    if (!await file.exists()) throw Exception('File not found: $path');
    await file.delete();
  }

  Future<void> createDirectory(String path) async {
    final dir = Directory(_resolve(path));
    await dir.create(recursive: true);
  }

  Future<Map<String, dynamic>> getFileInfo(String path) async {
    final file = File(_resolve(path));
    if (!await file.exists()) throw Exception('File not found: $path');
    final stat = await file.stat();
    return {
      'path': path,
      'size': stat.size,
      'modified': stat.modified.toIso8601String(),
      'type': stat.type == FileSystemEntityType.directory ? 'directory' : 'file',
    };
  }
}
