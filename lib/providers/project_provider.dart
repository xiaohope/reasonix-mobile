import 'package:flutter/material.dart';
import '../models/project_config.dart';
import '../services/file_service.dart';
import '../services/git_service.dart';

/// 项目状态管理
class ProjectProvider extends ChangeNotifier {
  ProjectConfig? _config;
  final FileService fileService = FileService();
  final GitService gitService = GitService();

  ProjectConfig? get config => _config;
  bool get hasProject => _config != null;
  String get rootPath => _config?.rootPath ?? '';

  void openProject(String path) {
    _config = ProjectConfig.fromPath(path);
    fileService.projectRoot = path;
    gitService.projectRoot = path;
    notifyListeners();
  }

  void closeProject() {
    _config = null;
    fileService.projectRoot = null;
    gitService.projectRoot = null;
    notifyListeners();
  }
}
