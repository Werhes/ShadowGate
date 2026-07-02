import 'package:flutter/material.dart';

/// Основные типы приложения
enum AppMode {
  proxy,
  tun;

  String get label {
    switch (this) {
      case AppMode.proxy:
        return 'Прокси';
      case AppMode.tun:
        return 'TUN';
    }
  }

  IconData get icon {
    switch (this) {
      case AppMode.proxy:
        return Icons.vpn_lock;
      case AppMode.tun:
        return Icons.settings_ethernet;
    }
  }

  String get description {
    switch (this) {
      case AppMode.proxy:
        return 'Локальный HTTP/SOCKS5 прокси-сервер';
      case AppMode.tun:
        return 'Виртуальный TUN-интерфейс с DPI-обходом';
    }
  }
}

/// Типы прокси
enum ProxyType {
  http,
  socks5;

  String get label {
    switch (this) {
      case ProxyType.http:
        return 'HTTP';
      case ProxyType.socks5:
        return 'SOCKS5';
    }
  }
}

/// Целевые сервисы
enum TargetService {
  telegram,
  discord,
  youtube,
  custom;

  String get label {
    switch (this) {
      case TargetService.telegram:
        return 'Telegram';
      case TargetService.discord:
        return 'Discord';
      case TargetService.youtube:
        return 'YouTube';
      case TargetService.custom:
        return 'Пользовательский';
    }
  }

  IconData get icon {
    switch (this) {
      case TargetService.telegram:
        return Icons.send;
      case TargetService.discord:
        return Icons.headset_mic;
      case TargetService.youtube:
        return Icons.play_circle;
      case TargetService.custom:
        return Icons.add_circle;
    }
  }
}

/// Методы DPI-обхода
enum DpiMethod {
  fragmentation,
  ttl,
  hostSpoof,
  packetReorder,
  tlsObfuscation;

  String get label {
    switch (this) {
      case DpiMethod.fragmentation:
        return 'Фрагментация TCP';
      case DpiMethod.ttl:
        return 'Изменение TTL';
      case DpiMethod.hostSpoof:
        return 'Подмена Host';
      case DpiMethod.packetReorder:
        return 'Перепаковка пакетов';
      case DpiMethod.tlsObfuscation:
        return 'TLS-обфускация';
    }
  }

  String get description {
    switch (this) {
      case DpiMethod.fragmentation:
        return 'Разбиение TCP-пакетов на мелкие фрагменты';
      case DpiMethod.ttl:
        return 'Установка TTL=1 для первого пакета handshake';
      case DpiMethod.hostSpoof:
        return 'Маскировка Host header под легитимный трафик';
      case DpiMethod.packetReorder:
        return 'Изменение порядка TCP-сегментов';
      case DpiMethod.tlsObfuscation:
        return 'Добавление случайных данных в TLS ClientHello';
    }
  }
}

/// Статус сервиса
enum ServiceStatus {
  stopped,
  starting,
  running,
  stopping,
  error;

  String get label {
    switch (this) {
      case ServiceStatus.stopped:
        return 'Остановлен';
      case ServiceStatus.starting:
        return 'Запускается...';
      case ServiceStatus.running:
        return 'Работает';
      case ServiceStatus.stopping:
        return 'Останавливается...';
      case ServiceStatus.error:
        return 'Ошибка';
    }
  }

  Color get color {
    switch (this) {
      case ServiceStatus.stopped:
        return Colors.grey;
      case ServiceStatus.starting:
        return Colors.orange;
      case ServiceStatus.running:
        return Colors.green;
      case ServiceStatus.stopping:
        return Colors.orange;
      case ServiceStatus.error:
        return Colors.red;
    }
  }
}