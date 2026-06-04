/// 项目配置
class ProjectConfig {
  final String rootPath;
  final String name;

  ProjectConfig({
    required this.rootPath,
    required this.name,
  });

  factory ProjectConfig.fromPath(String path) {
    final segments = path.split('/');
    return ProjectConfig(
      rootPath: path,
      name: segments.isNotEmpty ? segments.last : '未知项目',
    );
  }
}
