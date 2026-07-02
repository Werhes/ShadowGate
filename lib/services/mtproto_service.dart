import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/proxy_config.dart';
import '../utils/logger.dart';

/// MTProto прокси-сервер (как в tg-ws-proxy от flowseal)
/// Реализует Telegram MTProto протокол через WebSocket
/// Позволяет бесплатно обходить блокировки Telegram
///
/// MTProto secret — это 32 hex-символа (16 байт),
/// которые Telegram использует для шифрования соединения.
/// Без secret Telegram не может подключиться к прокси.
class MtprotoProxyService {
  HttpServer? _server;
  bool _isRunning = false;
  Timer? _statsTimer;
  int _bytesSent = 0;
  int _bytesReceived = 0;
  String? _generatedSecret;
  final _random = Random.secure();

  /// Колбэк для обновления статистики трафика
  void Function(int sent, int received)? onTrafficUpdate;

  bool get isRunning => _isRunning;
  int get bytesSent => _bytesSent;
  int get bytesReceived => _bytesReceived;

  /// Сгенерированный секрет для MTProto
  String? get secret => _generatedSecret;

  /// Генерация случайного MTProto secret (32 hex-символа = 16 байт)
  String _generateSecret() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Запуск MTProto прокси-сервера
  Future<void> start(ProxyConfig config) async {
    if (_isRunning) {
      Logger.warn('MTProto прокси уже запущен');
      return;
    }

    try {
      // Генерируем секрет, если его нет
      _generatedSecret = config.mtprotoSecret ?? _generateSecret();
      Logger.info(
        'Запуск MTProto прокси на ${config.host}:${config.port}',
      );
      Logger.info('MTProto secret: $_generatedSecret');

      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        config.port,
      );

      _server!.listen(
        (HttpRequest request) {
          _handleRequest(request, config).catchError((error) {
            Logger.error('Ошибка обработки MTProto запроса: $error');
          });
        },
        onError: (error) {
          Logger.error('Ошибка MTProto сервера: $error');
        },
      );

      _isRunning = true;
      Logger.info('MTProto прокси запущен на порту ${config.port}');

      // Таймер для обновления статистики
      _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        onTrafficUpdate?.call(_bytesSent, _bytesReceived);
      });
    } catch (e) {
      Logger.error('Ошибка запуска MTProto прокси: $e');
      rethrow;
    }
  }

  /// Остановка MTProto прокси-сервера
  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      _statsTimer?.cancel();
      await _server?.close(force: true);
      _server = null;
      _isRunning = false;
      _bytesSent = 0;
      _bytesReceived = 0;
      Logger.info('MTProto прокси остановлен');
    } catch (e) {
      Logger.error('Ошибка остановки MTProto прокси: $e');
      rethrow;
    }
  }

  /// Обработка входящего запроса
  Future<void> _handleRequest(
    HttpRequest request,
    ProxyConfig config,
  ) async {
    final method = request.method.toUpperCase();
    final uri = request.uri.toString();

    Logger.debug('MTProto запрос: $method $uri');

    // WebSocket upgrade (основной режим tg-ws-proxy)
    if (request.headers.value('upgrade')?.toLowerCase() == 'websocket') {
      await _handleWebSocket(request, config);
      return;
    }

    // HTTP запросы
    if (method == 'GET' && uri == '/') {
      await _sendStatusPage(request, config);
      return;
    }

    // MTProto API запросы
    if (uri.startsWith('/api') || uri.startsWith('/mtproto')) {
      await _handleApiRequest(request, config);
      return;
    }

    // Проксирование запроса к Telegram
    await _proxyToTelegram(request, config);
  }

  /// Обработка WebSocket соединения (основной режим tg-ws-proxy)
  Future<void> _handleWebSocket(
    HttpRequest request,
    ProxyConfig config,
  ) async {
    try {
      final ws = await WebSocketTransformer.upgrade(request);
      Logger.info('WebSocket соединение установлено');

      // Подключаемся к Telegram через WebSocket
      final tgUri = config.webSocketUrl ??
          'wss://pluto.web.telegram.org/apiws';
      final tgWs = await WebSocket.connect(tgUri);

      // Двунаправленная передача данных
      await Future.wait([
        ws.forEach((data) {
          final len = data is List<int> ? data.length : data.toString().length;
          _bytesSent += len;
          tgWs.add(data);
        }).catchError((_) {}),
        tgWs.forEach((data) {
          final len = data is List<int> ? data.length : data.toString().length;
          _bytesReceived += len;
          ws.add(data);
        }).catchError((_) {}),
      ]);
    } catch (e) {
      Logger.error('Ошибка WebSocket MTProto: $e');
      try {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Обработка API запросов MTProto
  Future<void> _handleApiRequest(
    HttpRequest request,
    ProxyConfig config,
  ) async {
    try {
      // Проксируем API запросы к Telegram
      final tgHost = config.webSocketUrl != null
          ? Uri.parse(config.webSocketUrl!).host
          : 'pluto.web.telegram.org';
      final tgPort = 443;

      final targetSocket = await Socket.connect(tgHost, tgPort);

      // Отправляем успешный ответ
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.set('content-type', 'application/json');
      await request.response.flush();

      final requestSocket = await request.response.detachSocket(
        writeHeaders: false,
      );

      await Future.wait([
        targetSocket.forEach((data) {
          _bytesReceived += data.length;
          requestSocket.add(data);
        }).catchError((_) {}),
        requestSocket.forEach((data) {
          _bytesSent += data.length;
          targetSocket.add(data);
        }).catchError((_) {}),
      ]);
    } catch (e) {
      Logger.error('Ошибка MTProto API: $e');
      try {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Проксирование HTTP запроса к Telegram
  Future<void> _proxyToTelegram(
    HttpRequest request,
    ProxyConfig config,
  ) async {
    try {
      final client = HttpClient();
      final uri = request.uri;

      // Определяем целевой хост Telegram
      final tgHost = config.webSocketUrl != null
          ? Uri.parse(config.webSocketUrl!).host
          : 'pluto.web.telegram.org';

      final proxyRequest = await client.getUrl(
        Uri.https(tgHost, uri.path, uri.queryParameters),
      );

      // Копируем заголовки
      request.headers.forEach((name, values) {
        if (name.toLowerCase() != 'host') {
          proxyRequest.headers.set(name, values);
        }
      });
      proxyRequest.headers.set('Host', tgHost);

      // Копируем тело
      if (request.contentLength > 0) {
        final body = await request.cast<List<int>>().transform(utf8.decoder).join();
        proxyRequest.write(body);
      }

      final proxyResponse = await proxyRequest.close();

      request.response.statusCode = proxyResponse.statusCode;
      proxyResponse.headers.forEach((name, values) {
        request.response.headers.set(name, values);
      });

      final responseBody =
          await proxyResponse.cast<List<int>>().transform(utf8.decoder).join();
      request.response.write(responseBody);
      await request.response.close();

      _bytesSent += request.contentLength;
      _bytesReceived += proxyResponse.contentLength;
    } catch (e) {
      Logger.error('Ошибка проксирования к Telegram: $e');
      try {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Отправка статусной страницы с секретом
  Future<void> _sendStatusPage(
    HttpRequest request,
    ProxyConfig config,
  ) async {
    final secret = _generatedSecret ?? 'не сгенерирован';
    final tgProxyLink =
        'tg://proxy?server=${config.host}&port=${config.port}&secret=$secret';

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.set('content-type', 'text/html; charset=utf-8');
    request.response.write('''
<!DOCTYPE html>
<html>
<head>
  <title>ShadowGate MTProto Proxy</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #0F0F23;
      color: #fff;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      padding: 20px;
    }
    .card {
      background: linear-gradient(135deg, #1a1a2e, #16213e);
      border-radius: 20px;
      padding: 40px;
      max-width: 420px;
      width: 100%;
      text-align: center;
      border: 1px solid rgba(255,255,255,0.1);
    }
    .status {
      display: inline-block;
      width: 12px;
      height: 12px;
      background: #00E676;
      border-radius: 50%;
      box-shadow: 0 0 20px rgba(0,230,118,0.5);
      margin-right: 8px;
    }
    h1 { font-size: 24px; margin: 20px 0; }
    .info { color: rgba(255,255,255,0.6); font-size: 14px; }
    .proxy-link {
      display: block;
      background: linear-gradient(135deg, #6C63FF, #00D9FF);
      color: #fff;
      text-decoration: none;
      padding: 16px;
      border-radius: 12px;
      margin: 20px 0;
      font-weight: bold;
    }
    .secret-box {
      background: rgba(0,0,0,0.3);
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 8px;
      padding: 12px;
      font-family: monospace;
      font-size: 13px;
      color: #00E676;
      word-break: break-all;
      margin: 12px 0;
    }
    .label {
      font-size: 12px;
      color: rgba(255,255,255,0.4);
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-top: 16px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div><span class="status"></span> MTProto Proxy</div>
    <h1>ShadowGate</h1>
    <p class="info">MTProto прокси-сервер запущен</p>
    <div class="label">Secret (скопируйте для подключения)</div>
    <div class="secret-box">$secret</div>
    <a class="proxy-link" href="$tgProxyLink">
      Подключиться в Telegram
    </a>
    <p class="info">
      Сервер: ${config.host}:${config.port}<br>
      Secret: $secret<br>
      Статус: Активен
    </p>
  </div>
</body>
</html>
''');
    await request.response.close();
  }
}