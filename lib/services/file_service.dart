import 'dart:io';
import 'dart:convert';
import '../models/file_node.dart';

/// 鏂囦欢璇诲啓鎼滅储鏈嶅姟 鈥?Reasonix 鏍稿績鑳藉姏鐨勬湰鍦板疄鐜?class FileService {
  String? _projectRoot;

  set projectRoot(String? path) => _projectRoot = path;
  String? get projectRoot => _projectRoot;

  // 鈹€鈹€ Resolve path 鈹€鈹€
  String _resolve(String path) {
    if (path.startsWith('/') && _projectRoot != null) {
      return '$_projectRoot$path';
    }
    if (!path.startsWith('/') && _projectRoot != null) {
      return '$_projectRoot/$path';
    }
    return path;
  }

  // 鈹€鈹€ Read 鈹€鈹€
  Future<String> readFile(String path) async {
    final file = File(_resolve(path));
    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }
    return await file.readAsString();
  }

  String readFileSync(String path) {
    final file = File(_resolve(path));
    if (!file.existsSync()) {
      throw Exception('File not found: $path');
    }
    return file.readAsStringSync();
  }

  // 鈹€鈹€ Write 鈹€鈹€
  Future<void> writeFile(String path, String content) async {
    final file = File(_resolve(path));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  // 鈹€鈹€ Edit (SEARCH/REPLACE) 鈹€鈹€
  Future<void> editFile(String path, String search, String replace) async {
    final content = await readFile(path);
    final idx = content.indexOf(search);
    if (idx == -1) {
      throw Exception('SEARCH text not found in $path');
    }
    final newContent = content.replaceFirst(search, replace);
    await File(_resolve(path)).writeAsString(newContent);
  }

  // 鈹€鈹€ List directory 鈹€鈹€
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

  /// 閫掑綊鍒楀嚭鐩綍鏍戯紙鐢ㄤ簬鏂囦欢娴忚鍣級
  List<FileNode> listTree(String path, {int maxDepth = 3}) {
    final result = <FileNode>[];
    _walk(Directory(_resolve(path)), result, 0, maxDepth);
    return result;
  }

  void _walk(Directory dir, List<FileNode> result, int depth, int maxDepth) {
    if (depth > maxDepth) return;
    try {
      for (final entity in dir.listSync()) {
        final name = entity.uri.pathSegments.last;
        if (FileNode.isIgnored(name)) continue;
        final node = FileNode.fromEntity(entity);
        result.add(node);
        if (entity is Directory && depth < maxDepth) {
          _walk(entity, result, depth + 1, maxDepth);
        }
      }
    } catch (_) {}
  }

  // 鈹€鈹€ Search content (grep) 鈹€鈹€
  List<Map<String, dynamic>> searchContent(
    String pattern, {
    String? path,
    bool caseSensitive = false,
    int context = 0,
  }) {
    final root = path != null ? _resolve(path) : _projectRoot;
    if (root == null) return [];
    final results = <Map<String, dynamic>>[];
    final regex = RegExp(
      pattern,
      caseSensitive: caseSensitive,
      multiLine: true,
    );
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
          final entry = <String, dynamic>{
            'path': file.path,
            'line': i + 1,
            'text': lines[i],
          };
          if (context > 0) {
            final start = (i - context).clamp(0, lines.length);
            final end = (i + context + 1).clamp(0, lines.length);
            entry['context'] = lines.sublist(start, end);
          }
          results.add(entry);
          if (hitCount >= 30) break; // cap per file
        }
      }
    } catch (_) {}
  }

  // 鈹€鈹€ Search files by name 鈹€鈹€
  List<String> searchFiles(String pattern) {
    final root = _projectRoot;
    if (root == null) return [];
    final results = <String>[];
    final lowerPattern = pattern.toLowerCase();
    _walkFiles(Directory(root), results, lowerPattern);
    return results;
  }

  void _walkFiles(Directory dir, List<String> results, String pattern) {
    try {
      for (final entity in dir.listSync()) {
        final name = entity.uri.pathSegments.last;
        if (FileNode.isIgnored(name)) continue;
        if (name.toLowerCase().contains(pattern)) {
          results.add(entity.path);
        }
        if (entity is Directory) {
          _walkFiles(entity, results, pattern);
        }
      }
    } catch (_) {}
  }

  // 鈹€鈹€ File info 鈹€鈹€
  Map<String, dynamic>? getFileInfo(String path) {
    final file = File(_resolve(path));
    if (!file.existsSync()) return null;
    final stat = file.statSync();
    return {
      'path': path,
      'size': stat.size,
      'modified': stat.modified.toIso8601String(),
      'type': stat.type == FileSystemEntityType.directory ? 'directory' : 'file',
    };
  }

  // 鈹€鈹€ Delete 鈹€鈹€
  Future<void> deleteFile(String path) async {
    final resolved = _resolve(path);
    final file = File(resolved);
    final dir = Directory(resolved);
    if (await file.exists()) {
      await file.delete();
    } else if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  // 鈹€鈹€ Create directory 鈹€鈹€
  Future<void> createDirectory(String path) async {
    await Directory(_resolve(path)).create(recursive: true);
  }

  // 鈹€鈹€ Move / rename 鈹€鈹€
  Future<void> moveFile(String from, String to) async {
    await File(_resolve(from)).rename(_resolve(to));
  }
}

