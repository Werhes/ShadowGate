import '../core/types.dart';
import 'tun_config.dart';

/// Конфигурация целевого сервиса
class TargetConfig {
  final String id;
  final String name;
  final TargetService service;
  final List<String> domains;
  final List<String> ipRanges;
  final List<int> ports;
  final bool enabled;
  final List<DpiMethod> dpiMethods;

  const TargetConfig({
    required this.id,
    required this.name,
    required this.service,
    this.domains = const [],
    this.ipRanges = const [],
    this.ports = const [443, 80],
    this.enabled = true,
    this.dpiMethods = DpiMethodValues.defaults,
  });

  TargetConfig copyWith({
    String? id,
    String? name,
    TargetService? service,
    List<String>? domains,
    List<String>? ipRanges,
    List<int>? ports,
    bool? enabled,
    List<DpiMethod>? dpiMethods,
  }) {
    return TargetConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      service: service ?? this.service,
      domains: domains ?? this.domains,
      ipRanges: ipRanges ?? this.ipRanges,
      ports: ports ?? this.ports,
      enabled: enabled ?? this.enabled,
      dpiMethods: dpiMethods ?? this.dpiMethods,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'service': service.name,
        'domains': domains,
        'ipRanges': ipRanges,
        'ports': ports,
        'enabled': enabled,
        'dpiMethods': dpiMethods.map((e) => e.name).toList(),
      };

  factory TargetConfig.fromJson(Map<String, dynamic> json) => TargetConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        service: TargetService.values.firstWhere(
          (e) => e.name == json['service'],
          orElse: () => TargetService.custom,
        ),
        domains: List<String>.from(json['domains'] ?? []),
        ipRanges: List<String>.from(json['ipRanges'] ?? []),
        ports: List<int>.from(json['ports'] ?? [443, 80]),
        enabled: json['enabled'] as bool? ?? true,
        dpiMethods: (json['dpiMethods'] as List<dynamic>?)
                ?.map((e) => DpiMethod.values.firstWhere(
                      (m) => m.name == e,
                      orElse: () => DpiMethod.fragmentation,
                    ))
                .toList() ??
            DpiMethodValues.defaults,
      );

  /// Создание предустановленных целей
  static List<TargetConfig> get defaults => [
        TargetConfig(
          id: 'telegram',
          name: 'Telegram',
          service: TargetService.telegram,
          domains: ['api.telegram.org', 't.me', 'telegram.org'],
          ipRanges: ['149.154.160.0/20', '91.108.56.0/22'],
          ports: [443, 80],
        ),
        TargetConfig(
          id: 'discord',
          name: 'Discord',
          service: TargetService.discord,
          domains: ['discord.com', 'discord.gg', 'discordapp.net'],
          ipRanges: ['162.159.128.0/17'],
          ports: [443],
        ),
        TargetConfig(
          id: 'youtube',
          name: 'YouTube',
          service: TargetService.youtube,
          domains: ['youtube.com', 'googlevideo.com', 'ytimg.com'],
          ipRanges: ['142.250.0.0/15', '172.217.0.0/16'],
          ports: [443],
        ),
      ];
}