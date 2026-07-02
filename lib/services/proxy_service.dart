import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/types.dart';
import '../models/proxy_config.dart';
import '../utils/logger.dart';
import 'dpi_bypass_service.dart';
import 'socks5_handler.dart';

/// Сервис для управления прокси-сервером
/// С поддержкой DPI-обхода (zapret-style)
class ProxyService {
  HttpServer? _httpServer;
  ServerSocket? _socksServer;
  bool _isRunning = false;
  final DpiBypassService _dpiBypass = DpiBypassService();
  Timer? _statsTimer;
  int _bytesSent = 0;
  int _bytesReceived = 0;

  /// Колбэк для обновления статистики трафика
  void Function(int sent, int received)? onTrafficUpdate;

  bool get isRunning => _isRunning;
  int get bytesSent => _bytesSent;
  int get bytesReceived => _bytesReceived;

  /// Запуск прокси-сервера
  Future<void> start(ProxyConfig config) async {
    if (_isRunning) {
      Logger.warn('Прокси-сервер уже запущен');
      return;
    }

    try {
      Logger.info(
        'Запуск ${config.type.label} прокси на ${config.host}:${config.port}',
      );

      if (config.type == ProxyType.http) {
        await _startHttpServer(config);
      } else {
        await _startSocksServer(config);
      }

      _isRunning = true;
      Logger.info('Прокси-сервер запущен на порту ${config.port}');

      // Таймер для обновления статистики
      _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        onTrafficUpdate?.call(_bytesSent, _bytesReceived);
      });
    } catch (e) {
      Logger.error('Ошибка запуска прокси: $e');
      rethrow;
    }
  }

  /// Запуск HTTP прокси-сервера
  Future<void> _startHttpServer(ProxyConfig config) async {
    _httpServer = await HttpServer.bind(
      InternetAddress.anyIPv4,
      config.port,
    );

    _httpServer!.listen(
      (HttpRequest request) {
        _handleHttpRequest(request, config).catchError((error) {
          Logger.error('Ошибка обработки HTTP запроса: $error');
        });
      },
      onError: (error) {
        Logger.error('Ошибка HTTP сервера: $error');
      },
    );
  }

  /// Запуск SOCKS5 сервера
  Future<void> _startSocksServer(ProxyConfig config) async {
    _socksServer = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      config.port,
    );

    _socksServer!.listen(
      (Socket client) {
        final handler = Socks5Handler(
          client,
          username: config.username,
          password: config.password,
          dpiBypass: _dpiBypass,
          onTrafficUpdate: (sent, received) {
            _bytesSent += sent;
            _bytesReceived += received;
          },
        );
        handler.handle().catchError((error) {
          Logger.error('Ошибка SOCKS5 обработки: $error');
        });
      },
      onError: (error) {
        Logger.error('Ошибка SOCKS5 сервера: $error');
      },
    );
  }

  /// Остановка прокси-сервера
  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      _statsTimer?.cancel();
      await _httpServer?.close(force: true);
      _httpServer = null;
      await _socksServer?.close();
      _socksServer = null;
      _isRunning = false;
      _bytesSent = 0;
      _bytesReceived = 0;
      Logger.info('Прокси-сервер остановлен');
    } catch (e) {
      Logger.error('Ошибка остановки прокси: $e');
      rethrow;
    }
  }

  /// Обработка HTTP-запроса
  Future<void> _handleHttpRequest(
    HttpRequest request,
    ProxyConfig config,
  ) async {
    final method = request.method.toUpperCase();

    if (method == 'CONNECT') {
      await _handleConnect(request, config);
    } else {
      await _handleHttpProxy(request, config);
    }
  }

  /// Обработка CONNECT (HTTPS туннелирование) с DPI-обходом
  Future<void> _handleConnect(
    HttpRequest request,
    ProxyConfig config,
  ) async {
    final uri = request.uri.toString();
    final parts = uri.split(':');
    final host = parts[0];
    final port = parts.length > 1 ? int.parse(parts[1]) : 443;

    try {
      final targetSocket = await Socket.connect(host, port);
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.set('connection', 'keep-alive');
      await request.response.flush();

      final requestSocket = await request.response.detachSocket(
        writeHeaders: false,
      );

      // Двунаправленная передача данных с DPI-обходом
      final dpiMethods = config.type == ProxyType.http
          ? [DpiMethod.httpSplit, DpiMethod.hostSpoof]
          : <DpiMethod>[];

      await Future.wait([
        targetSocket.forEach((data) {
          _bytesReceived += data.length;
          // Применяем DPI-обход к данным от сервера
          if (dpiMethods.isNotEmpty) {
            _dpiBypass.applyDpiMethods(data, dpiMethods).then((processed) {
              requestSocket.add(processed);
            });
          } else {
            requestSocket.add(data);
          }
        }).catchError((_) {}),
        requestSocket.forEach((data) {
          _bytesSent += data.length;
          targetSocket.add(data);
        }).catchError((_) {}),
      ]);
    } catch (e) {
      Logger.error('Ошибка CONNECT к $host:$port: $e');
      try {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Обработка HTTP прокси-запроса с DPI-обходом
  Future<void> _handleHttpProxy(
    HttpRequest request,
    ProxyConfig config,
  ) async {
    final uri = request.uri;
    if (!uri.hasAuthority) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    try {
      final client = HttpClient();
      final proxyRequest = await client.getUrl(uri);
      proxyRequest.headers.set('Host', uri.host);

      // Копируем заголовки
      request.headers.forEach((name, values) {
        if (name.toLowerCase() != 'host') {
          proxyRequest.headers.set(name, values);
        }
      });

      // Копируем тело запроса
      if (request.contentLength > 0) {
        final body =
            await request.cast<List<int>>().transform(utf8.decoder).join();
        proxyRequest.write(body);
      }

      final proxyResponse = await proxyRequest.close();

      // Копируем ответ
      request.response.statusCode = proxyResponse.statusCode;
      proxyResponse.headers.forEach((name, values) {
        request.response.headers.set(name, values);
      });

      // Копируем тело ответа
      final responseBody =
          await proxyResponse.cast<List<int>>().transform(utf8.decoder).join();
      request.response.write(responseBody);
      await request.response.close();

      _bytesSent += request.contentLength;
      _bytesReceived += proxyResponse.contentLength;
    } catch (e) {
      Logger.error('Ошибка HTTP прокси: $e');
      try {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      } catch (_) {}
    }
  }
}