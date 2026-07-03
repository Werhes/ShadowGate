import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/types.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/log_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_status.dart';
import '../widgets/mode_selector.dart';
import '../widgets/log_viewer.dart';
import '../widgets/target_list.dart';
import 'customization_screen.dart';
import 'proxy_config_screen.dart';
import 'targets_screen.dart';
import 'tun_config_screen.dart';

/// Главный экран приложения — Hiddify-стиль
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('ShadowGate'),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.cardBorderColor.withValues(alpha: 0.5),
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings, size: 22),
              onPressed: () => _openSettings(context),
              tooltip: 'Настройки',
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.surfaceGradient,
        ),
        child: SafeArea(
          child: _buildBody(context),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(
            top: BorderSide(
              color: AppTheme.cardBorderColor.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (index) => setState(() => _currentTab = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Главная',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.track_changes_outlined),
              activeIcon: Icon(Icons.track_changes),
              label: 'Цели',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.terminal_outlined),
              activeIcon: Icon(Icons.terminal),
              label: 'Логи',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_currentTab) {
      case 0:
        return _buildHomeTab(context);
      case 1:
        return _buildTargetsTab(context);
      case 2:
        return _buildLogsTab(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHomeTab(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, _) {
        final state = provider.state;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // Выбор режима — Proxy / TUN / MTProto
              const SectionHeader(title: 'Режим работы'),
              ModeSelector(
                currentMode: state.mode,
                onModeChanged: provider.setMode,
              ),
              const SizedBox(height: 24),

              // Статус подключения
              const SectionHeader(title: 'Статус'),
              ConnectionStatus(
                status: state.status,
                errorMessage: state.errorMessage,
                speed: state.formattedSpeed,
                traffic: state.formattedTraffic,
              ),
              const SizedBox(height: 24),

              // Кнопка Старт/Стоп
              GradientButton(
                label: state.status == ServiceStatus.running
                    ? 'Остановить'
                    : 'Запустить',
                icon: state.status == ServiceStatus.running
                    ? Icons.stop
                    : Icons.play_arrow,
                onPressed: state.status == ServiceStatus.running
                    ? () => provider.stop()
                    : state.status == ServiceStatus.stopped ||
                            state.status == ServiceStatus.error
                        ? () => provider.start()
                        : null,
                gradient: state.status == ServiceStatus.running
                    ? AppTheme.accentGradient
                    : null,
              ),

              // Кнопка "Подключиться в Telegram" для MTProto режима
              if (state.status == ServiceStatus.running &&
                  state.mode == AppMode.mtproto) ...[
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Подключиться в Telegram',
                  icon: Icons.telegram,
                  onPressed: () {
                    _connectToTelegram(context, provider);
                  },
                  gradient: AppTheme.primaryGradient,
                ),
              ],

              const SizedBox(height: 24),

              // Текущая конфигурация
              const SectionHeader(title: 'Текущая конфигурация'),
              _buildConfigSummary(context, provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfigSummary(
    BuildContext context,
    AppStateProvider provider,
  ) {
    final state = provider.state;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (state.mode == AppMode.proxy) ...[
            _ConfigRow(
              icon: Icons.vpn_lock,
              label: 'Тип',
              value: state.proxyConfig.type.label,
            ),
            const SizedBox(height: 12),
            _ConfigRow(
              icon: Icons.computer,
              label: 'Адрес',
              value: '${state.proxyConfig.host}:${state.proxyConfig.port}',
            ),
            const SizedBox(height: 12),
            _ConfigRow(
              icon: Icons.web,
              label: 'WebSocket',
              value: state.proxyConfig.useWebSocket ? 'Включён' : 'Выключен',
            ),
          ] else if (state.mode == AppMode.mtproto) ...[
            _ConfigRow(
              icon: Icons.telegram,
              label: 'Тип',
              value: 'MTProto Proxy',
            ),
            const SizedBox(height: 12),
            _ConfigRow(
              icon: Icons.computer,
              label: 'Адрес',
              value: '${state.proxyConfig.host}:${state.proxyConfig.port}',
            ),
            const SizedBox(height: 12),
            _ConfigRow(
              icon: Icons.link,
              label: 'WebSocket URL',
              value: state.proxyConfig.webSocketUrl ?? 'wss://pluto.web.telegram.org/apiws',
            ),
            const SizedBox(height: 12),
            _ConfigRow(
              icon: Icons.key,
              label: 'Secret',
              value: state.proxyConfig.mtprotoSecret ?? 'будет сгенерирован при запуске',
            ),
            const SizedBox(height: 12),
            _ConfigRow(
              icon: Icons.security,
              label: 'Fake TLS',
              value: state.proxyConfig.useFakeTls ? 'Включён (рекомендуется)' : 'Выключен',
            ),
          ] else ...[
            _ConfigRow(
              icon: Icons.settings_ethernet,
              label: 'Интерфейс',
              value: state.tunConfig.interfaceName,
            ),
            const SizedBox(height: 12),
            _ConfigRow(
              icon: Icons.straighten,
              label: 'MTU',
              value: '${state.tunConfig.mtu}',
            ),
            const SizedBox(height: 12),
            _ConfigRow(
              icon: Icons.auto_fix_high,
              label: 'Методы DPI',
              value: state.tunConfig.enabledMethods
                  .map((m) => m.label)
                  .join(', '),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetsTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Consumer<AppStateProvider>(
        builder: (context, provider, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              SectionHeader(
                title: 'Целевые сервисы',
                trailing: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TargetsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Управлять'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TargetList(
                  targets: [],
                  onToggle: (id) {},
                  onAdd: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TargetsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogsTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Consumer<LogProvider>(
            builder: (context, logProvider, _) {
              return Expanded(
                child: LogViewer(
                  logs: logProvider.logs,
                  onClear: logProvider.clear,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _connectToTelegram(BuildContext context, AppStateProvider provider) {
    final config = provider.state.proxyConfig;
    final secret = config.mtprotoSecret;
    if (secret == null) return;

    final uri = Uri.parse(
      'tg://proxy?server=${config.host}&port=${config.port}&secret=$secret',
    );

    // Сохраняем SnackBar host до асинхронного вызова
    final messenger = ScaffoldMessenger.of(context);
    final host = config.host;
    final port = config.port;

    launchUrl(uri, mode: LaunchMode.externalApplication).then((success) {
      if (!success) {
        // Если tg:// не открылся, показываем ссылку для копирования
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Не удалось открыть Telegram. '
              'Скопируйте настройки вручную:\n'
              'Сервер: $host:$port\n'
              'Secret: $secret',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }

  void _openSettings(BuildContext context) {
    final provider = context.read<AppStateProvider>();
    final mode = provider.state.mode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
              color: AppTheme.cardBorderColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Полоска захвата
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Настройки режима
              _SettingsItem(
                icon: mode == AppMode.mtproto
                    ? Icons.telegram
                    : Icons.vpn_lock,
                title: mode == AppMode.mtproto
                    ? 'Настройки MTProto'
                    : 'Настройки прокси',
                subtitle: 'Порт, хост, WebSocket',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => mode == AppMode.tun
                          ? const TunConfigScreen()
                          : const ProxyConfigScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              // Кастомизация
              _SettingsItem(
                icon: Icons.palette,
                title: 'Кастомизация',
                subtitle: 'Тема оформления',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomizationScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Элемент меню настроек
class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.cardBorderColor.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppTheme.textMuted,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ConfigRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}