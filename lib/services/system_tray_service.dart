import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/logger.dart';

/// Сервис для работы в системном трее (Windows)
/// Позволяет сворачивать приложение в трей при закрытии окна
class SystemTrayService {
  final SystemTray _systemTray = SystemTray();
  bool _initialized = false;

  /// Колбэк при выборе "Показать окно"
  VoidCallback? onShow;

  /// Колбэк при выборе "Скрыть в трей"
  VoidCallback? onHide;

  /// Колбэк при выборе "Выход"
  VoidCallback? onExit;

  bool get initialized => _initialized;

  /// Инициализация системного трея и window_manager
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Инициализируем window_manager для обработки закрытия окна
      await windowManager.ensureInitialized();

      // Устанавливаем обработчик закрытия окна — сворачиваем в трей
      windowManager.setPreventClose(true);

      // Слушаем события окна
      WindowManager.instance.addListener(_WindowListener(this));

      // Инициализируем system tray
      await _systemTray.initSystemTray(
        iconPath: 'assets/app_icon.ico',
        toolTip: 'ShadowGate - VPN/Proxy с DPI-обходом',
      );

      // Регистрируем обработчик кликов по иконке трея
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == 'leftMouseClick' ||
            eventName == 'leftDoubleClick') {
          onShow?.call();
        }
      });

      // Создаём меню
      await _buildMenu();

      _initialized = true;
      Logger.info('Системный трей инициализирован');
    } catch (e) {
      Logger.error('Ошибка инициализации системного трея: $e');
    }
  }

  /// Построение контекстного меню трея
  Future<void> _buildMenu() async {
    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: 'Показать ShadowGate',
        onClicked: (_) => onShow?.call(),
      ),
      MenuItemLabel(
        label: 'Скрыть в трей',
        onClicked: (_) => onHide?.call(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Выход',
        onClicked: (_) => onExit?.call(),
      ),
    ]);
    await _systemTray.setContextMenu(menu);
  }

  /// Показать уведомление из трея
  Future<void> showNotification({
    String title = 'ShadowGate',
    String message = '',
  }) async {
    try {
      // system_tray не имеет встроенного API для уведомлений на Windows,
      // используем setToolTip для отображения статуса
      await _systemTray.setToolTip('$title\n$message');
    } catch (e) {
      Logger.error('Ошибка показа уведомления: $e');
    }
  }

  /// Удаление иконки из трея
  Future<void> dispose() async {
    try {
      _systemTray.destroy();
      _initialized = false;
    } catch (e) {
      Logger.error('Ошибка удаления трея: $e');
    }
  }
}

/// Слушатель событий окна для сворачивания в трей
class _WindowListener extends WindowListener {
  final SystemTrayService _service;

  _WindowListener(this._service);

  @override
  void onWindowClose() async {
    // Вместо закрытия — сворачиваем в трей
    await windowManager.hide();
    _service.onHide?.call();
  }
}