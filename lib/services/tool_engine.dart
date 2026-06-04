import '../models/message.dart';
import '../models/tool_call.dart';
import 'file_service.dart';
import 'terminal_service.dart';

/// Reasonix 工具执行引擎
/// 接收 LLM 返回的 ToolCall → 本地执行 → 返回结果
class ToolEngine {
  final FileService fileService;
  final TerminalService terminalService;

  ToolEngine({
    required this.fileService,
    required this.terminalService,
  });

  /// 执行一个工具调用，返回结果字符串
  Future<String> execute(ToolCall call) async {
    try {
      switch (call.name) {
        case 'read_file':
          return await _readFile(call);
        case 'write_file':
          return await _writeFile(call);
        case 'edit_file':
          return await _editFile(call);
        case 'search_content':
          return _searchContent(call);
        case 'search_files':
          return _searchFiles(call);
        case 'list_directory':
          return _listDirectory(call);
        case 'run_command':
          return await _runCommand(call);
        case 'get_file_info':
          return _getFileInfo(call);
        case 'delete_file':
          return await _deleteFile(call);
        case 'create_directory':
          return await _createDirectory(call);
        default:
          return '未知工具: ${call.name}';
      }
    } catch (e) {
      return '工具执行错误 (${call.name}): $e';
    }
  }

  Future<String> _readFile(ToolCall call) async {
    final path = call.arguments['path'] as String? ?? '';
    if (path.isEmpty) return '错误: 缺少 path 参数';
    return await fileService.readFile(path);
  }

  Future<String> _writeFile(ToolCall call) async {
    final path = call.arguments['path'] as String? ?? '';
    final content = call.arguments['content'] as String? ?? '';
    if (path.isEmpty) return '错误: 缺少 path 参数';
    await fileService.writeFile(path, content);
    return '文件已写入: $path (${content.length} 字符)';
  }

  Future<String> _editFile(ToolCall call) async {
    final path = call.arguments['path'] as String? ?? '';
    final search = call.arguments['search'] as String? ?? '';
    final replace = call.arguments['replace'] as String? ?? '';
    if (path.isEmpty) return '错误: 缺少 path 参数';
    if (search.isEmpty) return '错误: 缺少 search 参数';
    await fileService.editFile(path, search, replace);
    return '文件已编辑: $path';
  }

  String _searchContent(ToolCall call) {
    final pattern = call.arguments['pattern'] as String? ?? '';
    final path = call.arguments['path'] as String?;
    if (pattern.isEmpty) return '错误: 缺少 pattern 参数';
    final results = fileService.searchContent(pattern, path: path);
    if (results.isEmpty) return '未找到匹配: $pattern';
    final sb = StringBuffer();
    sb.writeln('找到 ${results.length} 处匹配:');
    for (final r in results.take(30)) {
      sb.writeln('  ${r['path']}:${r['line']}: ${r['text']}');
    }
    return sb.toString();
  }

  String _searchFiles(ToolCall call) {
    final pattern = call.arguments['pattern'] as String? ?? '';
    if (pattern.isEmpty) return '错误: 缺少 pattern 参数';
    final results = fileService.searchFiles(pattern);
    if (results.isEmpty) return '未找到文件: $pattern';
    return '找到 ${results.length} 个文件:
${results.take(30).join('
')}';
  }

  String _listDirectory(ToolCall call) {
    final path = call.arguments['path'] as String? ?? '';
    final entries = fileService.listDirectory(path);
    if (entries.isEmpty) return '(空目录)';
    return entries.map((e) {
      final icon = e.isDirectory ? '📁' : '📄';
      return '$icon ${e.name}';
    }).join('
');
  }

  Future<String> _runCommand(ToolCall call) async {
    final command = call.arguments['command'] as String? ?? '';
    if (command.isEmpty) return '错误: 缺少 command 参数';
    return await terminalService.executeCommand(command);
  }

  Future<String> _getFileInfo(ToolCall call) async {
    final path = call.arguments['path'] as String? ?? '';
    if (path.isEmpty) return '错误: 缺少 path 参数';
    final info = await fileService.getFileInfo(path);
    if (info == null) return '路径不存在: $path';
    return '路径: ${info['path']}
类型: ${info['type']}
大小: ${info['size']} bytes
修改时间: ${info['modified']}';
  }

  Future<String> _deleteFile(ToolCall call) async {
    final path = call.arguments['path'] as String? ?? '';
    if (path.isEmpty) return '错误: 缺少 path 参数';
    await fileService.deleteFile(path);
    return '已删除: $path';
  }

  Future<String> _createDirectory(ToolCall call) async {
    final path = call.arguments['path'] as String? ?? '';
    if (path.isEmpty) return '错误: 缺少 path 参数';
    await fileService.createDirectory(path);
    return '目录已创建: $path';
  }
}
