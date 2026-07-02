import '../core/types.dart';

/// Конфигурация TUN-режима
class TunConfig {
  final String interfaceName;
  final String? dnsServer;
  final List<DpiMethod> enabledMethods;
  final int mtu;
  final bool bypassLocalTraffic;

  const TunConfig({
    this.interfaceName = 'shadowgate0',
    this.dnsServer,
    this.enabledMethods = DpiMethodValues.defaults,
    this.mtu = 1500,
    this.bypassLocalTraffic = true,
  });

  TunConfig copyWith({
    String? interfaceName,
    String? dnsServer,
    List<DpiMethod>? enabledMethods,
    int? mtu,
    bool? bypassLocalTraffic,
  }) {
    return TunConfig(
      interfaceName: interfaceName ?? this.interfaceName,
      dnsServer: dnsServer ?? this.dnsServer,
      enabledMethods: enabledMethods ?? this.enabledMethods,
      mtu: mtu ?? this.mtu,
      bypassLocalTraffic: bypassLocalTraffic ?? this.bypassLocalTraffic,
    );
  }

  Map<String, dynamic> toJson() => {
        'interfaceName': interfaceName,
        'dnsServer': dnsServer,
        'enabledMethods': enabledMethods.map((e) => e.name).toList(),
        'mtu': mtu,
        'bypassLocalTraffic': bypassLocalTraffic,
      };

  factory TunConfig.fromJson(Map<String, dynamic> json) => TunConfig(
        interfaceName: json['interfaceName'] as String? ?? 'shadowgate0',
        dnsServer: json['dnsServer'] as String?,
        enabledMethods: (json['enabledMethods'] as List<dynamic>?)
                ?.map((e) => DpiMethod.values.firstWhere(
                      (m) => m.name == e,
                      orElse: () => DpiMethod.fragmentation,
                    ))
                .toList() ??
            DpiMethodValues.defaults,
        mtu: json['mtu'] as int? ?? 1500,
        bypassLocalTraffic: json['bypassLocalTraffic'] as bool? ?? true,
      );
}

/// Вспомогательный класс для значений по умолчанию
class DpiMethodValues {
  DpiMethodValues._();

  static const List<DpiMethod> defaults = [
    DpiMethod.fragmentation,
    DpiMethod.ttl,
  ];

  static const List<DpiMethod> all = DpiMethod.values;
}