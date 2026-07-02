/// Константы приложения
class AppConstants {
  AppConstants._();

  /// Название приложения
  static const String appName = 'ShadowGate';

  /// Версия
  static const String appVersion = '0.1.0';

  /// Порт по умолчанию для прокси
  static const int defaultProxyPort = 1080;

  /// Порт по умолчанию для HTTP прокси
  static const int defaultHttpProxyPort = 8080;

  /// Адрес по умолчанию для прокси
  static const String defaultProxyHost = '127.0.0.1';

  /// Ключи для SharedPreferences
  static const String prefAppMode = 'app_mode';
  static const String prefProxyType = 'proxy_type';
  static const String prefProxyPort = 'proxy_port';
  static const String prefProxyHost = 'proxy_host';
  static const String prefUseWebSocket = 'use_websocket';
  static const String prefWsUrl = 'ws_url';
  static const String prefTargets = 'targets';
  static const String prefDpiMethods = 'dpi_methods';

  /// Предустановленные цели
  static const Map<String, List<String>> defaultTargets = {
    'telegram': [
      'api.telegram.org',
      't.me',
      'telegram.org',
      '149.154.160.0/20',
      '91.108.56.0/22',
    ],
    'discord': [
      'discord.com',
      'discord.gg',
      'discordapp.net',
      '162.159.128.0/17',
    ],
    'youtube': [
      'youtube.com',
      'googlevideo.com',
      'ytimg.com',
      '142.250.0.0/15',
      '172.217.0.0/16',
    ],
  };
}