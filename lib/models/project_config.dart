import 'dart:io';

/// 项目配置
class ProjectConfig {
  final String name;
  final String rootPath;
  final String? gitRemote;

  const ProjectConfig({
    required this.name,
    required this.rootPath,
    this.gitRemote,
  });

  bool get isValid => Directory(rootPath).existsSync();

  factory ProjectConfig.fromPath(String path) {
    final dir = Directory(path);
    return ProjectConfig(
      name: dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'untitled'),
      rootPath: path,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'rootPath': rootPath,
    'gitRemote': gitRemote,
  };

  factory ProjectConfig.fromJson(Map<String, dynamic> json) => ProjectConfig(
    name: json['name'] as String? ?? '',
    rootPath: json['rootPath'] as String? ?? '',
    gitRemote: json['gitRemote'] as String?,
  );
}
