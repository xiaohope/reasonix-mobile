import 'package:flutter/material.dart';
import 'dart:io';
import '../services/terminal_service.dart';

/// 终端状态管理
class TerminalProvider extends ChangeNotifier {
  final TerminalService _service = TerminalService();
  final List<String> _history = [];
  int _historyIndex = -1;
  String _currentOutput = '';

  TerminalService get service => _service;
  List<String> get history => List.unmodifiable(_history);
  String get currentOutput => _currentOutput;

  Future<String> executeCommand(String command) async {
    if (command.trim().isNotEmpty) {
      _history.add(command.trim());
      _historyIndex = _history.length;
    }
    notifyListeners();

    final result = await _service.executeCommand(command);
    _currentOutput = result;
    notifyListeners();
    return result;
  }

  String? getPreviousCommand() {
    if (_history.isEmpty) return null;
    _historyIndex = (_historyIndex - 1).clamp(0, _history.length - 1);
    return _history[_historyIndex];
  }

  String? getNextCommand() {
    if (_history.isEmpty) return null;
    _historyIndex = (_historyIndex + 1).clamp(0, _history.length);
    if (_historyIndex >= _history.length) return null;
    return _history[_historyIndex];
  }

  void clearOutput() {
    _currentOutput = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
