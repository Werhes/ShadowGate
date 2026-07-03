import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../core/types.dart';
import '../models/tun_config.dart';
import '../utils/logger.dart';
import 'dpi_bypass_service.dart';

/// Сервис для взаимодействия с нативным кодом через Platform Channels
///
/// Поддерживаемые платформы:
/// - Android: VpnService (ShadowVpnService.kt), MtprotoService (MtprotoService.kt)
/// - iOS: NEPacketTunnelProvider + нативный MTProto (ShadowTunPlugin.swift)
/// - Windows: Wintun (shadowgate_tun_plugin.cpp)
class PlatformChannelService {
  static const _channel = MethodChannel('com.example.shadowgate/service');
  static const _mtprotoChannel = MethodChannel('com.example.shadowgate/mtproto');

  final DpiBypassService _dpiBypass = DpiBypassService();

  /// Текущие методы DPI для обработки пакетов
  List<DpiMethod> _dpiMethods = DpiMethodValues.defaults;

  /// Колбэк для обновления статистики трафика
  void Function(int sent, int received)? onTrafficUpdate;

  /// Установка методов DPI для обработки пакетов
  void setDpiMethods(List<DpiMethod> methods) {
    _dpiMethods = methods;
  }

  /// Проверка, поддерживается ли платформа для TUN
  bool get _isTunSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isWindows;

  /// Проверка, поддерживается ли нативный MTProto прокси
  /// На iOS — через ShadowTunPlugin, на Android — через MtprotoService
  /// На Windows — через Dart FFI (mtproto_proxy.dll)
  bool get _isNativeMtprotoSupported =>
      Platform.isIOS || Platform.isAndroid || Platform.isWindows;

  // ============================================================
  // TUN METHODS
  // ============================================================

  /// Запуск TUN-интерфейса на нативной стороне
  Future<bool> startTun(Map<String, dynamic> config) async {
    if (!_isTunSupported) {
      Logger.warn('TUN не поддерживается на этой платформе');
      return false;
    }
    try {
      // На Android устанавливаем methodChannel для обратной связи из Kotlin
      if (Platform.isAndroid) {
        _channel.setMethodCallHandler(_handleTunCall);
      }

      final result = await _channel.invokeMethod<bool>('startTun', config);
      Logger.info('TUN запущен: $result');
      return result ?? false;
    } on MissingPluginException {
      Logger.error('TUN native plugin не найден (MissingPluginException)');
      return false;
    } catch (e) {
      Logger.error('Ошибка запуска TUN через native: $e');
      return false;
    }
  }

  /// Обработка входящих вызовов из нативного кода (Android TUN)
  Future<dynamic> _handleTunCall(MethodCall call) async {
    switch (call.method) {
      case 'processPacket':
        final packet = call.arguments as List<int>?;
        if (packet == null || packet.isEmpty) return null;

        try {
          // Применяем DPI-обход к пакету
          final processed = await _dpiBypass.applyDpiMethods(
            packet,
            _dpiMethods,
          );

          // Обновляем статистику
          onTrafficUpdate?.call(0, packet.length);

          return processed;
        } catch (e) {
          Logger.error('Ошибка обработки пакета TUN: $e');
          return packet; // Возвращаем как есть при ошибке
        }

      default:
        return null;
    }
  }

  /// Остановка TUN-интерфейса на нативной стороне
  Future<bool> stopTun() async {
    if (!_isTunSupported) {
      return false;
    }
    try {
      if (Platform.isAndroid) {
        _channel.setMethodCallHandler(null);
      }
      final result = await _channel.invokeMethod<bool>('stopTun');
      Logger.info('TUN остановлен: $result');
      return result ?? false;
    } on MissingPluginException {
      Logger.error('TUN native plugin не найден (MissingPluginException)');
      return false;
    } catch (e) {
      Logger.error('Ошибка остановки TUN через native: $e');
      return false;
    }
  }

  /// Получение статуса TUN
  Future<bool> getTunStatus() async {
    if (!_isTunSupported) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('getTunStatus');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      Logger.error('Ошибка получения статуса TUN: $e');
      return false;
    }
  }

  /// Запрос VPN-разрешения
  Future<bool> requestVpnPermission() async {
    if (!_isTunSupported) {
      return false;
    }
    try {
      final result =
          await _channel.invokeMethod<bool>('requestVpnPermission');
      return result ?? false;
    } on MissingPluginException {
      Logger.error('VPN permission plugin не найден (MissingPluginException)');
      return false;
    } catch (e) {
      Logger.error('Ошибка запроса VPN permission: $e');
      return false;
    }
  }

  /// Проверка админ-прав (Windows)
  Future<bool> checkAdminRights() async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('checkAdminRights');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      Logger.error('Ошибка проверки админ-прав: $e');
      return false;
    }
  }

  /// Получение статистики трафика с нативной стороны
  Future<Map<String, dynamic>?> getTrafficStats() async {
    if (!_isTunSupported) {
      return null;
    }
    try {
      final result =
          await _channel.invokeMethod<Map<String, dynamic>>('getTrafficStats');
      return result;
    } on MissingPluginException {
      return null;
    } catch (e) {
      Logger.error('Ошибка получения статистики трафика: $e');
      return null;
    }
  }

  // ============================================================
  // MTProto METHODS (нативные, для iOS и Android)
  // ============================================================

  /// Выбор канала в зависимости от платформы
  /// iOS: использует общий канал ShadowTunPlugin
  /// Android: использует отдельный канал MtprotoService
  MethodChannel get _mtprotoChannelForPlatform =>
      Platform.isAndroid ? _mtprotoChannel : _channel;

  /// Запуск нативного MTProto прокси (iOS/Android)
  /// Возвращает сгенерированный secret
  Future<String?> startNativeMtproto(Map<String, dynamic> config) async {
    if (!_isNativeMtprotoSupported) {
      return null;
    }
    try {
      final channel = _mtprotoChannelForPlatform;
      final result = await channel.invokeMethod<String>('startMtproto', config);
      Logger.info('Нативный MTProto запущен, secret: $result');
      return result;
    } on MissingPluginException {
      Logger.error('Native MTProto plugin не найден');
      return null;
    } catch (e) {
      Logger.error('Ошибка запуска нативного MTProto: $e');
      return null;
    }
  }

  /// Остановка нативного MTProto прокси (iOS/Android)
  Future<bool> stopNativeMtproto() async {
    if (!_isNativeMtprotoSupported) {
      return false;
    }
    try {
      final channel = _mtprotoChannelForPlatform;
      final result = await channel.invokeMethod<bool>('stopMtproto');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      Logger.error('Ошибка остановки нативного MTProto: $e');
      return false;
    }
  }

  /// Получение статуса нативного MTProto прокси (iOS/Android)
  Future<Map<String, dynamic>> getNativeMtprotoStatus() async {
    if (!_isNativeMtprotoSupported) {
      return {'isRunning': false};
    }
    try {
      final channel = _mtprotoChannelForPlatform;
      final result =
          await channel.invokeMethod<Map<String, dynamic>>('getMtprotoStatus');
      return result ?? {'isRunning': false};
    } on MissingPluginException {
      return {'isRunning': false};
    } catch (e) {
      Logger.error('Ошибка получения статуса нативного MTProto: $e');
      return {'isRunning': false};
    }
  }

  /// Генерация MTProto secret на нативной стороне (iOS/Android)
  Future<String?> generateNativeSecret({bool useFakeTls = true}) async {
    if (!_isNativeMtprotoSupported) {
      return null;
    }
    try {
      final channel = _mtprotoChannelForPlatform;
      final result = await channel.invokeMethod<String>('generateSecret', {
        'useFakeTls': useFakeTls,
      });
      return result;
    } on MissingPluginException {
      return null;
    } catch (e) {
      Logger.error('Ошибка генерации secret на native: $e');
      return null;
    }
  }
}