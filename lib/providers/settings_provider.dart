import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// 设置状态管理 — 使用 JSON 文件持久化（替代 SharedPreferences）
class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  String _apiKey = '';
  String _apiBaseUrl = 'https://api.deepseek.com/v1';
  String _apiModel = 'deepseek-chat';
  String _lastProjectPath = '';

  ThemeMode get themeMode => _themeMode;
  String get apiKey => _apiKey;
  String get apiBaseUrl => _apiBaseUrl;
  String get apiModel => _apiModel;
  String get lastProjectPath => _lastProjectPath;

  bool get hasApiKey => _apiKey.isNotEmpty;

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
        _apiKey = json['api_key'] as String? ?? '';
        _apiBaseUrl = json['api_base_url'] as String? ?? 'https://api.deepseek.com/v1';
        _apiModel = json['api_model'] as String? ?? 'deepseek-chat';
        _lastProjectPath = json['last_project_path'] as String? ?? '';
        final theme = json['theme_mode'] as String? ?? 'dark';
        _themeMode = theme == 'light' ? ThemeMode.light : ThemeMode.dark;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    await _initFile();
    try {
      await _file!.writeAsString(jsonEncode({
        'api_key': _apiKey,
        'api_base_url': _apiBaseUrl,
        'api_model': _apiModel,
        'last_project_path': _lastProjectPath,
        'theme_mode': _themeMode == ThemeMode.light ? 'light' : 'dark',
      }));
    } catch (_) {}
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    await _save();
    notifyListeners();
  }

  Future<void> setApiBaseUrl(String url) async {
    _apiBaseUrl = url;
    await _save();
    notifyListeners();
  }

  Future<void> setApiModel(String model) async {
    _apiModel = model;
    await _save();
    notifyListeners();
  }

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
