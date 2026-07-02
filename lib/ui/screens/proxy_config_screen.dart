import 'dart:math' as dart_math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/types.dart';
import '../../providers/app_state_provider.dart';
import '../../utils/validators.dart';
import '../theme/app_theme.dart';

/// Экран настроек прокси и MTProto — Hiddify-стиль
class ProxyConfigScreen extends StatefulWidget {
  const ProxyConfigScreen({super.key});

  @override
  State<ProxyConfigScreen> createState() => _ProxyConfigScreenState();
}

class _ProxyConfigScreenState extends State<ProxyConfigScreen> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _wsUrlController;
  late ProxyType _proxyType;
  late bool _useWebSocket;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final config = context.read<AppStateProvider>().state.proxyConfig;
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: config.port.toString());
    _wsUrlController = TextEditingController(text: config.webSocketUrl ?? '');
    _proxyType = config.type;
    _useWebSocket = config.useWebSocket;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _wsUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMtproto = _proxyType == ProxyType.mtproto;
    final provider = context.watch<AppStateProvider>();
    final secret = provider.state.proxyConfig.mtprotoSecret;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isMtproto ? 'Настройки MTProto' : 'Настройки прокси'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: _save,
              child: const Text(
                'Сохранить',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 10),

                // Тип прокси
                const SectionHeader(title: 'Тип прокси'),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: SegmentedButton<ProxyType>(
                    segments: ProxyType.values.map((type) {
                      return ButtonSegment(
                        value: type,
                        label: Text(
                          type.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        icon: Icon(type.icon, size: 18),
                      );
                    }).toList(),
                    selected: {_proxyType},
                    onSelectionChanged: (selected) {
                      setState(() => _proxyType = selected.first);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppTheme.primaryColor.withValues(alpha: 0.3);
                        }
                        return Colors.transparent;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return AppTheme.textSecondary;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Адрес и порт
                const SectionHeader(title: 'Соединение'),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: 'Адрес',
                          hintText: '127.0.0.1',
                          prefixIcon: Icon(Icons.computer),
                        ),
                        validator: Validators.validateHost,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _portController,
                        decoration: InputDecoration(
                          labelText: 'Порт',
                          hintText: isMtproto ? '443' : '1080',
                          prefixIcon: const Icon(Icons.numbers),
                        ),
                        keyboardType: TextInputType.number,
                        validator: Validators.validatePort,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // WebSocket (для MTProto и прокси)
                const SectionHeader(title: 'WebSocket'),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Использовать WebSocket'),
                        subtitle: Text(
                          isMtproto
                              ? 'Подключение к Telegram через WebSocket'
                              : 'Перенаправлять трафик через WebSocket',
                        ),
                        value: _useWebSocket,
                        onChanged: (value) {
                          setState(() => _useWebSocket = value);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_useWebSocket) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _wsUrlController,
                          decoration: InputDecoration(
                            labelText: isMtproto
                                ? 'Telegram WebSocket URL'
                                : 'WebSocket URL',
                            hintText: isMtproto
                                ? 'wss://pluto.web.telegram.org/apiws'
                                : 'wss://example.com/ws',
                            prefixIcon: const Icon(Icons.link),
                          ),
                          validator:
                              _useWebSocket ? Validators.validateUrl : null,
                        ),
                      ],
                    ],
                  ),
                ),

                if (isMtproto) ...[
                  const SizedBox(height: 24),

                  // MTProto Secret
                  const SectionHeader(title: 'MTProto Secret'),
                  const SizedBox(height: 12),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.key,
                                color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Secret для подключения',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.cardBorderColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: SelectableText(
                            secret ?? 'не сгенерирован',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: secret != null
                                  ? const Color(0xFF00E676)
                                  : AppTheme.textSecondary,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: secret != null
                                    ? () {
                                        Clipboard.setData(
                                          ClipboardData(text: secret),
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Secret скопирован в буфер обмена',
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('Копировать'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  side: BorderSide(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final newSecret = _generateSecret();
                                  provider.updateProxyConfig(
                                    provider.state.proxyConfig.copyWith(
                                      mtprotoSecret: newSecret,
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Новый secret сгенерирован',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Сгенерировать'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  side: BorderSide(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Secret — это 32 hex-символа (16 байт), '
                          'которые Telegram использует для шифрования соединения. '
                          'Без secret подключение к MTProto прокси невозможно.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'MTProto Proxy',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Бесплатный MTProto прокси для Telegram. '
                          'После запуска откройте ссылку '
                          'tg://proxy?server=...&port=...&secret=... '
                          'в браузере или настройте прокси в Telegram вручную.\n\n'
                          'Secret генерируется автоматически при запуске, '
                          'если не указан вручную.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Генерация случайного MTProto secret (32 hex-символа)
  String _generateSecret() {
    final random = dart_math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AppStateProvider>();
    provider.updateProxyConfig(
      provider.state.proxyConfig.copyWith(
        type: _proxyType,
        host: _hostController.text,
        port: int.parse(_portController.text),
        useWebSocket: _useWebSocket,
        webSocketUrl: _useWebSocket ? _wsUrlController.text : null,
      ),
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Настройки сохранены'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}