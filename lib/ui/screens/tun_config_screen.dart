import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/types.dart';
import '../../providers/app_state_provider.dart';
import '../theme/app_theme.dart';

/// Экран настроек TUN
class TunConfigScreen extends StatefulWidget {
  const TunConfigScreen({super.key});

  @override
  State<TunConfigScreen> createState() => _TunConfigScreenState();
}

class _TunConfigScreenState extends State<TunConfigScreen> {
  late TextEditingController _interfaceController;
  late TextEditingController _mtuController;
  late TextEditingController _dnsController;
  late bool _bypassLocal;
  late Set<DpiMethod> _selectedMethods;

  @override
  void initState() {
    super.initState();
    final config = context.read<AppStateProvider>().state.tunConfig;
    _interfaceController =
        TextEditingController(text: config.interfaceName);
    _mtuController = TextEditingController(text: config.mtu.toString());
    _dnsController = TextEditingController(text: config.dnsServer ?? '');
    _bypassLocal = config.bypassLocalTraffic;
    _selectedMethods = config.enabledMethods.toSet();
  }

  @override
  void dispose() {
    _interfaceController.dispose();
    _mtuController.dispose();
    _dnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Настройки TUN'),
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
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 10),

              // Интерфейс
              const SectionHeader(title: 'Интерфейс'),
              const SizedBox(height: 12),
              GradientContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _interfaceController,
                      decoration: const InputDecoration(
                        labelText: 'Имя интерфейса',
                        hintText: 'shadowgate0',
                        prefixIcon: Icon(Icons.settings_ethernet),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mtuController,
                      decoration: const InputDecoration(
                        labelText: 'MTU',
                        hintText: '1500',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dnsController,
                      decoration: const InputDecoration(
                        labelText: 'DNS-сервер (опционально)',
                        hintText: '8.8.8.8',
                        prefixIcon: Icon(Icons.dns),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Обход локального трафика
              GradientContainer(
                padding: const EdgeInsets.all(8),
                child: SwitchListTile(
                  title: const Text('Обходить локальный трафик'),
                  subtitle: const Text('Не маршрутизировать локальный трафик через TUN'),
                  value: _bypassLocal,
                  onChanged: (value) {
                    setState(() => _bypassLocal = value);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Методы DPI-обхода
              const SectionHeader(title: 'Методы DPI-обхода'),
              const SizedBox(height: 12),
              GradientContainer(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: DpiMethod.values.map((method) {
                    final isSelected = _selectedMethods.contains(method);
                    return CheckboxListTile(
                      title: Text(
                        method.label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        method.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      value: isSelected,
                      activeColor: AppTheme.primaryColor,
                      checkColor: Colors.white,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedMethods.add(method);
                          } else {
                            _selectedMethods.remove(method);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final provider = context.read<AppStateProvider>();
    provider.updateTunConfig(
      provider.state.tunConfig.copyWith(
        interfaceName: _interfaceController.text,
        mtu: int.tryParse(_mtuController.text) ?? 1500,
        dnsServer: _dnsController.text.isNotEmpty
            ? _dnsController.text
            : null,
        bypassLocalTraffic: _bypassLocal,
        enabledMethods: _selectedMethods.toList(),
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