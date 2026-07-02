import '../core/types.dart';

/// Конфигурация прокси-режима
class ProxyConfig {
  final ProxyType type;
  final String host;
  final int port;
  final bool useWebSocket;
  final String? webSocketUrl;
  final String? username;
  final String? password;

  const ProxyConfig({
    this.type = ProxyType.socks5,
    this.host = '127.0.0.1',
    this.port = 1080,
    this.useWebSocket = false,
    this.webSocketUrl,
    this.username,
    this.password,
  });

  ProxyConfig copyWith({
    ProxyType? type,
    String? host,
    int? port,
    bool? useWebSocket,
    String? webSocketUrl,
    String? username,
    String? password,
  }) {
    return ProxyConfig(
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      useWebSocket: useWebSocket ?? this.useWebSocket,
      webSocketUrl: webSocketUrl ?? this.webSocketUrl,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'host': host,
        'port': port,
        'useWebSocket': useWebSocket,
        'webSocketUrl': webSocketUrl,
        'username': username,
        'password': password,
      };

  factory ProxyConfig.fromJson(Map<String, dynamic> json) => ProxyConfig(
        type: ProxyType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => ProxyType.socks5,
        ),
        host: json['host'] as String? ?? '127.0.0.1',
        port: json['port'] as int? ?? 1080,
        useWebSocket: json['useWebSocket'] as bool? ?? false,
        webSocketUrl: json['webSocketUrl'] as String?,
        username: json['username'] as String?,
        password: json['password'] as String?,
      );
}