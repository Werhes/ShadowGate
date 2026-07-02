import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Сервис для взаимодействия с нативным кодом через Platform Channels
class PlatformChannelService {
  static const _channel = MethodChannel('com.example.shadowgate/service');

  /// Запуск TUN-интерфейса на нативной стороне
  Future<bool> startTun(Map<String, dynamic> config) async {
    try {
      final result = await _channel.invokeMethod<bool>('startTun', config);
      Logger.info('TUN запущен: $result');
      return result ?? false;
    } catch (e) {
      Logger.error('Ошибка запуска TUN через native: $e');
      return false;
    }
  }

  /// Остановка TUN-интерфейса на нативной стороне
  Future<bool> stopTun() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopTun');
      Logger.info('TUN остановлен: $result');
      return result ?? false;
    } catch (e) {
      Logger.error('Ошибка остановки TUN через native: $e');
      return false;
    }
  }

  /// Получение статуса TUN
  Future<bool> getTunStatus() async {
    try {
      final result = await _channel.invokeMethod<bool>('getTunStatus');
      return result ?? false;
    } catch (e) {
      Logger.error('Ошибка получения статуса TUN: $e');
      return false;
    }
  }

  /// Запрос VPN-разрешения (Android)
  Future<bool> requestVpnPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('requestVpnPermission');
      return result ?? false;
    } catch (e) {
      Logger.error('Ошибка запроса VPN permission: $e');
      return false;
    }
  }

  /// Проверка админ-прав (Windows)
  Future<bool> checkAdminRights() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkAdminRights');
      return result ?? false;
    } catch (e) {
      Logger.error('Ошибка проверки админ-прав: $e');
      return false;
    }
  }
}