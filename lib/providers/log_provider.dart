import 'package:flutter/foundation.dart';

import '../utils/logger.dart';

/// Провайдер логов
class LogProvider extends ChangeNotifier {
  final List<LogEntry> _logs = [];

  List<LogEntry> get logs => List.unmodifiable(_logs);

  LogProvider() {
    Logger.onLog = _onLog;
  }

  void _onLog(LogEntry entry) {
    _logs.add(entry);
    if (_logs.length > 500) {
      _logs.removeRange(0, _logs.length - 500);
    }
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    Logger.clear();
    notifyListeners();
  }
}