import 'package:flutter/material.dart';

import '../../models/target_config.dart';
import '../theme/app_theme.dart';

/// Виджет списка целей с красивым дизайном
class TargetList extends StatelessWidget {
  final List<TargetConfig> targets;
  final ValueChanged<String> onToggle;
  final VoidCallback onAdd;

  const TargetList({
    super.key,
    required this.targets,
    required this.onToggle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (targets.isEmpty) {
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
              ),
              child: Icon(
                Icons.track_changes,
                size: 40,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Нет целей',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте целевые сервисы\nдля обхода блокировок',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Добавить цель',
              icon: Icons.add,
              onPressed: onAdd,
              height: 48,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        return _TargetItem(
          target: target,
          onToggle: () => onToggle(target.id),
        );
      },
    );
  }
}

class _TargetItem extends StatelessWidget {
  final TargetConfig target;
  final VoidCallback onToggle;

  const _TargetItem({
    required this.target,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GradientContainer(
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
              color: target.enabled ? Colors.white : Colors.white.withValues(alpha: 0.4),
              size: 22,
            ),
          ),
          title: Text(
            target.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: target.enabled ? Colors.white : Colors.white.withValues(alpha: 0.5),
            ),
          ),
          subtitle: Text(
            '${target.domains.length} доменов, ${target.ipRanges.length} IP-диапазонов',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          trailing: Switch(
            value: target.enabled,
            onChanged: (_) => onToggle(),
          ),
          onTap: onToggle,
        ),
      ),
    );
  }
}