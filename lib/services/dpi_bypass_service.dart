import 'dart:math';

import '../core/types.dart';
import '../utils/logger.dart';

/// Сервис DPI-обхода (zapret-style)
/// Реализует бесплатные методы обхода Deep Packet Inspection
///
/// Принципы работы (как в zapret и byebyedpi):
/// - Фрагментация TCP: разбиение пакетов на мелкие части (MSS clamping)
/// - HTTP Split: разделение HTTP-запроса на части (метод zapret)
/// - Подмена Host: маскировка под легитимный трафик
/// - TLS-обфускация: добавление случайных данных в ClientHello
/// - TTL: установка TTL=1 для первого пакета handshake
class DpiBypassService {
  static const _minFragmentSize = 1;
  static const _maxFragmentSize = 64;
  static const _tlsHandshakeType = 0x16;
  static const _httpMethodBytes = [
    // 'GET ', 'POST', 'PUT ', 'HEAD', etc.
    0x47, 0x45, 0x54, 0x20, // GET
    0x50, 0x4F, 0x53, 0x54, // POST
    0x48, 0x45, 0x41, 0x44, // HEAD
    0x50, 0x55, 0x54, 0x20, // PUT
    0x44, 0x45, 0x4C, 0x45, // DELE
    0x43, 0x4F, 0x4E, 0x4E, // CONN
    0x4F, 0x50, 0x54, 0x49, // OPTI
    0x50, 0x41, 0x54, 0x43, // PATC
  ];

  final _random = Random.secure();

  /// Применение методов DPI-обхода к пакету
  Future<List<int>> applyDpiMethods(
    List<int> packet,
    List<DpiMethod> methods,
  ) async {
    if (packet.isEmpty) return packet;
    var processed = packet;

    for (final method in methods) {
      processed = await _applyMethod(processed, method);
    }

    return processed;
  }

  /// Применение конкретного метода
  Future<List<int>> _applyMethod(
    List<int> packet,
    DpiMethod method,
  ) async {
    switch (method) {
      case DpiMethod.fragmentation:
        return _applyFragmentation(packet);
      case DpiMethod.ttl:
        return _applyTtlChange(packet);
      case DpiMethod.hostSpoof:
        return _applyHostSpoof(packet);
      case DpiMethod.packetReorder:
        return _applyPacketReorder(packet);
      case DpiMethod.tlsObfuscation:
        return _applyTlsObfuscation(packet);
      case DpiMethod.httpSplit:
        return _applyHttpSplit(packet);
      case DpiMethod.quicObfuscation:
        return _applyQuicObfuscation(packet);
    }
  }

  /// Фрагментация TCP-пакетов (MSS clamping)
  /// Разбиение на мелкие фрагменты для обхода DPI
  /// Как в zapret: --split-http, --split-tls
  List<int> _applyFragmentation(List<int> packet) {
    if (packet.length <= _maxFragmentSize) return packet;

    Logger.debug(
      'Фрагментация TCP: ${packet.length} байт -> '
      'фрагменты по $_maxFragmentSize байт',
    );

    // Вставляем "мусорные" байты между фрагментами,
    // чтобы сбить DPI с толку (как в byebyedpi)
    final result = <int>[];
    int offset = 0;

    while (offset < packet.length) {
      final chunkSize = _random.nextInt(_maxFragmentSize - _minFragmentSize + 1) +
          _minFragmentSize;
      final end = (offset + chunkSize).clamp(0, packet.length);
      result.addAll(packet.sublist(offset, end));

      // Добавляем случайный мусор между фрагментами (для обхода DPI)
      if (end < packet.length) {
        final garbageLen = _random.nextInt(4) + 1;
        for (int i = 0; i < garbageLen; i++) {
          result.add(_random.nextInt(256));
        }
      }

      offset = end;
    }

    return result;
  }

  /// Изменение TTL
  /// Установка TTL=1 для первого пакета handshake
  /// Как в zapret: --ttl=1
  List<int> _applyTtlChange(List<int> packet) {
    if (packet.length < 20) return packet; // Минимальный IP-заголовок

    Logger.debug('Применение изменения TTL');

    // IP-заголовок: байт 8 — это TTL
    // Устанавливаем TTL=1 для первого пакета,
    // чтобы DPI не мог собрать полную картину
    final result = List<int>.from(packet);
    if (result.length > 8) {
      result[8] = 1; // TTL = 1
      // Пересчитываем контрольную сумму IP-заголовка
      _recalculateIpChecksum(result);
    }

    return result;
  }

  /// Подмена Host header
  /// Маскировка под легитимный трафик (как в zapret --hostspell)
  List<int> _applyHostSpoof(List<int> packet) {
    Logger.debug('Применение подмены Host');

    // Ищем "Host:" в пакете и подменяем на легитимный домен
    final packetStr = String.fromCharCodes(packet);
    final hostMatch = RegExp(r'Host:\s*([^\r\n]+)', caseSensitive: false)
        .firstMatch(packetStr);

    if (hostMatch == null) return packet;

    final originalHost = hostMatch.group(1)!;
    final spoofedHost = _getSpoofedHost(originalHost);

    if (spoofedHost == originalHost) return packet;

    Logger.debug('Подмена Host: $originalHost -> $spoofedHost');

    final result = packetStr.replaceFirst(
      RegExp(RegExp.escape(originalHost), caseSensitive: false),
      spoofedHost,
    );

    return result.codeUnits;
  }

  /// Получение легитимного домена для подмены
  String _getSpoofedHost(String originalHost) {
    // Список популярных легитимных доменов для маскировки
    const spoofDomains = [
      'cloudflare.com',
      'googleapis.com',
      'akamaihd.net',
      'cloudfront.net',
      'fastly.net',
      'microsoft.com',
      'apple.com',
      'amazonaws.com',
    ];

    // Если хост уже легитимный, не меняем
    for (final domain in spoofDomains) {
      if (originalHost.contains(domain)) return originalHost;
    }

    return spoofDomains[_random.nextInt(spoofDomains.length)];
  }

  /// Перепаковка пакетов
  /// Изменение порядка TCP-сегментов для обхода DPI
  List<int> _applyPacketReorder(List<int> packet) {
    if (packet.length < 40) return packet; // Слишком маленький пакет

    Logger.debug('Применение перепаковки пакетов');

    // Разбиваем пакет на сегменты и перемешиваем их
    // DPI ожидает пакеты в определённом порядке,
    // перестановка сбивает анализ
    const segmentSize = 16;
    final segments = <List<int>>[];

    for (int i = 0; i < packet.length; i += segmentSize) {
      final end = (i + segmentSize).clamp(0, packet.length);
      segments.add(packet.sublist(i, end));
    }

    // Перемешиваем сегменты (кроме первого — IP-заголовок)
    if (segments.length > 2) {
      final bodySegments = segments.sublist(1);
      bodySegments.shuffle(_random);
      segments
        ..length = 1
        ..addAll(bodySegments);
    }

    return segments.expand((s) => s).toList();
  }

  /// TLS-обфускация
  /// Добавление случайных данных в TLS ClientHello
  /// Как в byebyedpi: рандомизация TLS handshake
  List<int> _applyTlsObfuscation(List<int> packet) {
    // Проверяем, что это TLS ClientHello
    if (packet.length < 5) return packet;
    if (packet[0] != _tlsHandshakeType) return packet; // Не TLS

    Logger.debug('Применение TLS-обфускации');

    // Добавляем случайные байты в TLS-запись
    // Это сбивает DPI, который пытается анализировать SNI
    final result = List<int>.from(packet);

    // Вставляем случайные байты после ContentType (байт 0)
    // но перед длиной TLS-записи
    final paddingLen = _random.nextInt(16) + 4;
    final padding = List<int>.generate(paddingLen, (_) => _random.nextInt(256));

    // Вставляем padding после первого байта
    result.insertAll(1, padding);

    // Обновляем длину TLS-записи (байты 3-4)
    if (result.length > 4) {
      final newLen = result.length - 5;
      result[3] = (newLen >> 8) & 0xFF;
      result[4] = newLen & 0xFF;
    }

    return result;
  }

  /// HTTP Split (как в zapret)
  /// Разделение HTTP-запроса на части для обхода DPI
  /// Ключевой метод zapret: --split-http
  List<int> _applyHttpSplit(List<int> packet) {
    // Проверяем, что это HTTP-запрос
    if (packet.length < 20) return packet;

    final isHttp = _httpMethodBytes.contains(packet[0]) &&
        _httpMethodBytes.contains(packet[1]) &&
        _httpMethodBytes.contains(packet[2]);

    if (!isHttp) return packet;

    Logger.debug('Применение HTTP Split');

    // Разделяем HTTP-запрос на две части:
    // 1. Первая строка (метод + URI)
    // 2. Заголовки и тело
    //
    // DPI обычно анализирует только первый пакет,
    // разделение заставляет DPI пропустить трафик

    final packetStr = String.fromCharCodes(packet);
    final firstLineEnd = packetStr.indexOf('\r\n');

    if (firstLineEnd < 0 || firstLineEnd >= packet.length - 2) return packet;

    // Вставляем задержку в виде случайных байт между первой строкой и заголовками
    final firstLine = packet.sublist(0, firstLineEnd + 2); // Включая \r\n
    final rest = packet.sublist(firstLineEnd + 2);

    // Добавляем "мусорный" заголовок между первой строкой и остальными
    final fakeHeader = 'X-Ignore: ${_random.nextInt(999999)}\r\n'.codeUnits;

    return [...firstLine, ...fakeHeader, ...rest];
  }

  /// QUIC-обфускация
  /// Обфускация QUIC (HTTP/3) пакетов
  List<int> _applyQuicObfuscation(List<int> packet) {
    // QUIC пакеты начинаются с флага (первые биты)
    if (packet.isEmpty) return packet;

    // Проверяем, похоже ли на QUIC (первые 2 бита = 0b11 или 0b10)
    final firstByte = packet[0];
    if ((firstByte & 0xC0) != 0xC0 && (firstByte & 0xC0) != 0x80) {
      return packet; // Не QUIC
    }

    Logger.debug('Применение QUIC-обфускации');

    // Обфусцируем QUIC-пакет, меняя Connection ID
    // (первые байты после флага)
    final result = List<int>.from(packet);

    // Меняем несколько байт в заголовке QUIC
    // (не затрагивая критически важные поля)
    final dcil = (firstByte & 0x0F); // Destination Connection ID Length
    if (dcil > 0 && result.length > 1 + dcil) {
      for (int i = 1; i < 1 + dcil && i < result.length; i++) {
        // Меняем только некоторые байты, чтобы не сломать соединение
        if (_random.nextBool()) {
          result[i] = _random.nextInt(256);
        }
      }
    }

    return result;
  }

  /// Пересчёт контрольной суммы IP-заголовка
  void _recalculateIpChecksum(List<int> packet) {
    if (packet.length < 20) return;

    // Обнуляем контрольную сумму
    packet[10] = 0;
    packet[11] = 0;

    // Вычисляем новую
    int sum = 0;
    for (int i = 0; i < 20; i += 2) {
      sum += (packet[i] << 8) | packet[i + 1];
    }

    while (sum >> 16 != 0) {
      sum = (sum & 0xFFFF) + (sum >> 16);
    }

    packet[10] = (~sum >> 8) & 0xFF;
    packet[11] = ~sum & 0xFF;
  }
}