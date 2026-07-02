import 'package:flutter/material.dart';

import '../../core/types.dart';
import '../../models/target_config.dart';
import '../theme/app_theme.dart';

/// Экран управления целями — Hiddify-стиль
class TargetsScreen extends StatefulWidget {
  const TargetsScreen({super.key});

  @override
  State<TargetsScreen> createState() => _TargetsScreenState();
}

class _TargetsScreenState extends State<TargetsScreen> {
  final List<TargetConfig> _targets = TargetConfig.defaults;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Целевые сервисы'),
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
              icon: const Icon(Icons.add),
              onPressed: _showAddTargetDialog,
              tooltip: 'Добавить цель',
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: SafeArea(
          child: _targets.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _targets.length,
                  itemBuilder: (context, index) {
                    final target = _targets[index];
                    return _TargetCard(
                      target: target,
                      onToggle: () {
                        setState(() {
                          _targets[index] = target.copyWith(
                            enabled: !target.enabled,
                          );
                        });
                      },
                      onDelete: () {
                        setState(() => _targets.removeAt(index));
                      },
                      onEdit: () => _showEditTargetDialog(target, index),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.cardBorderColor.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              Icons.track_changes,
              size: 40,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Нет целей',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте целевые сервисы для обхода блокировок',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Добавить цель',
            icon: Icons.add,
            onPressed: _showAddTargetDialog,
            height: 48,
          ),
        ],
      ),
    );
  }

  void _showAddTargetDialog() {
    _showTargetDialog(null, -1);
  }

  void _showEditTargetDialog(TargetConfig target, int index) {
    _showTargetDialog(target, index);
  }

  void _showTargetDialog(TargetConfig? existing, int index) {
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    final domainsController = TextEditingController(
      text: existing?.domains.join(', ') ?? '',
    );
    final ipRangesController = TextEditingController(
      text: existing?.ipRanges.join(', ') ?? '',
    );
    final portsController = TextEditingController(
      text: existing?.ports.join(', ') ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.cardBorderColor.withValues(alpha: 0.5),
          ),
        ),
        title: Text(
          existing != null ? 'Редактировать цель' : 'Новая цель',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Название',
                  hintText: 'Мой сервис',
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: domainsController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Домены (через запятую)',
                  hintText: 'example.com, api.example.com',
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ipRangesController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'IP-диапазоны (через запятую)',
                  hintText: '192.168.1.0/24, 10.0.0.0/8',
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portsController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Порты (через запятую)',
                  hintText: '443, 80',
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Отмена',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          GradientButton(
            label: 'Сохранить',
            onPressed: () {
              if (nameController.text.isEmpty) return;

              final target = TargetConfig(
                id: existing?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text,
                service: TargetService.custom,
                domains: domainsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
                ipRanges: ipRangesController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
                ports: portsController.text
                    .split(',')
                    .map((e) => int.tryParse(e.trim()))
                    .where((e) => e != null)
                    .cast<int>()
                    .toList(),
              );

              setState(() {
                if (existing != null && index >= 0) {
                  _targets[index] = target;
                } else {
                  _targets.add(target);
                }
              });

              Navigator.pop(context);
            },
            height: 44,
          ),
        ],
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  final TargetConfig target;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TargetCard({
    required this.target,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(4),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: target.enabled
                  ? AppTheme.primaryGradient
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              target.service.icon,
              color: target.enabled ? Colors.white : AppTheme.textMuted,
              size: 22,
            ),
          ),
          title: Text(
            target.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: target.enabled
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
            ),
          ),
          subtitle: Text(
            '${target.domains.length} доменов, ${target.ipRanges.length} IP-диапазонов',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.edit,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                onPressed: onEdit,
                tooltip: 'Редактировать',
              ),
              Switch(
                value: target.enabled,
                onChanged: (_) => onToggle(),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppTheme.errorColor.withValues(alpha: 0.7),
                ),
                onPressed: onDelete,
                tooltip: 'Удалить',
              ),
            ],
          ),
          onTap: onEdit,
        ),
      ),
    );
  }
}