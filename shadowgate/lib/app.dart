import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state_provider.dart';
import 'providers/log_provider.dart';
import 'services/proxy_service.dart';
import 'services/tun_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

/// Главный виджет приложения
class ShadowGateApp extends StatelessWidget {
  const ShadowGateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppStateProvider(
            proxyService: ProxyService(),
            tunService: TunService(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LogProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'ShadowGate',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const HomeScreen(),
      ),
    );
  }
}