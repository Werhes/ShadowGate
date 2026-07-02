import 'package:flutter/foundation.dart';

import '../core/types.dart';
import '../models/app_state.dart';
import '../models/proxy_config.dart';
import '../models/tun_config.dart';
import '../services/proxy_service.dart';
import '../services/tun_service.dart';
import '../utils/logger.dart';

/// Провайдер состояния приложения
class AppStateProvider extends ChangeNotifier {
  final ProxyService _proxyService;
  final TunService _tunService;

  AppState _state = const AppState();

  AppStateProvider({
    required ProxyService proxyService,
    required TunService tunService,
  })  : _proxyService = proxyService,
        _tunService = tunService;
  // ignore: prefer_initializing_formals - поля private

  AppState get state => _state;

  /// Установка режима
  void setMode(AppMode mode) {
    _state = _state.copyWith(mode: mode);
    notifyListeners();
    Logger.info('Режим изменён на: ${mode.label}');
  }

  /// Обновление конфигурации прокси
  void updateProxyConfig(ProxyConfig config) {
    _state = _state.copyWith(proxyConfig: config);
    notifyListeners();
  }

  /// Обновление конфигурации TUN
  void updateTunConfig(TunConfig config) {
    _state = _state.copyWith(tunConfig: config);
    notifyListeners();
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

  /// Обновление статистики трафика
  void updateTraffic({int? sent, int? received}) {
    _state = _state.copyWith(
      bytesSent: sent,
      bytesReceived: received,
    );
    notifyListeners();
  }
}