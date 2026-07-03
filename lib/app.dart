import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/types.dart';
import 'providers/app_state_provider.dart';
import 'providers/log_provider.dart';
import 'services/mtproto_service.dart';
import 'services/platform_channel_service.dart';
import 'services/proxy_service.dart';
import 'services/settings_service.dart';
import 'services/system_tray_service.dart';
import 'services/tun_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

/// Главный виджет приложения
class ShadowGateApp extends StatefulWidget {
  const ShadowGateApp({super.key});

  @override
  State<ShadowGateApp> createState() => _ShadowGateAppState();
}

class _ShadowGateAppState extends State<ShadowGateApp> {
  final _settingsService = SettingsService();
  SystemTrayService? _systemTrayService;
  AppStateProvider? _provider;

  @override
  void initState() {
    super.initState();

    // Инициализация после первого кадра
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Сохраняем ссылку на провайдер для использования в колбэках
      _provider = context.read<AppStateProvider>();

      // Инициализируем трей ТОЛЬКО на Desktop (Windows/macOS/Linux)
      // На Android/iOS system_tray не поддерживается
      if (!Platform.isAndroid && !Platform.isIOS) {
        _systemTrayService = SystemTrayService();
        await _systemTrayService!.init();

        // Настраиваем колбэки трея
        _systemTrayService!.onShow = () async {
          await windowManager.show();
          await windowManager.focus();
        };
        _systemTrayService!.onHide = () async {
          await windowManager.hide();
        };
        _systemTrayService!.onExit = () async {
          // Останавливаем сервисы перед выходом
          final p = _provider;
          if (p != null && p.state.status == ServiceStatus.running) {
            await p.stop();
          }
          await _systemTrayService!.dispose();
          await windowManager.destroy();
        };
      }

      // Загружаем сохранённые настройки
      if (mounted) {
        await _provider?.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppStateProvider(
            proxyService: ProxyService(),
            tunService: TunService(),
            mtprotoService: MtprotoProxyService(),
            settingsService: _settingsService,
            platformChannel: PlatformChannelService(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LogProvider(),
        ),
      ],
      child: Consumer<AppStateProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'ShadowGate',
            theme: AppTheme.themeFor(provider.themeType),
            debugShowCheckedModeBanner: false,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}