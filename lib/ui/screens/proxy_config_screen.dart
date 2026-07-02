import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/types.dart';
import '../../providers/app_state_provider.dart';
import '../../utils/validators.dart';
import '../theme/app_theme.dart';

/// Экран настроек прокси
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Настройки прокси'),
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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
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
                GradientContainer(
                  padding: const EdgeInsets.all(16),
                  child: SegmentedButton<ProxyType>(
                    segments: ProxyType.values.map((type) {
                      return ButtonSegment(
                        value: type,
                        label: Text(
                          type.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
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
                        return Colors.white.withValues(alpha: 0.6);
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Адрес и порт
                const SectionHeader(title: 'Соединение'),
                const SizedBox(height: 12),
                GradientContainer(
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
                        decoration: const InputDecoration(
                          labelText: 'Порт',
                          hintText: '1080',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        keyboardType: TextInputType.number,
                        validator: Validators.validatePort,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // WebSocket
                const SectionHeader(title: 'WebSocket'),
                const SizedBox(height: 12),
                GradientContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Использовать WebSocket'),
                        subtitle: const Text('Перенаправлять трафик через WebSocket'),
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
                          decoration: const InputDecoration(
                            labelText: 'WebSocket URL',
                            hintText: 'wss://example.com/ws',
                            prefixIcon: Icon(Icons.link),
                          ),
                          validator: _useWebSocket ? Validators.validateUrl : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}