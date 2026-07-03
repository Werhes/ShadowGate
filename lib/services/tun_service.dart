import 'dart:async';
import 'dart:io' show Platform;

import '../models/tun_config.dart';
import '../utils/logger.dart';
import 'platform_channel_service.dart';

/// Сервис для управления TUN-интерфейсом
/// Работает через platform channels:
/// - Android: VpnService (реализован в ShadowVpnService.kt)
/// - iOS: NEPacketTunnelProvider (реализован в ShadowTunPlugin.swift)
/// - Windows: WinDivert (требуется нативный плагин C++)
/// - macOS: NEPacketTunnelProvider (реализован в ShadowTunPlugin.swift)
///
/// Применяет DPI-обход (zapret-style) к проходящему трафику
/// Обработка пакетов происходит в PlatformChannelService
/// (на Android — через MethodChannel обратно в Dart)
class TunService {
  bool _isRunning = false;
  final PlatformChannelService _platformChannel = PlatformChannelService();
  Timer? _statsTimer;
  int _bytesSent = 0;
  int _bytesReceived = 0;

  /// Колбэк для обновления статистики трафика
  void Function(int sent, int received)? onTrafficUpdate;

  bool get isRunning => _isRunning;
  int get bytesSent => _bytesSent;
  int get bytesReceived => _bytesReceived;

  /// Проверка поддержки TUN на текущей платформе
  bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isWindows;

  /// Запуск TUN-интерфейса
  Future<void> start(TunConfig config) async {
    if (_isRunning) {
      Logger.warn('TUN-интерфейс уже запущен');
      return;
    }

    // Проверка поддержки платформы
    if (!isSupported) {
      throw UnsupportedError(
        'TUN-режим поддерживается только на Android, iOS и Windows. '
        'Используйте режим "Прокси" или "MTProto".',
      );
    }

    try {
      Logger.info('Запуск TUN-интерфейса: ${config.interfaceName}');
      Logger.info('MTU: ${config.mtu}');
      Logger.info(
        'Методы DPI: ${config.enabledMethods.map((m) => m.label).join(', ')}',
      );

      // Передаём методы DPI в PlatformChannelService для обработки пакетов
      _platformChannel.setDpiMethods(config.enabledMethods);

      // Подключаем колбэк статистики
      _platformChannel.onTrafficUpdate = (sent, received) {
        _bytesSent += sent;
        _bytesReceived += received;
      };

      // Запрашиваем VPN-разрешение (Android / iOS)
      final hasPermission = await _platformChannel.requestVpnPermission();
      if (!hasPermission) {
        throw Exception(
          'Не получено разрешение VPN. '
          'Пожалуйста, разрешите ShadowGate создавать VPN-соединение.',
        );
      }

      // Адаптируем конфигурацию под платформу
      final tunConfig = _buildPlatformConfig(config);

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

  /// Построение конфигурации с учётом платформы
  Map<String, dynamic> _buildPlatformConfig(TunConfig config) {
    final platformConfig = <String, dynamic>{
      'interfaceName': config.interfaceName,
      'mtu': config.mtu,
      'dns': config.dnsServer,
      'bypassLocalTraffic': config.bypassLocalTraffic,
      'enabledMethods':
          config.enabledMethods.map((m) => m.name).toList(),
    };

    // iOS-specific настройки
    if (Platform.isIOS) {
      // iOS требует IPv4 и IPv6 DNS
      platformConfig['dns'] = config.dnsServer ?? '8.8.8.8';
      // iOS NEPacketTunnelProvider использует свои имена интерфейсов
      platformConfig['interfaceName'] = 'utun2';
      // Для iOS добавляем дополнительные параметры
      platformConfig['ipv4Address'] = '10.8.0.2';
      platformConfig['ipv4SubnetMask'] = '255.255.255.0';
      platformConfig['ipv6Address'] = 'fd00:1:2:3::2';
      platformConfig['ipv6PrefixLength'] = 64;
      // iOS требует указания включенных прокси
      platformConfig['proxyServerPort'] = 0;
      platformConfig['proxyServerAddress'] = '';
    }

    return platformConfig;
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
}