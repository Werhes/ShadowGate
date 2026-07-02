import 'package:flutter/material.dart';

import '../../core/types.dart';
import '../theme/app_theme.dart';

/// Виджет выбора режима с красивыми карточками
class ModeSelector extends StatelessWidget {
  final AppMode currentMode;
  final ValueChanged<AppMode> onModeChanged;

  const ModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: AppMode.values.map((mode) {
        final isSelected = mode == currentMode;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: mode == AppMode.proxy ? 8 : 0,
              left: mode == AppMode.tun ? 8 : 0,
            ),
            child: _ModeCard(
              mode: mode,
              isSelected: isSelected,
              onTap: () => onModeChanged(mode),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final AppMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.3),
                    AppTheme.secondaryColor.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    AppTheme.cardColor,
                    AppTheme.cardColor,
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? AppTheme.primaryGradient
                    : LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                mode.icon,
                size: 28,
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              mode.label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mode.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: isSelected ? 0.7 : 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}