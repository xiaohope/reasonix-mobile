import 'package:flutter/material.dart';
import 'dart:io';
import '../models/project_config.dart';
import '../services/file_service.dart';
import '../services/git_service.dart';

class ProjectProvider extends ChangeNotifier {
  ProjectConfig? _config;
  final FileService fileService = FileService();
  final GitService gitService = GitService();
  VoidCallback? onProjectOpened;

  ProjectConfig? get config => _config;
  bool get hasProject => _config != null;
  String get rootPath => _config?.rootPath ?? '';

  String? get memoryFilePath {
    if (_config == null) return null;
    return '${_config!.rootPath}/.reasonix_memory.json';
  }

  bool get hasMemoryFile {
    final path = memoryFilePath;
    if (path == null) return false;
    return File(path).existsSync();
  }

  void openProject(String path) {
    _config = ProjectConfig.fromPath(path);
    fileService.projectRoot = path;
    gitService.projectRoot = path;
    notifyListeners();
    onProjectOpened?.call();
  }

  void closeProject() {
    _config = null;
    fileService.projectRoot = null;
    gitService.projectRoot = null;
    notifyListeners();
    onProjectOpened?.call();
  }
}