import 'dart:io' show Platform;

/// Утилиты для определения платформы
class PlatformUtils {
  PlatformUtils._();

  /// Текущая платформа
  static bool get isAndroid => _isPlatform(() => Platform.isAndroid);
  static bool get isIOS => _isPlatform(() => Platform.isIOS);
  static bool get isMacOS => _isPlatform(() => Platform.isMacOS);
  static bool get isWindows => _isPlatform(() => Platform.isWindows);
  static bool get isLinux => _isPlatform(() => Platform.isLinux);

  /// Безопасная проверка платформы (не падает на Web)
  static bool _isPlatform(bool Function() check) {
    try {
      return check();
    } catch (_) {
      return false;
    }
  }

  /// Поддерживает ли платформа TUN-режим
  static bool get supportsTun {
    return isAndroid || isWindows || isMacOS || isIOS;
  }

  /// Поддерживает ли платформа прокси-режим
  static bool get supportsProxy => true; // Dart работает везде

  /// Требуются ли root/админ права для TUN
  static bool get tunRequiresAdmin => isWindows;

  /// Требуется ли VPN permission для TUN
  static bool get tunRequiresVpnPermission => isAndroid;
}