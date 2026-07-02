import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/types.dart';
import '../models/proxy_config.dart';
import '../models/tun_config.dart';
import '../ui/theme/app_theme.dart';
import '../utils/logger.dart';

/// Сервис для сохранения и загрузки настроек приложения
/// Использует SharedPreferences для персистентного хранения
class SettingsService {
  static const _keyAppMode = 'app_mode';
  static const _keyProxyConfig = 'proxy_config';
  static const _keyTunConfig = 'tun_config';
  static const _keyAutoStart = 'auto_start';
  static const _keyThemeType = 'theme_type';

  SharedPreferences? _prefs;

  /// Инициализация SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    Logger.info('SettingsService инициализирован');
  }

  // ===== AppMode =====

  /// Сохранение выбранного режима
  Future<void> saveAppMode(AppMode mode) async {
    await _prefs?.setString(_keyAppMode, mode.name);
    Logger.debug('Режим сохранён: ${mode.name}');
  }

  /// Загрузка сохранённого режима
  AppMode loadAppMode() {
    final name = _prefs?.getString(_keyAppMode);
    if (name == null) return AppMode.proxy;
    return AppMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => AppMode.proxy,
    );
  }

  // ===== ProxyConfig =====

  /// Сохранение конфигурации прокси
  Future<void> saveProxyConfig(ProxyConfig config) async {
    final json = jsonEncode(config.toJson());
    await _prefs?.setString(_keyProxyConfig, json);
    Logger.debug('ProxyConfig сохранён');
  }

  /// Загрузка сохранённой конфигурации прокси
  ProxyConfig loadProxyConfig() {
    final json = _prefs?.getString(_keyProxyConfig);
    if (json == null) return const ProxyConfig();
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return ProxyConfig.fromJson(map);
    } catch (e) {
      Logger.error('Ошибка загрузки ProxyConfig: $e');
      return const ProxyConfig();
    }
  }

  // ===== TunConfig =====

  /// Сохранение конфигурации TUN
  Future<void> saveTunConfig(TunConfig config) async {
    final json = jsonEncode(config.toJson());
    await _prefs?.setString(_keyTunConfig, json);
    Logger.debug('TunConfig сохранён');
  }

  /// Загрузка сохранённой конфигурации TUN
  TunConfig loadTunConfig() {
    final json = _prefs?.getString(_keyTunConfig);
    if (json == null) return const TunConfig();
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return TunConfig.fromJson(map);
    } catch (e) {
      Logger.error('Ошибка загрузки TunConfig: $e');
      return const TunConfig();
    }
  }

  // ===== Auto-start =====

  /// Сохранение настройки автозапуска
  Future<void> saveAutoStart(bool enabled) async {
    await _prefs?.setBool(_keyAutoStart, enabled);
    Logger.debug('AutoStart сохранён: $enabled');
  }

  /// Загрузка настройки автозапуска
  bool loadAutoStart() {
    return _prefs?.getBool(_keyAutoStart) ?? false;
  }

  // ===== Очистка =====

  // ===== AppThemeType =====

  /// Сохранение выбранной темы
  Future<void> saveThemeType(AppThemeType type) async {
    await _prefs?.setString(_keyThemeType, type.name);
    Logger.debug('Тема сохранена: ${type.name}');
  }

  /// Загрузка сохранённой темы
  AppThemeType loadThemeType() {
    final name = _prefs?.getString(_keyThemeType);
    if (name == null) return AppThemeType.violet;
    return AppThemeType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => AppThemeType.violet,
    );
  }

  /// Очистка всех сохранённых настроек
  Future<void> clear() async {
    await _prefs?.clear();
    Logger.info('Все настройки очищены');
  }
}