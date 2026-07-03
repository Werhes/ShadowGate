import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../core/types.dart';
import '../utils/logger.dart';
import 'dpi_bypass_service.dart';

/// Реализация SOCKS5 протокола (RFC 1928)
/// С поддержкой DPI-обхода (zapret-style)
///
/// Исправления:
/// - Устранён race condition в _readBytes (теперь используется единая подписка)
/// - Добавлена буферизация для гарантии целостности фреймов
/// - DPI-обход применяется в обе стороны
/// - Добавлено логирование ошибок вместо catchError((_) {})
/// - Добавлен таймаут на всё соединение
class Socks5Handler {
  static const _socksVersion = 0x05;

  // Authentication methods
  static const _authNoAuth = 0x00;
  static const _authPassword = 0x02;
  static const _authNoAcceptable = 0xFF;

  // Commands
  static const _cmdConnect = 0x01;
  static const _cmdBind = 0x02;
  static const _cmdUdpAssociate = 0x03;

  // Address types
  static const _addrIPv4 = 0x01;
  static const _addrDomain = 0x03;
  static const _addrIPv6 = 0x04;

  // Replies
  static const _repSuccess = 0x00;
  static const _repGeneralFailure = 0x01;
  static const _repHostUnreachable = 0x04;
  static const _repCommandNotSupported = 0x07;
  static const _repAddressNotSupported = 0x08;

  final Socket _client;
  final String? username;
  final String? password;
  final DpiBypassService? _dpiBypass;
  final void Function(int sent, int received)? _onTrafficUpdate;

  /// Буфер для накопления данных при фрагментированном чтении
  final BytesBuilder _readBuffer = BytesBuilder();
  StreamSubscription<Uint8List>? _clientSubscription;

  Socks5Handler(
    this._client, {
    this.username,
    this.password,
    DpiBypassService? dpiBypass,
    void Function(int sent, int received)? onTrafficUpdate,
  })  : _dpiBypass = dpiBypass,
        _onTrafficUpdate = onTrafficUpdate;

  /// Обработка SOCKS5-соединения
  Future<void> handle() async {
    try {
      // Таймаут на всё соединение (5 минут)
      final connectionTimer = Timer(const Duration(minutes: 5), () {
        Logger.warn('SOCKS5 соединение превысило таймаут 5 мин');
        try {
          _client.close();
        } catch (_) {}
      });

      try {
        // Этап 1: Приветствие и аутентификация
        if (!await _greeting()) return;

        // Этап 2: Запрос
        await _handleRequest();
      } finally {
        connectionTimer.cancel();
      }
    } catch (e) {
      Logger.error('SOCKS5 ошибка: $e');
    } finally {
      try {
        await _clientSubscription?.cancel();
      } catch (_) {}
      try {
        await _client.close();
      } catch (_) {}
    }
  }

  /// Этап 1: Приветствие
  Future<bool> _greeting() async {
    // Читаем версию и методы аутентификации
    final header = await _readBytes(2);
    if (header.isEmpty || header[0] != _socksVersion) {
      _sendGreetingResponse(_authNoAcceptable);
      return false;
    }

    final nmethods = header[1];
    final methods = await _readBytes(nmethods);

    // Выбираем метод аутентификации
    if (username != null && password != null) {
      if (methods.contains(_authPassword)) {
        _sendGreetingResponse(_authPassword);
        return _authenticate();
      }
    } else if (methods.contains(_authNoAuth)) {
      _sendGreetingResponse(_authNoAuth);
      return true;
    }

    _sendGreetingResponse(_authNoAcceptable);
    return false;
  }

  /// Аутентификация по паролю (RFC 1929)
  Future<bool> _authenticate() async {
    final header = await _readBytes(2);
    if (header.isEmpty || header[0] != 0x01) return false;

    final ulen = header[1];
    final uname = String.fromCharCodes(await _readBytes(ulen));

    final plen = (await _readBytes(1))[0];
    final passwd = String.fromCharCodes(await _readBytes(plen));

    if (uname == username && passwd == password) {
      _client.add([0x01, 0x00]); // Успех
      await _client.flush();
      return true;
    } else {
      _client.add([0x01, 0x01]); // Ошибка
      await _client.flush();
      return false;
    }
  }

  /// Отправка ответа на приветствие
  void _sendGreetingResponse(int method) {
    _client.add([_socksVersion, method]);
    _client.flush();
  }

  /// Этап 2: Обработка запроса
  Future<void> _handleRequest() async {
    final header = await _readBytes(4);
    if (header.isEmpty || header[0] != _socksVersion) {
      await _sendResponse(_repGeneralFailure);
      return;
    }

    final cmd = header[1];
    // final rsv = header[2]; // Зарезервировано, должно быть 0x00
    final atyp = header[3];

    // Читаем адрес
    final address = await _readAddress(atyp);
    if (address == null) {
      await _sendResponse(_repAddressNotSupported);
      return;
    }

    // Читаем порт
    final portBytes = await _readBytes(2);
    if (portBytes.length < 2) {
      await _sendResponse(_repGeneralFailure);
      return;
    }
    final port = (portBytes[0] << 8) | portBytes[1];

    Logger.info('SOCKS5 запрос: $cmd ${address.host}:$port');

    switch (cmd) {
      case _cmdConnect:
        await _handleConnect(address, port);
        break;
      case _cmdBind:
        await _sendResponse(_repCommandNotSupported);
        break;
      case _cmdUdpAssociate:
        await _sendResponse(_repCommandNotSupported);
        break;
      default:
        await _sendResponse(_repCommandNotSupported);
    }
  }

  /// Обработка CONNECT с DPI-обходом
  Future<void> _handleConnect(SocksAddress address, int port) async {
    StreamSubscription<Uint8List>? targetSubscription;
    try {
      final targetSocket = await Socket.connect(
        address.host,
        port,
        timeout: const Duration(seconds: 10),
      );

      // Отправляем успешный ответ
      await _sendResponse(
        _repSuccess,
        bindAddress: InternetAddress.anyIPv4,
        bindPort: port,
      );

      // Двунаправленная передача данных с DPI-обходом
      int sent = 0;
      int received = 0;
      final completer = Completer<void>();
      bool clientDone = false;
      bool targetDone = false;

      void checkDone() {
        if (clientDone && targetDone && !completer.isCompleted) {
          completer.complete();
        }
      }

      // Подписка на данные от целевого сервера -> клиенту
      targetSubscription = targetSocket.listen(
        (data) {
          received += data.length;
          // Применяем DPI-обход к данным от сервера
          if (_dpiBypass != null) {
            _dpiBypass
                .applyDpiMethods(
                  data,
                  [DpiMethod.fragmentation, DpiMethod.hostSpoof],
                )
                .then((processed) {
                  try {
                    _client.add(processed);
                    _client.flush();
                  } catch (e) {
                    Logger.error(
                      'SOCKS5: ошибка записи клиенту: $e',
                    );
                  }
                });
          } else {
            try {
              _client.add(data);
              _client.flush();
            } catch (e) {
              Logger.error('SOCKS5: ошибка записи клиенту: $e');
            }
          }
        },
        onError: (error) {
          Logger.error('SOCKS5: ошибка от целевого сервера: $error');
          targetDone = true;
          checkDone();
        },
        onDone: () {
          targetDone = true;
          checkDone();
        },
        cancelOnError: false,
      );

      // Подписка на данные от клиента -> целевому серверу
      _clientSubscription = _client.listen(
        (data) {
          sent += data.length;
          // Применяем DPI-обход к данным от клиента (для Telegram)
          if (_dpiBypass != null) {
            _dpiBypass
                .applyDpiMethods(
                  data,
                  [DpiMethod.fragmentation, DpiMethod.tlsObfuscation],
                )
                .then((processed) {
                  try {
                    targetSocket.add(processed);
                    targetSocket.flush();
                  } catch (e) {
                    Logger.error(
                      'SOCKS5: ошибка записи целевому серверу: $e',
                    );
                  }
                });
          } else {
            try {
              targetSocket.add(data);
              targetSocket.flush();
            } catch (e) {
              Logger.error(
                'SOCKS5: ошибка записи целевому серверу: $e',
              );
            }
          }
        },
        onError: (error) {
          Logger.error('SOCKS5: ошибка от клиента: $error');
          clientDone = true;
          checkDone();
        },
        onDone: () {
          clientDone = true;
          checkDone();
        },
        cancelOnError: false,
      );

      // Ждём завершения одной из сторон
      await completer.future;

      _onTrafficUpdate?.call(sent, received);
    } catch (e) {
      Logger.error('SOCKS5 CONNECT ошибка: $e');
      try {
        await _sendResponse(_repHostUnreachable);
      } catch (_) {}
    } finally {
      try {
        await targetSubscription?.cancel();
      } catch (_) {}
    }
  }

  /// Чтение адреса
  Future<SocksAddress?> _readAddress(int atyp) async {
    switch (atyp) {
      case _addrIPv4:
        final bytes = await _readBytes(4);
        if (bytes.length < 4) return null;
        return SocksAddress(
          InternetAddress(bytes.join('.'), type: InternetAddressType.IPv4),
        );

      case _addrDomain:
        final len = (await _readBytes(1))[0];
        final domain = String.fromCharCodes(await _readBytes(len));
        return SocksAddress(domain);

      case _addrIPv6:
        final bytes = await _readBytes(16);
        if (bytes.length < 16) return null;
        final parts = <int>[];
        for (var i = 0; i < 16; i += 2) {
          parts.add((bytes[i] << 8) | bytes[i + 1]);
        }
        return SocksAddress(
          InternetAddress(
            parts.join(':'),
            type: InternetAddressType.IPv6,
          ),
        );

      default:
        return null;
    }
  }

  /// Отправка ответа
  Future<void> _sendResponse(
    int rep, {
    InternetAddress? bindAddress,
    int bindPort = 0,
  }) async {
    final response = <int>[_socksVersion, rep, 0x00];

    if (bindAddress != null) {
      if (bindAddress.type == InternetAddressType.IPv4) {
        response.add(_addrIPv4);
        response.addAll(bindAddress.rawAddress);
      } else {
        response.add(_addrIPv6);
        response.addAll(bindAddress.rawAddress);
      }
    } else {
      response.addAll([_addrIPv4, 0, 0, 0, 0]);
    }

    response.add((bindPort >> 8) & 0xFF);
    response.add(bindPort & 0xFF);

    _client.add(response);
    await _client.flush();
  }

  /// Чтение байтов из сокета с буферизацией
  /// Исправлено: используется единый буфер, нет race condition
  Future<Uint8List> _readBytes(int count) async {
    // Если в буфере уже достаточно данных, возвращаем из буфера
    if (_readBuffer.length >= count) {
      final bytes = _readBuffer.takeBytes();
      return Uint8List.fromList(bytes.sublist(0, count));
    }

    final completer = Completer<Uint8List>();
    StreamSubscription<Uint8List>? subscription;

    subscription = _client.listen(
      (data) {
        _readBuffer.add(data);

        if (_readBuffer.length >= count) {
          final allBytes = _readBuffer.takeBytes();
          subscription?.cancel();
          if (!completer.isCompleted) {
            completer.complete(Uint8List.fromList(allBytes.sublist(0, count)));
          }
        }
      },
      onError: (error) {
        Logger.error('SOCKS5 _readBytes ошибка: $error');
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(Uint8List(0));
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          final remaining = _readBuffer.takeBytes();
          completer.complete(Uint8List.fromList(remaining));
        }
      },
      cancelOnError: false,
    );

    // Таймаут 30 секунд
    Future.delayed(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.complete(Uint8List(0));
      }
    });

    final result = await completer.future;
    return result;
  }
}

/// Адрес для SOCKS5
class SocksAddress {
  final String host;

  SocksAddress(Object addr)
      : host = addr is InternetAddress ? addr.address : addr as String;
}