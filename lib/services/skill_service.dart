import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/skill.dart';

/// 技能（Skill）管理服务 — 单例
/// 技能以 .skill.md 文件存储在 App 数据目录下
class SkillService {
  // ── 单例 ──
  static final SkillService _instance = SkillService._internal();
  factory SkillService() => _instance;
  SkillService._internal();

  List<Skill> _skills = [];
  Directory? _skillsDir;
  bool _initialized = false;

  List<Skill> get skills => List.unmodifiable(_skills);

  // ── 默认内置技能 ──
  static final List<Skill> _defaultSkills = [
    Skill(
      id: 'code_review', name: '代码审查',
      description: '审查当前项目代码，找出问题',
      prompt: '请审查我当前项目的代码，重点关注：\n'
          '1) 潜在 bug\n2) 性能问题\n3) 代码规范\n'
          '4) 安全性问题\n5) 可维护性\n\n'
          '逐一列出发现的问题，标注严重程度，并给出修改建议。',
      icon: '🔍',
    ),
    Skill(
      id: 'fix_bugs', name: '修复Bug',
      description: '分析和修复代码中的 Bug',
      prompt: '请分析这段代码中的 Bug，解释问题原因，并给出修复后的代码。',
      icon: '🐛',
    ),
    Skill(
      id: 'explain', name: '解释代码',
      description: '用通俗语言解释代码逻辑',
      prompt: '请用通俗易懂的语言解释以下代码的功能和逻辑，适合初学者理解。',
      icon: '📖',
    ),
    Skill(
      id: 'refactor', name: '代码重构',
      description: '优化代码结构和可读性',
      prompt: '请对这个代码进行重构，提高可读性和可维护性。\n'
          '保持功能不变，优化变量命名、提取公共逻辑、简化复杂条件等。',
      icon: '🛠️',
    ),
    Skill(
      id: 'add_comments', name: '添加注释',
      description: '为代码添加中文注释',
      prompt: '请为以下代码添加详细的中文注释，解释每一段的功能和关键逻辑。',
      icon: '💬',
    ),
    Skill(
      id: 'write_test', name: '写测试',
      description: '为代码生成单元测试',
      prompt: '请为以下代码编写单元测试。\n使用合适的测试框架，覆盖正常路径和边界情况。',
      icon: '🧪',
    ),
    Skill(
      id: 'optimize', name: '性能优化',
      description: '分析性能瓶颈并给出优化建议',
      prompt: '请分析这段代码的性能瓶颈，给出优化建议。\n'
          '关注：时间复杂度、内存使用、不必要的计算、IO 操作等。',
      icon: '⚡',
    ),
    Skill(
      id: 'security', name: '安全审查',
      description: '检查代码中的安全隐患',
      prompt: '请审查以下代码的安全性：\n'
          '1) 输入验证\n2) SQL/命令注入\n3) 路径遍历\n'
          '4) 敏感信息泄露\n5) 认证授权\n\n列出所有风险点及修复方案。',
      icon: '🔒',
    ),
  ];

  // ── 初始化 ──

  Future<void> init() async {
    if (_initialized) return;
    final appDir = await getApplicationDocumentsDirectory();
    _skillsDir = Directory('${appDir.path}/reasonix/skills');
    if (!await _skillsDir!.exists()) {
      await _skillsDir!.create(recursive: true);
    }
    await _loadFromDisk();
    _initialized = true;
  }

  /// 从磁盘重新加载（从设置页返回后调用）
  Future<void> refresh() async {
    await _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    _skills = [];
    if (_skillsDir == null || !await _skillsDir!.exists()) return;

    try {
      final files = _skillsDir!.listSync();
      // 先清理旧的 .json 格式技能文件（v0.3.0 遗留）
      for (final f in files) {
        if (f is File && f.path.endsWith('.json')) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
      // 加载 .skill.md 格式
      for (final f in files) {
        if (f is File && f.path.endsWith('.skill.md')) {
          try {
            final id = f.uri.pathSegments.last.replaceAll('.skill.md', '');
            final content = await f.readAsString();
            _skills.add(Skill.fromMarkdown(content, id: id));
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 首次运行：创建默认技能
    if (_skills.isEmpty) {
      for (final skill in _defaultSkills) {
        await _writeSkillFile(skill);
      }
      _skills = List.from(_defaultSkills);
    }

    _skills.sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _writeSkillFile(Skill skill) async {
    if (_skillsDir == null) return;
    final file = File('${_skillsDir!.path}/${skill.id}.skill.md');
    await file.writeAsString(skill.toMarkdown());
  }

  // ── CRUD ──

  /// 添加或更新一个技能
  Future<void> upsertSkill(Skill skill) async {
    final idx = _skills.indexWhere((s) => s.id == skill.id);
    if (idx >= 0) {
      _skills[idx] = skill;
    } else {
      _skills.add(skill);
    }
    await _writeSkillFile(skill);
  }

  /// 删除一个技能
  Future<void> deleteSkill(String id) async {
    _skills.removeWhere((s) => s.id == id);
    if (_skillsDir != null) {
      final file = File('${_skillsDir!.path}/$id.skill.md');
      if (await file.exists()) await file.delete();
    }
  }

  /// 根据 ID 查找技能
  Skill? getById(String id) {
    try {
      return _skills.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 恢复所有默认技能
  Future<void> resetToDefaults() async {
    if (_skillsDir != null && await _skillsDir!.exists()) {
      // 删除所有 .skill.md 文件
      final files = _skillsDir!.listSync();
      for (final f in files) {
        if (f is File && f.path.endsWith('.skill.md')) {
          await f.delete();
        }
      }
    }
    _skills = [];
    for (final skill in _defaultSkills) {
      await _writeSkillFile(skill);
    }
    _skills = List.from(_defaultSkills);
  }
}
