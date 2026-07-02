import '../models/tun_config.dart';
import '../utils/logger.dart';

/// Сервис для управления TUN-интерфейсом
class TunService {
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Запуск TUN-интерфейса
  Future<void> start(TunConfig config) async {
    if (_isRunning) {
      Logger.warn('TUN-интерфейс уже запущен');
      return;
    }

    try {
      Logger.info('Запуск TUN-интерфейса: ${config.interfaceName}');
      Logger.info('MTU: ${config.mtu}');
      Logger.info('Методы DPI: ${config.enabledMethods.map((m) => m.label).join(', ')}');

      // TODO: Реализовать нативный запуск TUN через platform channel
      // На Android: VpnService
      // На Windows: WinDivert
      // На macOS/iOS: NEPacketTunnelProvider

      _isRunning = true;
      Logger.info('TUN-интерфейс запущен');
    } catch (e) {
      Logger.error('Ошибка запуска TUN: $e');
      rethrow;
    }
  }

  /// Остановка TUN-интерфейса
  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      // TODO: Реализовать нативную остановку TUN
      _isRunning = false;
      Logger.info('TUN-интерфейс остановлен');
    } catch (e) {
      Logger.error('Ошибка остановки TUN: $e');
      rethrow;
    }
  }
}