import 'package:flutter/material.dart';

/// Типы тем приложения
enum AppThemeType {
  violet, // Фиолетовая (Hiddify-style)
  amber, // Жёлтая/коричневая
  emerald, // Изумрудная/зелёная
  ruby, // Красная/рубиновая
  ocean; // Синяя/океан

  /// Отображаемое название темы
  String get label {
    switch (this) {
      case AppThemeType.violet:
        return 'Фиолетовая';
      case AppThemeType.amber:
        return 'Янтарная';
      case AppThemeType.emerald:
        return 'Изумрудная';
      case AppThemeType.ruby:
        return 'Рубиновая';
      case AppThemeType.ocean:
        return 'Океан';
    }
  }

  /// Иконка темы
  IconData get icon {
    switch (this) {
      case AppThemeType.violet:
        return Icons.color_lens;
      case AppThemeType.amber:
        return Icons.wb_sunny;
      case AppThemeType.emerald:
        return Icons.eco;
      case AppThemeType.ruby:
        return Icons.favorite;
      case AppThemeType.ocean:
        return Icons.water_drop;
    }
  }

  /// Цвет для предпросмотра
  Color get previewColor {
    switch (this) {
      case AppThemeType.violet:
        return const Color(0xFF8B5CF6);
      case AppThemeType.amber:
        return const Color(0xFFD97706);
      case AppThemeType.emerald:
        return const Color(0xFF059669);
      case AppThemeType.ruby:
        return const Color(0xFFDC2626);
      case AppThemeType.ocean:
        return const Color(0xFF0284C7);
    }
  }
}

/// Тема приложения — Hiddify-стиль с поддержкой кастомизации
class AppTheme {
  AppTheme._();

  // ===== Цвета по умолчанию (фиолетовая тема) =====
  static const Color defaultPrimary = Color(0xFF8B5CF6);
  static const Color defaultPrimaryLight = Color(0xFFA78BFA);
  static const Color defaultSecondary = Color(0xFF06B6D4);

  // ===== Янтарная тема =====
  static const Color amberPrimary = Color(0xFFD97706);
  static const Color amberPrimaryLight = Color(0xFFF59E0B);
  static const Color amberSecondary = Color(0xFFFCD34D);

  // ===== Изумрудная тема =====
  static const Color emeraldPrimary = Color(0xFF059669);
  static const Color emeraldPrimaryLight = Color(0xFF10B981);
  static const Color emeraldSecondary = Color(0xFF34D399);

  // ===== Рубиновая тема =====
  static const Color rubyPrimary = Color(0xFFDC2626);
  static const Color rubyPrimaryLight = Color(0xFFEF4444);
  static const Color rubySecondary = Color(0xFFFB7185);

  // ===== Океан тема =====
  static const Color oceanPrimary = Color(0xFF0284C7);
  static const Color oceanPrimaryLight = Color(0xFF38BDF8);
  static const Color oceanSecondary = Color(0xFF7DD3FC);

  // ===== Общие цвета =====
  static const Color surfaceColor = Color(0xFF1E1B2E);
  static const Color backgroundColor = Color(0xFF0F0D1A);
  static const Color cardColor = Color(0xFF1A1630);
  static const Color cardBorderColor = Color(0xFF2D2A4A);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFF1F0FF);
  static const Color textSecondary = Color(0xFF9D97B5);
  static const Color textMuted = Color(0xFF6B6580);

  /// Получение primary цвета по типу темы
  static Color primaryFor(AppThemeType type) {
    switch (type) {
      case AppThemeType.violet:
        return defaultPrimary;
      case AppThemeType.amber:
        return amberPrimary;
      case AppThemeType.emerald:
        return emeraldPrimary;
      case AppThemeType.ruby:
        return rubyPrimary;
      case AppThemeType.ocean:
        return oceanPrimary;
    }
  }

  /// Получение primaryLight цвета по типу темы
  static Color primaryLightFor(AppThemeType type) {
    switch (type) {
      case AppThemeType.violet:
        return defaultPrimaryLight;
      case AppThemeType.amber:
        return amberPrimaryLight;
      case AppThemeType.emerald:
        return emeraldPrimaryLight;
      case AppThemeType.ruby:
        return rubyPrimaryLight;
      case AppThemeType.ocean:
        return oceanPrimaryLight;
    }
  }

  /// Получение secondary цвета по типу темы
  static Color secondaryFor(AppThemeType type) {
    switch (type) {
      case AppThemeType.violet:
        return defaultSecondary;
      case AppThemeType.amber:
        return amberSecondary;
      case AppThemeType.emerald:
        return emeraldSecondary;
      case AppThemeType.ruby:
        return rubySecondary;
      case AppThemeType.ocean:
        return oceanSecondary;
    }
  }

  /// Получение primary градиента по типу темы
  static LinearGradient primaryGradientFor(AppThemeType type) {
    return LinearGradient(
      colors: [primaryFor(type), secondaryFor(type)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Получение glow градиента по типу темы
  static LinearGradient glowGradientFor(AppThemeType type) {
    return LinearGradient(
      colors: [
        primaryFor(type),
        secondaryFor(type),
        primaryFor(type),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Создание ThemeData для указанного типа темы
  static ThemeData themeFor(AppThemeType type) {
    final primary = primaryFor(type);
    final secondary = secondaryFor(type);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        onError: Colors.white,
        primaryContainer: primary.withValues(alpha: 0.15),
        secondaryContainer: secondary.withValues(alpha: 0.15),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cardBorderColor.withValues(alpha: 0.5)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: cardBorderColor.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.5);
          }
          return Colors.grey.withValues(alpha: 0.3);
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: surfaceColor,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(
        color: cardBorderColor.withValues(alpha: 0.5),
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardColor,
        selectedColor: primary.withValues(alpha: 0.3),
        labelStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // ===== Градиенты (для обратной совместимости) =====
  static LinearGradient get primaryGradient =>
      primaryGradientFor(AppThemeType.violet);
  static LinearGradient get accentGradient => const LinearGradient(
        colors: [errorColor, Color(0xFFFB7185)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
  static LinearGradient get successGradient => const LinearGradient(
        colors: [successColor, Color(0xFF34D399)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
  static LinearGradient get surfaceGradient => const LinearGradient(
        colors: [backgroundColor, surfaceColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
  static LinearGradient get cardGradient => const LinearGradient(
        colors: [cardColor, Color(0xFF1F1B3A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
  static LinearGradient get glowGradient => glowGradientFor(AppThemeType.violet);

  // ===== Константы для обратной совместимости =====
  static Color get primaryColor => defaultPrimary;
  static Color get primaryLight => defaultPrimaryLight;
  static Color get secondaryColor => defaultSecondary;
  static Color get accentColor => errorColor;

  /// Стандартная тёмная тема (фиолетовая)
  static ThemeData get darkTheme => themeFor(AppThemeType.violet);
}

/// Декоративный контейнер с градиентом и глянцевым эффектом
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final LinearGradient? gradient;
  final bool hasGlow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.gradient,
    this.hasGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ?? AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppTheme.cardBorderColor.withValues(alpha: 0.5),
        ),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Кнопка с градиентом Hiddify
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final LinearGradient? gradient;
  final double height;
  final Color? backgroundColor;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.gradient,
    this.height = 56,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ?? AppTheme.primaryGradient;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: onPressed != null ? effectiveGradient : null,
        color: onPressed == null
            ? Colors.grey.withValues(alpha: 0.3)
            : backgroundColor,
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Секция с заголовком
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: AppTheme.textPrimary,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Анимированный индикатор статуса с пульсацией
class StatusIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const StatusIndicator({
    super.key,
    required this.color,
    this.size = 16,
  });

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _animation.value * 0.6),
                blurRadius: widget.size,
                spreadRadius: widget.size / 4,
              ),
            ],
          ),
        );
      },
    );
  }
}