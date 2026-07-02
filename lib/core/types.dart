import 'package:flutter/material.dart';

/// Основные режимы приложения
enum AppMode {
  proxy,
  tun,
  mtproto;

  String get label {
    switch (this) {
      case AppMode.proxy:
        return 'Прокси';
      case AppMode.tun:
        return 'TUN';
      case AppMode.mtproto:
        return 'MTProto';
    }
  }

  IconData get icon {
    switch (this) {
      case AppMode.proxy:
        return Icons.vpn_lock;
      case AppMode.tun:
        return Icons.settings_ethernet;
      case AppMode.mtproto:
        return Icons.telegram;
    }
  }

  String get description {
    switch (this) {
      case AppMode.proxy:
        return 'Локальный HTTP/SOCKS5 прокси-сервер';
      case AppMode.tun:
        return 'Виртуальный TUN-интерфейс с DPI-обходом';
      case AppMode.mtproto:
        return 'Telegram MTProto прокси (бесплатный обход блокировок)';
    }
  }
}

/// Типы прокси
enum ProxyType {
  http,
  socks5,
  mtproto;

  String get label {
    switch (this) {
      case ProxyType.http:
        return 'HTTP';
      case ProxyType.socks5:
        return 'SOCKS5';
      case ProxyType.mtproto:
        return 'MTProto';
    }
  }

  IconData get icon {
    switch (this) {
      case ProxyType.http:
        return Icons.http;
      case ProxyType.socks5:
        return Icons.vpn_lock;
      case ProxyType.mtproto:
        return Icons.telegram;
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

/// Методы DPI-обхода (zapret-style)
enum DpiMethod {
  fragmentation,
  ttl,
  hostSpoof,
  packetReorder,
  tlsObfuscation,
  httpSplit,
  quicObfuscation;

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
      case DpiMethod.httpSplit:
        return 'HTTP Split';
      case DpiMethod.quicObfuscation:
        return 'QUIC-обфускация';
    }
  }

  String get description {
    switch (this) {
      case DpiMethod.fragmentation:
        return 'Разбиение TCP-пакетов на мелкие фрагменты (MSS clamping)';
      case DpiMethod.ttl:
        return 'Установка TTL=1 для первого пакета handshake';
      case DpiMethod.hostSpoof:
        return 'Маскировка Host header под легитимный трафик';
      case DpiMethod.packetReorder:
        return 'Изменение порядка TCP-сегментов';
      case DpiMethod.tlsObfuscation:
        return 'Добавление случайных данных в TLS ClientHello';
      case DpiMethod.httpSplit:
        return 'Разделение HTTP-запроса на части (как в zapret)';
      case DpiMethod.quicObfuscation:
        return 'Обфускация QUIC (HTTP/3) пакетов';
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
        return const Color(0xFF00E676);
      case ServiceStatus.stopping:
        return Colors.orange;
      case ServiceStatus.error:
        return const Color(0xFFFF5252);
    }
  }
}