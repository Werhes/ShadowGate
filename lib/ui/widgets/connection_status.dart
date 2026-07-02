import 'package:flutter/material.dart';

import '../../core/types.dart';
import '../theme/app_theme.dart';

/// Виджет статуса подключения — Hiddify-стиль
class ConnectionStatus extends StatelessWidget {
  final ServiceStatus status;
  final String? errorMessage;
  final String speed;
  final String traffic;

  const ConnectionStatus({
    super.key,
    required this.status,
    this.errorMessage,
    required this.speed,
    required this.traffic,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      hasGlow: status == ServiceStatus.running,
      child: Column(
        children: [
          // Индикатор статуса с пульсацией
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatusIndicator(
                color: status.color,
                size: 20,
              ),
              const SizedBox(width: 14),
              Text(
                status.label,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: status.color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          if (status == ServiceStatus.error && errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.errorColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppTheme.errorColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (status == ServiceStatus.running) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.speed,
                    label: 'Скорость',
                    value: speed,
                    gradient: AppTheme.primaryGradient,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatItem(
                    icon: Icons.swap_vert,
                    label: 'Трафик',
                    value: traffic,
                    gradient: AppTheme.successGradient,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final LinearGradient gradient;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.cardBorderColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}