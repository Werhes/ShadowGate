/// Утилита для логирования
class Logger {
  Logger._();

  static final List<LogEntry> _logs = [];
  static void Function(LogEntry)? onLog;

  static void debug(String message) => _log(LogLevel.debug, message);
  static void info(String message) => _log(LogLevel.info, message);
  static void warn(String message) => _log(LogLevel.warn, message);
  static void error(String message) => _log(LogLevel.error, message);

  static void _log(LogLevel level, String message) {
    final entry = LogEntry(
      level: level,
      message: message,
      timestamp: DateTime.now(),
    );
    _logs.add(entry);
    onLog?.call(entry);

    // Ограничиваем размер лога
    if (_logs.length > 1000) {
      _logs.removeRange(0, _logs.length - 1000);
    }
  }

  static List<LogEntry> get logs => List.unmodifiable(_logs);

  static void clear() => _logs.clear();
}

enum LogLevel {
  debug,
  info,
  warn,
  error;

  String get label {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }
}

class LogEntry {
  final LogLevel level;
  final String message;
  final DateTime timestamp;

  const LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
  });

  String get formatted {
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    return '[$time][${level.label}] $message';
  }
}