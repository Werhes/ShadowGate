import 'dart:async';

import '../core/types.dart';
import '../models/tun_config.dart';
import '../utils/logger.dart';
import 'dpi_bypass_service.dart';
import 'platform_channel_service.dart';

/// Сервис для управления TUN-интерфейсом
/// Работает через platform channels:
/// - Android: VpnService
/// - Windows: WinDivert (через нативный плагин)
/// - iOS/macOS: NEPacketTunnelProvider
///
/// Применяет DPI-обход (zapret-style) к проходящему трафику
class TunService {
  bool _isRunning = false;
  final DpiBypassService _dpiBypass = DpiBypassService();
  final PlatformChannelService _platformChannel = PlatformChannelService();
  Timer? _statsTimer;
  int _bytesSent = 0;
  int _bytesReceived = 0;

  /// Колбэк для обновления статистики трафика
  void Function(int sent, int received)? onTrafficUpdate;

  bool get isRunning => _isRunning;
  int get bytesSent => _bytesSent;
  int get bytesReceived => _bytesReceived;

  /// Запуск TUN-интерфейса
  Future<void> start(TunConfig config) async {
    if (_isRunning) {
      Logger.warn('TUN-интерфейс уже запущен');
      return;
    }

    try {
      Logger.info('Запуск TUN-интерфейса: ${config.interfaceName}');
      Logger.info('MTU: ${config.mtu}');
      Logger.info(
        'Методы DPI: ${config.enabledMethods.map((m) => m.label).join(', ')}',
      );

      // Запрашиваем VPN-разрешение (Android) или проверяем админ-права (Windows)
      final hasPermission = await _platformChannel.requestVpnPermission();
      if (!hasPermission) {
        Logger.warn('VPN разрешение не получено, продолжаем...');
      }

      // Запускаем TUN через platform channel
      final tunConfig = {
        'interfaceName': config.interfaceName,
        'mtu': config.mtu,
        'dns': config.dnsServer,
        'bypassLocalTraffic': config.bypassLocalTraffic,
        'enabledMethods':
            config.enabledMethods.map((m) => m.name).toList(),
      };

      final started = await _platformChannel.startTun(tunConfig);
      if (!started) {
        throw Exception('Не удалось запустить TUN-интерфейс');
      }

      _isRunning = true;
      Logger.info('TUN-интерфейс запущен');

      // Таймер для обновления статистики
      _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        onTrafficUpdate?.call(_bytesSent, _bytesReceived);
      });
    } catch (e) {
      Logger.error('Ошибка запуска TUN: $e');
      rethrow;
    }
  }

  /// Остановка TUN-интерфейса
  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      _statsTimer?.cancel();
      await _platformChannel.stopTun();
      _isRunning = false;
      _bytesSent = 0;
      _bytesReceived = 0;
      Logger.info('TUN-интерфейс остановлен');
    } catch (e) {
      Logger.error('Ошибка остановки TUN: $e');
      rethrow;
    }
  }

  /// Обработка входящего пакета из TUN с DPI-обходом
  Future<List<int>> processIncomingPacket(
    List<int> packet,
    List<DpiMethod> methods,
  ) async {
    _bytesReceived += packet.length;
    return _dpiBypass.applyDpiMethods(packet, methods);
  }

  /// Обработка исходящего пакета в TUN
  void processOutgoingPacket(List<int> packet) {
    _bytesSent += packet.length;
  }
}