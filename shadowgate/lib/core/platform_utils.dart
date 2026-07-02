import 'dart:io' show Platform;

/// Утилиты для определения платформы
class PlatformUtils {
  PlatformUtils._();

  /// Текущая платформа
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;

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