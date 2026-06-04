/// 文件树节点
class FileNode {
  final String name;
  final String path;
  final bool isDirectory;
  final List<FileNode>? children;

  const FileNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children,
  });
}
