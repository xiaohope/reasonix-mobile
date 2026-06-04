import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_node.dart';
import '../widgets/file_tree.dart';
import '../widgets/project_picker.dart';
import '../providers/project_provider.dart';
import '../providers/settings_provider.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});
  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  String _currentPath = '';
  List<FileNode> _currentNodes = [];
  bool _isLoading = false;
  bool _initialized = false;
  String _searchQuery = '';
  List<FileNode> _searchResults = [];

  @override
  Widget build(BuildContext context) {
    final project = context.watch<ProjectProvider>();
    if (project.hasProject && !_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDirectory(project.rootPath));
    }
    if (!project.hasProject && _initialized) {
      _initialized = false;
      _currentPath = '';
      _currentNodes = [];
    }
    if (!project.hasProject) return _buildNoProject(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(project.config?.name ?? '项目', style: const TextStyle(fontSize: 16)),
        actions: [
          if (_currentPath.isNotEmpty && _currentPath != project.rootPath)
            IconButton(icon: const Icon(Icons.arrow_upward), tooltip: '上级目录', onPressed: () => _goToParent(project.rootPath)),
          IconButton(icon: const Icon(Icons.search), tooltip: '搜索文件', onPressed: _showSearchDialog),
          IconButton(icon: const Icon(Icons.close), tooltip: '关闭项目', onPressed: () => project.closeProject()),
        ],
      ),
      body: Column(
        children: [
          GestureDetector(
            onTap: () => _loadDirectory(project.rootPath),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Theme.of(context).colorScheme.surface,
              child: Row(children: [
                Icon(Icons.folder, size: 14, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  _currentPath.isNotEmpty ? _currentPath : project.rootPath,
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
            ),
          ),
          Expanded(child: _searchQuery.isNotEmpty ? _buildSearchResults(context) : _buildFileList(context)),
        ],
      ),
    );
  }

  Widget _buildNoProject(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文件')),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: ProjectPicker(
          onPicked: (path) {
            context.read<ProjectProvider>().openProject(path);
            context.read<SettingsProvider>().setLastProjectPath(path);
            _loadDirectory(path);
          },
        ),
      )),
    );
  }

  void _loadDirectory(String path) {
    final project = context.read<ProjectProvider>();
    if (!project.hasProject) return;
    setState(() { _currentPath = path; _isLoading = true; });
    final nodes = project.fileService.listDirectory(path);
    setState(() { _currentNodes = nodes; _isLoading = false; });
  }

  void _goToParent(String rootPath) {
    if (_currentPath.isEmpty || _currentPath == rootPath) return;
    final parentDir = Directory(_currentPath).parent.path;
    _loadDirectory(parentDir.startsWith(rootPath) ? parentDir : rootPath);
  }

  Widget _buildFileList(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_currentNodes.isEmpty) return Center(child: Text('（空目录）', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14)));
    return FileTree(nodes: _currentNodes, onTap: (node) {
      if (node.isDirectory) _loadDirectory(node.path);
      else _openFileEditor(node.path);
    });
  }

  Future<void> _openFileEditor(String path) async {
    try {
      final content = await context.read<ProjectProvider>().fileService.readFile(path);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FileEditorPage(path: path, content: content)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('无法读取文件: $e')));
    }
  }

  Future<void> _showSearchDialog() async {
    final result = await showDialog<String>(context: context, builder: (ctx) => const _SearchDialog());
    if (result != null && result.isNotEmpty && mounted) _performSearch(result);
  }

  void _performSearch(String query) {
    final project = context.read<ProjectProvider>();
    final results = project.fileService.searchFiles(query);
    setState(() {
      _searchQuery = query;
      _searchResults = results.map((p) {
        final name = p.split(Platform.pathSeparator).last;
        return FileNode(name: name, path: p, isDirectory: false);
      }).toList();
    });
  }

  Widget _buildSearchResults(BuildContext context) {
    if (_searchResults.isEmpty) return Center(child: Text('未找到: $_searchQuery', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))));
    return Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: Row(children: [
        Text('找到 ${_searchResults.length} 个文件', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)),
        const Spacer(),
        TextButton(child: const Text('清除搜索'), onPressed: () => setState(() => _searchQuery = '')),
      ])),
      Expanded(child: ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final node = _searchResults[index];
          return ListTile(dense: true, leading: const Icon(Icons.insert_drive_file, size: 16),
            title: Text(node.path, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            onTap: () => _openFileEditor(node.path));
        },
      )),
    ]);
  }
}

class _SearchDialog extends StatefulWidget {
  const _SearchDialog();
  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}
class _SearchDialogState extends State<_SearchDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('搜索文件'),
      content: TextField(controller: _controller, autofocus: true,
        decoration: const InputDecoration(hintText: '文件名（子串匹配）', prefixIcon: Icon(Icons.search)),
        onSubmitted: (_) => Navigator.of(context).pop(_controller.text)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('搜索')),
      ],
    );
  }
}

class _FileEditorPage extends StatefulWidget {
  final String path; final String content;
  const _FileEditorPage({required this.path, required this.content});
  @override
  State<_FileEditorPage> createState() => _FileEditorPageState();
}
class _FileEditorPageState extends State<_FileEditorPage> {
  late TextEditingController _controller; bool _hasChanges = false;
  @override
  void initState() { super.initState(); _controller = TextEditingController(text: widget.content);
    _controller.addListener(() { if (!_hasChanges) setState(() => _hasChanges = true); }); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final name = widget.path.split(Platform.pathSeparator).last;
    return Scaffold(
      appBar: AppBar(
        title: Text(name, style: const TextStyle(fontSize: 14, fontFamily: 'monospace')),
        actions: [if (_hasChanges) IconButton(icon: const Icon(Icons.save), tooltip: '保存', onPressed: _save)],
      ),
      body: TextField(controller: _controller, maxLines: null, expands: true,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12))),
    );
  }
  Future<void> _save() async {
    try {
      await context.read<ProjectProvider>().fileService.writeFile(widget.path, _controller.text);
      setState(() => _hasChanges = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    }
  }
}