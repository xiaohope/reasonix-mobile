import 'dart:io';

/// 文件树节点
class FileNode {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modified;

  const FileNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modified,
  });

  String get extension {
    if (isDirectory) return '';
    final i = name.lastIndexOf('.');
    return i > 0 ? name.substring(i) : '';
  }

  IconType get iconType {
    if (isDirectory) return IconType.folder;
    switch (extension.toLowerCase()) {
      case '.dart': return IconType.dart;
      case '.go': return IconType.go;
      case '.py': return IconType.python;
      case '.ts': case '.tsx': return IconType.typescript;
      case '.js': case '.jsx': return IconType.javascript;
      case '.json': case '.yaml': case '.yml': case '.toml': return IconType.config;
      case '.md': return IconType.markdown;
      case '.png': case '.jpg': case '.jpeg': case '.gif': case '.svg': return IconType.image;
      case '.gitignore': return IconType.git;
      default: return IconType.file;
    }
  }

  static FileNode fromEntity(FileSystemEntity entity) {
    final stat = entity.statSync();
    return FileNode(
      name: entity.uri.pathSegments.last,
      path: entity.path,
      isDirectory: entity is Directory,
      size: entity is File ? stat.size : null,
      modified: stat.modified,
    );
  }

  /// 是否应该被过滤掉（依赖/构建目录）
  static bool isIgnored(String name) {
    const ignored = [
      '.git', 'node_modules', '.dart_tool', '.packages',
      'build', 'dist', '.next', '.nuxt', '.venv', '__pycache__',
      'vendor', '.idea', '.vscode', 'coverage', '.svn',
    ];
    return ignored.contains(name) || name.startsWith('.');
  }
}

enum IconType {
  folder, file, dart, go, python, typescript, javascript,
  config, markdown, image, git,
}
