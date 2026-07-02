import '../core/types.dart';
import 'proxy_config.dart';
import 'tun_config.dart';

/// Состояние приложения
class AppState {
  final AppMode mode;
  final ServiceStatus status;
  final ProxyConfig proxyConfig;
  final TunConfig tunConfig;
  final String? errorMessage;
  final int bytesSent;
  final int bytesReceived;
  final DateTime? startedAt;

  const AppState({
    this.mode = AppMode.proxy,
    this.status = ServiceStatus.stopped,
    this.proxyConfig = const ProxyConfig(),
    this.tunConfig = const TunConfig(),
    this.errorMessage,
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.startedAt,
  });

  AppState copyWith({
    AppMode? mode,
    ServiceStatus? status,
    ProxyConfig? proxyConfig,
    TunConfig? tunConfig,
    String? errorMessage,
    int? bytesSent,
    int? bytesReceived,
    DateTime? startedAt,
    bool clearError = false,
  }) {
    return AppState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      proxyConfig: proxyConfig ?? this.proxyConfig,
      tunConfig: tunConfig ?? this.tunConfig,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      bytesSent: bytesSent ?? this.bytesSent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  /// Скорость в байтах/сек
  double get speedBytesPerSec {
    if (startedAt == null) return 0;
    final elapsed = DateTime.now().difference(startedAt!).inSeconds;
    if (elapsed == 0) return 0;
    return (bytesSent + bytesReceived) / elapsed;
  }

  /// Отформатированная скорость
  String get formattedSpeed {
    final speed = speedBytesPerSec;
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// Отформатированный трафик
  String get formattedTraffic {
    final total = bytesSent + bytesReceived;
    if (total < 1024) return '$total B';
    if (total < 1024 * 1024) {
      return '${(total / 1024).toStringAsFixed(1)} KB';
    }
    if (total < 1024 * 1024 * 1024) {
      return '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(total / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}