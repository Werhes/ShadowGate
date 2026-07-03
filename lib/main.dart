import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализируем window_manager ТОЛЬКО для Desktop (Windows/macOS/Linux)
  // На Android/iOS window_manager не поддерживается и вызовет MissingPluginException
  if (!Platform.isAndroid && !Platform.isIOS) {
    await windowManager.ensureInitialized();

    // Настройки окна по умолчанию
    WindowOptions windowOptions = const WindowOptions(
      size: Size(480, 800),
      minimumSize: Size(400, 600),
      center: true,
      title: 'ShadowGate',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ShadowGateApp());
}
