/// Валидация ввода
class Validators {
  Validators._();

  /// Валидация порта
  static String? validatePort(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите порт';
    }
    final port = int.tryParse(value);
    if (port == null || port < 1 || port > 65535) {
      return 'Порт должен быть от 1 до 65535';
    }
    return null;
  }

  /// Валидация IP-адреса
  static String? validateHost(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите адрес';
    }
    // Простая проверка IPv4
    final parts = value.split('.');
    if (parts.length != 4) {
      return 'Неверный формат IP-адреса';
    }
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return 'Неверный формат IP-адреса';
      }
    }
    return null;
  }

  /// Валидация URL
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите URL';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Неверный формат URL';
    }
    return null;
  }

  /// Валидация домена
  static String? validateDomain(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите домен';
    }
    final domainRegex = RegExp(
      r'^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$',
    );
    if (!domainRegex.hasMatch(value)) {
      return 'Неверный формат домена';
    }
    return null;
  }

  /// Валидация CIDR
  static String? validateCidr(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите CIDR';
    }
    final parts = value.split('/');
    if (parts.length != 2) {
      return 'Неверный формат CIDR (пример: 192.168.1.0/24)';
    }
    final ipError = validateHost(parts[0]);
    if (ipError != null) return ipError;
    final prefix = int.tryParse(parts[1]);
    if (prefix == null || prefix < 0 || prefix > 32) {
      return 'Префикс должен быть от 0 до 32';
    }
    return null;
  }
}