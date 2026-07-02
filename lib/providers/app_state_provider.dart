import 'package:flutter/foundation.dart';

import '../core/types.dart';
import '../models/app_state.dart';
import '../models/proxy_config.dart';
import '../models/tun_config.dart';
import '../services/mtproto_service.dart';
import '../services/proxy_service.dart';
import '../services/settings_service.dart';
import '../services/tun_service.dart';
import '../ui/theme/app_theme.dart';
import '../utils/logger.dart';

/// Провайдер состояния приложения
/// Автоматически сохраняет настройки при изменениях
class AppStateProvider extends ChangeNotifier {
  final ProxyService _proxyService;
  final TunService _tunService;
  final MtprotoProxyService _mtprotoService;
  final SettingsService _settingsService;

  AppState _state = const AppState();
  bool _initialized = false;
  AppThemeType _themeType = AppThemeType.violet;

  AppStateProvider({
    required ProxyService proxyService,
    required TunService tunService,
    required SettingsService settingsService,
    MtprotoProxyService? mtprotoService,
  })  : _proxyService = proxyService,
        _tunService = tunService,
        _mtprotoService = mtprotoService ?? MtprotoProxyService(),
        _settingsService = settingsService {
    // Подписываемся на обновления трафика от всех сервисов
    _proxyService.onTrafficUpdate = _onProxyTrafficUpdate;
    _tunService.onTrafficUpdate = _onTunTrafficUpdate;
    _mtprotoService.onTrafficUpdate = _onMtprotoTrafficUpdate;
  }

  AppState get state => _state;
  bool get initialized => _initialized;
  AppThemeType get themeType => _themeType;

  /// Инициализация: загрузка сохранённых настроек
  Future<void> initialize() async {
    await _settingsService.init();

    final savedMode = _settingsService.loadAppMode();
    final savedProxyConfig = _settingsService.loadProxyConfig();
    final savedTunConfig = _settingsService.loadTunConfig();

    _state = _state.copyWith(
      mode: savedMode,
      proxyConfig: savedProxyConfig,
      tunConfig: savedTunConfig,
    );

    // Загружаем сохранённую тему
    _themeType = _settingsService.loadThemeType();

    _initialized = true;
    notifyListeners();

    Logger.info(
      'Настройки загружены: режим=${savedMode.name}, '
      'прокси=${savedProxyConfig.host}:${savedProxyConfig.port}, '
      'tun=${savedTunConfig.interfaceName}',
    );
  }

  /// Обработка обновления трафика от прокси-сервиса
  void _onProxyTrafficUpdate(int sent, int received) {
    _state = _state.copyWith(
      bytesSent: sent,
      bytesReceived: received,
    );
    notifyListeners();
  }

  /// Обработка обновления трафика от TUN-сервиса
  void _onTunTrafficUpdate(int sent, int received) {
    _state = _state.copyWith(
      bytesSent: sent,
      bytesReceived: received,
    );
    notifyListeners();
  }

  /// Обработка обновления трафика от MTProto-сервиса
  void _onMtprotoTrafficUpdate(int sent, int received) {
    _state = _state.copyWith(
      bytesSent: sent,
      bytesReceived: received,
    );
    notifyListeners();
  }

  /// Установка режима с автосохранением
  void setMode(AppMode mode) {
    _state = _state.copyWith(mode: mode);
    notifyListeners();
    _settingsService.saveAppMode(mode);
    Logger.info('Режим изменён на: ${mode.label}');
  }

  /// Обновление конфигурации прокси с автосохранением
  void updateProxyConfig(ProxyConfig config) {
    _state = _state.copyWith(proxyConfig: config);
    notifyListeners();
    _settingsService.saveProxyConfig(config);
  }

  /// Обновление конфигурации TUN с автосохранением
  void updateTunConfig(TunConfig config) {
    _state = _state.copyWith(tunConfig: config);
    notifyListeners();
    _settingsService.saveTunConfig(config);
  }

  /// Установка темы оформления с автосохранением
  void setThemeType(AppThemeType type) {
    _themeType = type;
    notifyListeners();
    _settingsService.saveThemeType(type);
    Logger.info('Тема изменена на: ${type.label}');
  }

  /// Запуск сервиса
  Future<void> start() async {
    if (_state.status == ServiceStatus.running ||
        _state.status == ServiceStatus.starting) {
      return;
    }

    _state = _state.copyWith(
      status: ServiceStatus.starting,
      clearError: true,
    );
    notifyListeners();

    try {
      switch (_state.mode) {
        case AppMode.proxy:
          await _proxyService.start(_state.proxyConfig);
          break;
        case AppMode.tun:
          await _tunService.start(_state.tunConfig);
          break;
        case AppMode.mtproto:
          await _mtprotoService.start(_state.proxyConfig);
          break;
      }

      _state = _state.copyWith(
        status: ServiceStatus.running,
        startedAt: DateTime.now(),
      );
      Logger.info('Сервис запущен');
    } catch (e) {
      _state = _state.copyWith(
        status: ServiceStatus.error,
        errorMessage: e.toString(),
      );
      Logger.error('Ошибка запуска: $e');
    }

    notifyListeners();
  }

  /// Остановка сервиса
  Future<void> stop() async {
    if (_state.status == ServiceStatus.stopped ||
        _state.status == ServiceStatus.stopping) {
      return;
    }

    _state = _state.copyWith(status: ServiceStatus.stopping);
    notifyListeners();

    try {
      switch (_state.mode) {
        case AppMode.proxy:
          await _proxyService.stop();
          break;
        case AppMode.tun:
          await _tunService.stop();
          break;
        case AppMode.mtproto:
          await _mtprotoService.stop();
          break;
      }

      _state = const AppState();
      Logger.info('Сервис остановлен');
    } catch (e) {
      _state = _state.copyWith(
        status: ServiceStatus.error,
        errorMessage: e.toString(),
      );
      Logger.error('Ошибка остановки: $e');
    }

    notifyListeners();
  }

  /// Обновление статистики трафика (ручной вызов)
  void updateTraffic({int? sent, int? received}) {
    _state = _state.copyWith(
      bytesSent: sent,
      bytesReceived: received,
    );
    notifyListeners();
  }
}