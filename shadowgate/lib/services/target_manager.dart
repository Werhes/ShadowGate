import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/target_config.dart';
import '../utils/logger.dart';

/// Менеджер целевых сервисов
class TargetManager {
  List<TargetConfig> _targets = [];
  bool _initialized = false;

  List<TargetConfig> get targets => List.unmodifiable(_targets);

  List<TargetConfig> get enabledTargets =>
      _targets.where((t) => t.enabled).toList();

  /// Инициализация из SharedPreferences
  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final targetsJson = prefs.getString(AppConstants.prefTargets);

      if (targetsJson != null) {
        final list = jsonDecode(targetsJson) as List<dynamic>;
        _targets = list
            .map((e) => TargetConfig.fromJson(e as Map<String, dynamic>))
            .toList();
        Logger.info('Загружено ${_targets.length} целей');
      } else {
        // Загружаем цели по умолчанию
        _targets = TargetConfig.defaults;
        await _save();
        Logger.info('Загружены цели по умолчанию');
      }

      _initialized = true;
    } catch (e) {
      Logger.error('Ошибка загрузки целей: $e');
      _targets = TargetConfig.defaults;
      _initialized = true;
    }
  }

  /// Добавление цели
  Future<void> addTarget(TargetConfig target) async {
    _targets.add(target);
    await _save();
    Logger.info('Добавлена цель: ${target.name}');
  }

  /// Обновление цели
  Future<void> updateTarget(TargetConfig target) async {
    final index = _targets.indexWhere((t) => t.id == target.id);
    if (index != -1) {
      _targets[index] = target;
      await _save();
      Logger.info('Обновлена цель: ${target.name}');
    }
  }

  /// Удаление цели
  Future<void> removeTarget(String id) async {
    _targets.removeWhere((t) => t.id == id);
    await _save();
    Logger.info('Удалена цель с id: $id');
  }

  /// Включение/отключение цели
  Future<void> toggleTarget(String id) async {
    final index = _targets.indexWhere((t) => t.id == id);
    if (index != -1) {
      _targets[index] = _targets[index].copyWith(
        enabled: !_targets[index].enabled,
      );
      await _save();
    }
  }

  /// Сохранение в SharedPreferences
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_targets.map((t) => t.toJson()).toList());
      await prefs.setString(AppConstants.prefTargets, json);
    } catch (e) {
      Logger.error('Ошибка сохранения целей: $e');
    }
  }
}