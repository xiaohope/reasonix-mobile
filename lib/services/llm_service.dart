import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../models/tool_call.dart';

/// LLM API 调用服务 — 支持流式输出
class LlmService {
  String? _apiKey;
  String _baseUrl = 'https://api.deepseek.com/v1';
  String _model = 'deepseek-chat';
  double _temperature = 0.0;

  // Tool definitions sent with each request
  static const List<Map<String, dynamic>> _tools = [
    {
      'type': 'function',
      'function': {
        'name': 'read_file',
        'description': '读取文件内容',
        'parameters': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': '文件路径（相对于项目根）'},
          },
          'required': ['path'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'write_file',
        'description': '写入/创建文件',
        'parameters': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': '文件路径'},
            'content': {'type': 'string', 'description': '文件内容'},
          },
          'required': ['path', 'content'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'edit_file',
        'description': '搜索替换方式编辑文件，SEARCH 必须完全匹配原文',
        'parameters': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': '文件路径'},
            'search': {'type': 'string', 'description': '要查找的原文'},
            'replace': {'type': 'string', 'description': '替换为的内容'},
          },
          'required': ['path', 'search', 'replace'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'search_content',
        'description': '在项目中搜索文件内容（grep）',
        'parameters': {
          'type': 'object',
          'properties': {
            'pattern': {'type': 'string', 'description': '搜索模式'},
            'path': {'type': 'string', 'description': '可选：限定搜索目录'},
          },
          'required': ['pattern'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'search_files',
        'description': '按文件名搜索',
        'parameters': {
          'type': 'object',
          'properties': {
            'pattern': {'type': 'string', 'description': '文件名（子串匹配）'},
          },
          'required': ['pattern'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'list_directory',
        'description': '列出目录内容',
        'parameters': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': '目录路径（默认项目根）'},
          },
          'required': [],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'run_command',
        'description': '在终端中执行命令',
        'parameters': {
          'type': 'object',
          'properties': {
            'command': {'type': 'string', 'description': '要执行的命令'},
          },
          'required': ['command'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_file_info',
        'description': '获取文件/目录信息',
        'parameters': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': '文件路径'},
          },
          'required': ['path'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_file',
        'description': '删除文件',
        'parameters': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': '文件路径'},
          },
          'required': ['path'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'create_directory',
        'description': '创建目录',
        'parameters': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': '目录路径'},
          },
          'required': ['path'],
        },
      },
    },
  ];

  // ── Config ──
  void configure({
    String? apiKey,
    String? baseUrl,
    String? model,
    double? temperature,
  }) {
    if (apiKey != null) _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
    if (model != null) _model = model;
    if (temperature != null) _temperature = temperature;
  }

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  // ── Streaming chat completion ──
  Stream<String> chatStream(List<Message> messages) async* {
    if (!isConfigured) {
      yield '请先在设置中配置 API Key';
      return;
    }

    final uri = Uri.parse('$_baseUrl/chat/completions');
    final body = jsonEncode({
      'model': _model,
      'messages': messages.map((m) => m.toApiMessage()).toList(),
      'tools': _tools,
      'stream': true,
      'temperature': _temperature,
    });

    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        'Accept': 'text/event-stream',
      })
      ..body = body;

    try {
      final response = await request.send();

      if (response.statusCode != 200) {
        final err = await response.stream.bytesToString();
        yield 'API 错误 (${response.statusCode}): $err';
        return;
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') return;
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final delta = json['choices']?[0]?['delta'] as Map<String, dynamic>?;
              if (delta != null && delta['content'] is String) {
                yield delta['content'] as String;
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      yield '网络请求失败: $e';
    }
  }

  /// 非流式调用（支持 tool_call 返回）
  /// [includeTools] = false 时不发送工具定义（聊天模式）
  Future<Map<String, dynamic>> chatComplete(List<Message> messages, {bool includeTools = true}) async {
    if (!isConfigured) {
      return {'error': '请先在设置中配置 API Key'};
    }

    final uri = Uri.parse('$_baseUrl/chat/completions');
    final bodyMap = <String, dynamic>{
      'model': _model,
      'messages': messages.map((m) => m.toApiMessage()).toList(),
      'stream': false,
      'temperature': _temperature,
    };
    if (includeTools) {
      bodyMap['tools'] = _tools;
    }
    final body = jsonEncode(bodyMap);

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        return {'error': 'API 错误 (${response.statusCode}): ${response.body}'};
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['usage'] is Map) {
        json['_has_usage'] = true;
      }
      return json;
    } catch (e) {
      return {'error': '网络请求失败: $e'};
    }
  }

  /// 查询余额
  Future<Map<String, dynamic>> checkBalance() async {
    if (!isConfigured) {
      return {'error': '请先在设置中配置 API Key'};
    }
    final base = Uri.parse(_baseUrl);
    final domain = "${base.scheme}://${base.host}";
    final urls = [
      "$domain/user/balance",
      "$domain/balance",
      "$domain/dashboard/billing/info",
    ];
    for (final url in urls) {
      try {
        final uri = Uri.parse(url);
        final response = await http.get(uri, headers: {
          'Authorization': 'Bearer $_apiKey',
          'Accept': 'application/json',
        });
        if (response.statusCode == 200) return jsonDecode(response.body);
      } catch (_) {
        continue;
      }
    }
    return {'error': '无法查询余额，请检查 API Key 是否正确'};
  }
}
