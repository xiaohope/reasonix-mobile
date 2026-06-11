import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/knowledge.dart';

/// 知识库管理服务 — 单例
/// 知识条目以 .md 文件存储在 App 数据目录下
class KnowledgeService {
  static final KnowledgeService _instance = KnowledgeService._internal();
  factory KnowledgeService() => _instance;
  KnowledgeService._internal();

  List<Knowledge> _items = [];
  Directory? _dir;
  bool _initialized = false;

  List<Knowledge> get items => List.unmodifiable(_items);

  Future<void> init() async {
    if (_initialized) return;
    final appDir = await getApplicationDocumentsDirectory();
    _dir = Directory('${appDir.path}/reasonix/knowledge');
    if (!await _dir!.exists()) {
      await _dir!.create(recursive: true);
    }
    await _loadFromDisk();
    _initialized = true;
  }

  Future<void> refresh() async {
    await _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    _items = [];
    if (_dir == null || !await _dir!.exists()) return;
    try {
      final files = _dir!.listSync();
      for (final f in files) {
        if (f is File && f.path.endsWith('.md')) {
          try {
            final id = f.uri.pathSegments.last.replaceAll('.md', '');
            final content = await f.readAsString();
            _items.add(Knowledge.fromMarkdown(content, id: id));
          } catch (_) {}
        }
      }
    } catch (_) {}
    _items.sort((a, b) => a.title.compareTo(b.title));
  }

  Future<void> _writeFile(Knowledge item) async {
    if (_dir == null) return;
    final file = File('${_dir!.path}/${item.id}.md');
    await file.writeAsString(item.toMarkdown());
  }

  Future<void> upsert(Knowledge item) async {
    final idx = _items.indexWhere((s) => s.id == item.id);
    if (idx >= 0) {
      _items[idx] = item;
    } else {
      _items.add(item);
    }
    await _writeFile(item);
  }

  Future<void> delete(String id) async {
    _items.removeWhere((s) => s.id == id);
    if (_dir != null) {
      final file = File('${_dir!.path}/$id.md');
      if (await file.exists()) await file.delete();
    }
  }

  Knowledge? getById(String id) {
    try {
      return _items.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
