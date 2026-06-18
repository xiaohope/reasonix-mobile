import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/model_provider.dart';

// ── 预设模板 ──────────────────────────────────────────────
class _ProviderPreset {
  final String name;
  final String icon;
  final String apiBaseUrl;
  final String defaultModel;
  final List<String> models;
  const _ProviderPreset({
    required this.name, required this.icon,
    required this.apiBaseUrl, required this.defaultModel,
    this.models = const [],
  });
}

const _presets = [
  _ProviderPreset(
    name: 'DeepSeek', icon: '🤖',
    apiBaseUrl: 'https://api.deepseek.com/v1',
    defaultModel: 'deepseek-chat',
    models: ['deepseek-chat', 'deepseek-reasoner', 'deepseek-v4-flash'],
  ),
  _ProviderPreset(
    name: 'Agnes AI', icon: '✨',
    apiBaseUrl: 'https://api.agnesai.com/v1',
    defaultModel: 'claude-3-5-sonnet-20241022',
    models: ['claude-3-5-sonnet-20241022', 'claude-3-7-sonnet-20250219',
             'gpt-4o', 'gpt-4o-mini', 'gemini-2.5-pro', 'gemini-2.0-flash',
             'deepseek-v3', 'deepseek-r1'],
  ),
  _ProviderPreset(
    name: 'OpenAI', icon: '🌀',
    apiBaseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o',
    models: ['gpt-4o', 'gpt-4o-mini', 'o1', 'o1-mini', 'o3-mini'],
  ),
  _ProviderPreset(
    name: 'Ollama（本地）', icon: '🦙',
    apiBaseUrl: 'http://localhost:11434/v1',
    defaultModel: 'llama3.2',
    models: ['llama3.2', 'llama3.1', 'qwen2.5', 'phi4', 'mistral'],
  ),
  _ProviderPreset(
    name: '自定义', icon: '⚙️',
    apiBaseUrl: '',
    defaultModel: '',
  ),
];

// ── 连接测试结果 ──────────────────────────────────────────
enum _TestStatus { idle, loading, success, error }

/// 大模型管理页面
class ProvidersManagePage extends StatefulWidget {
  const ProvidersManagePage({super.key});

  @override
  State<ProvidersManagePage> createState() => _ProvidersManagePageState();
}

class _ProvidersManagePageState extends State<ProvidersManagePage> {
  // 每个 provider 的连接测试状态缓存 {id: status}
  final Map<String, _TestStatus> _testStatus = {};
  final Map<String, String> _testMessage = {};

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('大模型管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '添加 Provider',
            onPressed: () => _showEditSheet(context),
          ),
        ],
      ),
      body: settings.providers.isEmpty
          ? _buildEmpty(context)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: settings.providers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final p = settings.providers[i];
                return _ProviderCard(
                  provider: p,
                  isSelected: p.id == settings.selectedProviderId,
                  testStatus: _testStatus[p.id] ?? _TestStatus.idle,
                  testMessage: _testMessage[p.id] ?? '',
                  onSelect: () => settings.selectProvider(p.id),
                  onEdit: () => _showEditSheet(context, existing: p),
                  onDelete: () => _deleteProvider(context, settings, p),
                  onTest: () => _testConnection(p),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('添加'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.smart_toy_outlined, size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text('还没有配置任何 Provider',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _showEditSheet(context),
          icon: const Icon(Icons.add),
          label: const Text('添加第一个'),
        ),
      ]),
    );
  }

  // ── 测试连接 ──────────────────────────────────────────────
  Future<void> _testConnection(ModelProvider p) async {
    setState(() {
      _testStatus[p.id] = _TestStatus.loading;
      _testMessage[p.id] = '连接中…';
    });

    try {
      final uri = Uri.parse('${p.apiBaseUrl}/chat/completions');
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${p.apiKey}',
        },
        body: jsonEncode({
          'model': p.model,
          'messages': [{'role': 'user', 'content': 'hi'}],
          'max_tokens': 4,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() {
          _testStatus[p.id] = _TestStatus.success;
          _testMessage[p.id] = '连接成功 ✓';
        });
      } else {
        final body = jsonDecode(resp.body);
        final msg = body['error']?['message'] ?? resp.body;
        setState(() {
          _testStatus[p.id] = _TestStatus.error;
          _testMessage[p.id] = '${resp.statusCode}: ${msg.toString().substring(0, msg.toString().length.clamp(0, 60))}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testStatus[p.id] = _TestStatus.error;
        _testMessage[p.id] = e.toString().substring(0, e.toString().length.clamp(0, 80));
      });
    }
  }

  // ── 删除 ──────────────────────────────────────────────────
  Future<void> _deleteProvider(BuildContext context, SettingsProvider settings, ModelProvider p) async {
    if (settings.providers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少保留一个 Provider')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除 Provider'),
        content: Text('确定删除「${p.name}」吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await settings.deleteProvider(p.id);
      _testStatus.remove(p.id);
      _testMessage.remove(p.id);
    }
  }

  // ── 添加/编辑 BottomSheet ──────────────────────────────────
  Future<void> _showEditSheet(BuildContext context, {ModelProvider? existing}) async {
    final result = await showModalBottomSheet<ModelProvider>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditSheet(existing: existing),
    );

    if (result != null && mounted) {
      final settings = context.read<SettingsProvider>();
      if (existing != null) {
        await settings.updateProvider(result);
        // 清除旧测试状态
        _testStatus.remove(result.id);
        _testMessage.remove(result.id);
      } else {
        await settings.addProvider(result);
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════
// Provider 卡片
// ══════════════════════════════════════════════════════════════
class _ProviderCard extends StatelessWidget {
  final ModelProvider provider;
  final bool isSelected;
  final _TestStatus testStatus;
  final String testMessage;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTest;

  const _ProviderCard({
    required this.provider,
    required this.isSelected,
    required this.testStatus,
    required this.testMessage,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onTest,
  });

  Color _testColor(BuildContext context) {
    switch (testStatus) {
      case _TestStatus.success: return Colors.green;
      case _TestStatus.error: return Colors.red;
      default: return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasKey = provider.apiKey.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outline.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.06)
            : colorScheme.surface,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isSelected ? null : onSelect,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 顶部行：名称 + badge + 菜单 ──
              Row(children: [
                Expanded(
                  child: Row(children: [
                    Text(provider.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                        )),
                    const SizedBox(width: 6),
                    if (isSelected)
                      _Badge('使用中', colorScheme.primary),
                    const SizedBox(width: 4),
                    if (hasKey)
                      _Badge('Key ✓', Colors.green)
                    else
                      _Badge('未填 Key', Colors.orange),
                  ]),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: colorScheme.onSurface.withValues(alpha: 0.5)),
                  itemBuilder: (ctx) => [
                    if (!isSelected)
                      const PopupMenuItem(value: 'select',
                          child: ListTile(leading: Icon(Icons.check_circle_outline, size: 20),
                              title: Text('设为当前', style: TextStyle(fontSize: 14)), dense: true)),
                    const PopupMenuItem(value: 'edit',
                        child: ListTile(leading: Icon(Icons.edit_outlined, size: 20),
                            title: Text('编辑', style: TextStyle(fontSize: 14)), dense: true)),
                    const PopupMenuItem(value: 'delete',
                        child: ListTile(leading: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            title: Text('删除', style: TextStyle(fontSize: 14, color: Colors.red)), dense: true)),
                  ],
                  onSelected: (v) {
                    if (v == 'select') onSelect();
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                ),
              ]),

              const SizedBox(height: 8),

              // ── 模型名 ──
              Row(children: [
                Icon(Icons.memory, size: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.45)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(provider.model,
                      style: TextStyle(fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.7)),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 3),

              // ── API URL ──
              Row(children: [
                Icon(Icons.link, size: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.45)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(provider.apiBaseUrl,
                      style: TextStyle(fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),

              const SizedBox(height: 10),

              // ── 底部行：测试按钮 + 测试结果 ──
              Row(children: [
                testStatus == _TestStatus.loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : SizedBox(
                        height: 30,
                        child: OutlinedButton.icon(
                          onPressed: hasKey ? onTest : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: const TextStyle(fontSize: 12),
                            side: BorderSide(
                              color: colorScheme.outline.withValues(alpha: 0.5)),
                          ),
                          icon: Icon(Icons.bolt, size: 14,
                              color: hasKey
                                  ? colorScheme.primary
                                  : colorScheme.onSurface.withValues(alpha: 0.3)),
                          label: Text('测试连接',
                              style: TextStyle(
                                color: hasKey
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withValues(alpha: 0.3))),
                        ),
                      ),
                const SizedBox(width: 10),
                if (testStatus != _TestStatus.idle && testStatus != _TestStatus.loading)
                  Expanded(
                    child: Text(testMessage,
                        style: TextStyle(fontSize: 11, color: _testColor(context)),
                        overflow: TextOverflow.ellipsis),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 添加/编辑 BottomSheet
// ══════════════════════════════════════════════════════════════
class _EditSheet extends StatefulWidget {
  final ModelProvider? existing;
  const _EditSheet({this.existing});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _keyCtrl;
  late TextEditingController _modelCtrl;

  bool _keyVisible = false;
  _ProviderPreset? _selectedPreset;
  List<String> _modelSuggestions = [];

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _urlCtrl  = TextEditingController(text: p?.apiBaseUrl ?? '');
    _keyCtrl  = TextEditingController(text: p?.apiKey ?? '');
    _modelCtrl = TextEditingController(text: p?.model ?? '');

    // 如果是编辑，尝试匹配预设更新 suggestions
    if (p != null) {
      for (final preset in _presets) {
        if (preset.apiBaseUrl == p.apiBaseUrl) {
          _selectedPreset = preset;
          _modelSuggestions = preset.models;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(_ProviderPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _modelSuggestions = preset.models;
      if (preset.name != '自定义') {
        _nameCtrl.text = preset.name;
        _urlCtrl.text = preset.apiBaseUrl;
        if (_modelCtrl.text.isEmpty || preset.models.contains(_modelCtrl.text) == false) {
          _modelCtrl.text = preset.defaultModel;
        }
      }
    });
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    final id = widget.existing?.id
        ?? DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.of(context).pop(ModelProvider(
      id: id,
      name: _nameCtrl.text.trim(),
      apiBaseUrl: _urlCtrl.text.trim(),
      apiKey: _keyCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 把手
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 标题
            Text(isEdit ? '编辑 Provider' : '添加 Provider',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // ── 预设选择（仅新建时显示）──
            if (!isEdit) ...[
              Text('快速选择平台', style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final preset = _presets[i];
                    final selected = _selectedPreset == preset;
                    return ChoiceChip(
                      label: Text('${preset.icon}  ${preset.name}'),
                      selected: selected,
                      onSelected: (_) => _applyPreset(preset),
                      selectedColor: colorScheme.primary.withValues(alpha: 0.15),
                      checkmarkColor: colorScheme.primary,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── 表单字段 ──

            // 名称
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '名称 *',
                hintText: '如 DeepSeek',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '名称不能为空' : null,
            ),
            const SizedBox(height: 12),

            // API 地址
            TextFormField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'API 地址 *',
                hintText: 'https://api.deepseek.com/v1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'API 地址不能为空' : null,
            ),
            const SizedBox(height: 12),

            // API Key
            TextFormField(
              controller: _keyCtrl,
              obscureText: !_keyVisible,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_keyCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: '复制',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _keyCtrl.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)));
                        },
                      ),
                    IconButton(
                      icon: Icon(_keyVisible ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _keyVisible = !_keyVisible),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 模型名（带建议）
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _modelCtrl.text),
              optionsBuilder: (editingValue) {
                if (_modelSuggestions.isEmpty || editingValue.text.isEmpty) {
                  return _modelSuggestions;
                }
                return _modelSuggestions.where(
                    (m) => m.toLowerCase().contains(editingValue.text.toLowerCase()));
              },
              onSelected: (v) {
                _modelCtrl.text = v;
              },
              fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
                // 保持和 _modelCtrl 同步
                ctrl.text = _modelCtrl.text;
                ctrl.addListener(() => _modelCtrl.text = ctrl.text);
                return TextFormField(
                  controller: ctrl,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: '模型名 *',
                    hintText: '如 deepseek-chat',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.memory_outlined),
                    suffixIcon: _modelSuggestions.isNotEmpty
                        ? const Icon(Icons.arrow_drop_down, size: 20)
                        : null,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '模型名不能为空' : null,
                );
              },
            ),

            const SizedBox(height: 20),

            // ── 操作按钮 ──
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: Icon(isEdit ? Icons.check : Icons.add),
                  label: Text(isEdit ? '保存修改' : '添加'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
