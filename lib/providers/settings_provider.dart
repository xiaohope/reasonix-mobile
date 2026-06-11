import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/model_provider.dart';

/// 设置状态管理 — JSON 文件持久化
class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  String _lastProjectPath = '';
  List<ModelProvider> _providers = [];
  String? _selectedProviderId;   /// 当前选中的 provider id

  // ── 兼容旧版单字段 API（由 selectProvider 更新） ──
  String get apiKey => selectedProvider?.apiKey ?? '';
  String get apiBaseUrl => selectedProvider?.apiBaseUrl ?? 'https://api.deepseek.com/v1';
  String get apiModel => selectedProvider?.model ?? 'deepseek-v4-flash';

  ThemeMode get themeMode => _themeMode;
  String get lastProjectPath => _lastProjectPath;
  List<ModelProvider> get providers => List.unmodifiable(_providers);
  String? get selectedProviderId => _selectedProviderId;

  bool get hasApiKey => apiKey.isNotEmpty;

  /// 当前选中的 provider
  ModelProvider? get selectedProvider {
    if (_selectedProviderId == null) return null;
    try {
      return _providers.firstWhere((p) => p.id == _selectedProviderId);
    } catch (_) {
      return null;
    }
  }

  // ── 默认 provider ──
  static ModelProvider _defaultDeepSeek() => ModelProvider(
    id: 'deepseek',
    name: 'DeepSeek',
    apiBaseUrl: 'https://api.deepseek.com/v1',
    apiKey: '',
    model: 'deepseek-v4-flash',
  );

  // ── 持久化 ──

  File? _file;

  Future<void> _initFile() async {
    if (_file != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/reasonix_settings.json');
  }

  Future<void> load() async {
    await _initFile();
    try {
      if (await _file!.exists()) {
        final json = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;

        // 加载多 provider
        if (json['providers'] is List) {
          _providers = (json['providers'] as List)
              .map((e) => ModelProvider.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        _selectedProviderId = json['selected_provider_id'] as String?;

        // 兼容旧版单字段迁移
        final oldKey = json['api_key'] as String? ?? '';
        final oldUrl = json['api_base_url'] as String? ?? 'https://api.deepseek.com/v1';
        final oldModel = json['api_model'] as String? ?? 'deepseek-v4-flash';
        if (oldKey.isNotEmpty && _providers.isEmpty) {
          _providers.add(ModelProvider(
            id: 'deepseek',
            name: 'DeepSeek',
            apiBaseUrl: oldUrl,
            apiKey: oldKey,
            model: oldModel,
          ));
          _selectedProviderId = 'deepseek';
        }

        _lastProjectPath = json['last_project_path'] as String? ?? '';
        final theme = json['theme_mode'] as String? ?? 'dark';
        _themeMode = theme == 'light' ? ThemeMode.light : ThemeMode.dark;
      }
    } catch (_) {}

    // 确保至少有一个 provider
    if (_providers.isEmpty) {
      _providers.add(_defaultDeepSeek());
      _selectedProviderId = 'deepseek';
    }

    // 确保 selected 有效
    if (_selectedProviderId != null && selectedProvider == null) {
      _selectedProviderId = _providers.first.id;
    }

    notifyListeners();
  }

  Future<void> _save() async {
    await _initFile();
    try {
      await _file!.writeAsString(jsonEncode({
        'providers': _providers.map((p) => p.toJson()).toList(),
        'selected_provider_id': _selectedProviderId,
        'last_project_path': _lastProjectPath,
        'theme_mode': _themeMode == ThemeMode.light ? 'light' : 'dark',
      }));
    } catch (_) {}
  }

  // ── Provider CRUD ──

  Future<void> addProvider(ModelProvider provider) async {
    _providers.add(provider);
    if (_providers.length == 1) {
      _selectedProviderId = provider.id;
    }
    await _save();
    notifyListeners();
  }

  Future<void> updateProvider(ModelProvider provider) async {
    final idx = _providers.indexWhere((p) => p.id == provider.id);
    if (idx >= 0) {
      _providers[idx] = provider;
      await _save();
      notifyListeners();
    }
  }

  Future<void> deleteProvider(String id) async {
    _providers.removeWhere((p) => p.id == id);
    if (_selectedProviderId == id) {
      _selectedProviderId = _providers.isNotEmpty ? _providers.first.id : null;
    }
    await _save();
    notifyListeners();
  }

  Future<void> selectProvider(String id) async {
    if (_providers.any((p) => p.id == id)) {
      _selectedProviderId = id;
      await _save();
      notifyListeners();
    }
  }

  // ── 旧接口兼容（用于外部调用处） ──

  Future<void> setApiKey(String key) async {
    final p = selectedProvider;
    if (p != null) {
      p.apiKey = key;
      await updateProvider(p);
    }
  }

  Future<void> setApiBaseUrl(String url) async {
    final p = selectedProvider;
    if (p != null) {
      p.apiBaseUrl = url;
      await updateProvider(p);
    }
  }

  Future<void> setApiModel(String model) async {
    final p = selectedProvider;
    if (p != null) {
      p.model = model;
      await updateProvider(p);
    }
  }

  // ── 其他设置 ──

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _save();
    notifyListeners();
  }

  Future<void> setLastProjectPath(String path) async {
    _lastProjectPath = path;
    await _save();
    notifyListeners();
  }
}
