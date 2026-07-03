import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../core/platform_utils.dart';
import '../models/proxy_config.dart';
import '../utils/logger.dart';
import 'mtproto_proxy_windows.dart';

/// MTProto прокси-сервер (как в tg-ws-proxy-android от amurcanov)
///
/// Реализует Telegram MTProto протокол через WebSocket.
///
/// Платформенная поддержка:
/// - **Windows**: использует нативную Rust-библиотеку (mtproto_proxy.dll) через Dart FFI
/// - **Android**: использует нативный Rust через JNA (MtprotoService.kt)
/// - **iOS**: использует нативный Rust через C FFI (ShadowMtprotoProxy.swift)
/// - **macOS/Linux**: Dart-реализация (HttpServer + WebSocket)
class MtprotoProxyService {
  HttpServer? _server;
  bool _isRunning = false;
  Timer? _statsTimer;
  Timer? _heartbeatTimer;
  int _bytesSent = 0;
  int _bytesReceived = 0;
  String? _generatedSecret;
  final _random = Random.secure();

  /// Windows FFI binding
  final MtprotoProxyWindows _windowsProxy = MtprotoProxyWindows.instance;

  /// Активные WebSocket соединения для корректного закрытия
  final Set<WebSocket> _activeConnections = {};

  /// Колбэк для обновления статистики трафика
  void Function(int sent, int received)? onTrafficUpdate;

  /// Колбэк при генерации нового secret (для сохранения в конфиг)
  void Function(String secret)? onSecretGenerated;

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

  /// Генерация Fake TLS secret (с префиксом "dd")
  /// Такой secret заставляет Telegram маскировать трафик под HTTPS
  String _generateFakeTlsSecret() {
    return 'dd${_generateSecret()}';
  }

  /// Запуск MTProto прокси-сервера
  Future<void> start(ProxyConfig config) async {
    if (_isRunning) {
      Logger.warn('MTProto прокси уже запущен');
      return;
    }

    try {
      // Генерируем секрет, если его нет
      _generatedSecret = config.mtprotoSecret ?? _generateFakeTlsSecret();
      Logger.info(
        'Запуск MTProto прокси на ${config.host}:${config.port}',
      );
      Logger.info('MTProto secret: $_generatedSecret');

      // Если secret не был в конфиге, но сгенерировался — сохраняем
      if (config.mtprotoSecret == null && _generatedSecret != null) {
        onSecretGenerated?.call(_generatedSecret!);
      }

      // На Windows используем нативную Rust-библиотеку через Dart FFI
      if (PlatformUtils.isWindows) {
        await _startWindowsNative(config);
        return;
      }

      // На остальных платформах — Dart HttpServer + WebSocket
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

  /// Запуск нативного Rust MTProto прокси на Windows через Dart FFI
  Future<void> _startWindowsNative(ProxyConfig config) async {
    // Загружаем библиотеку
    if (!_windowsProxy.load()) {
      throw Exception(
        'Не удалось загрузить mtproto_proxy.dll. '
        'Убедитесь, что библиотека собрана (native/mtproto_proxy/build_windows.bat) '
        'и находится в директории с исполняемым файлом.',
      );
    }

    // Формируем строку DC IPs
    // DC 1-5 + 203 для Telegram MTProto
    const dcIps =
        '1:149.154.175.50,2:149.154.167.51,3:149.154.175.100,4:149.154.167.91,5:91.108.56.151,203:91.108.56.130';

    // Запускаем прокси
    final result = _windowsProxy.startProxy(
      host: config.host,
      port: config.port,
      dcIps: dcIps,
      secret: _generatedSecret ?? '',
      verbose: true,
    );

    if (result != 0) {
      throw Exception('Ошибка запуска нативного MTProto прокси: код $result');
    }

    _isRunning = true;
    Logger.info(
      'Нативный MTProto прокси (Windows) запущен на порту ${config.port}',
    );

    // Таймер для опроса статистики из Rust
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final stats = _windowsProxy.getStats();
      if (stats != null) {
        _parseAndUpdateStats(stats);
      }
    });
  }

  /// Парсинг статистики из Rust и обновление счётчиков
  void _parseAndUpdateStats(String stats) {
    try {
      // Формат: "tx=12345 rx=67890 conn=5"
      final txMatch = RegExp(r'tx=(\d+)').firstMatch(stats);
      final rxMatch = RegExp(r'rx=(\d+)').firstMatch(stats);

      if (txMatch != null) {
        _bytesSent = int.tryParse(txMatch.group(1) ?? '0') ?? 0;
      }
      if (rxMatch != null) {
        _bytesReceived = int.tryParse(rxMatch.group(1) ?? '0') ?? 0;
      }

      onTrafficUpdate?.call(_bytesSent, _bytesReceived);
    } catch (e) {
      Logger.error('Ошибка парсинга статистики MTProto: $e');
    }
  }

  /// Остановка MTProto прокси-сервера
  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      _heartbeatTimer?.cancel();
      _statsTimer?.cancel();

      // На Windows останавливаем через FFI
      if (PlatformUtils.isWindows) {
        _windowsProxy.stopProxy();
        _isRunning = false;
        _bytesSent = 0;
        _bytesReceived = 0;
        Logger.info('Нативный MTProto прокси (Windows) остановлен');
        return;
      }

      // На остальных платформах — закрываем WebSocket соединения
      for (final ws in _activeConnections) {
        try {
          await ws.close();
        } catch (_) {}
      }
      _activeConnections.clear();

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

    // HTTP запросы — отдаём статус-страницу
    if (method == 'GET') {
      await _sendStatusPage(request, config);
      return;
    }

    // Все остальные запросы — 404
    try {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } catch (_) {}
  }

  /// Обработка WebSocket соединения (как в tg-ws-proxy-android)
  ///
  /// Схема работы:
  /// 1. Клиент (Telegram) подключается к нашему HTTP-серверу через WebSocket
  /// 2. Мы апгрейдим соединение до WebSocket
  /// 3. Подключаемся к Telegram через WSS с secret в query
  /// 4. Проксируем данные в обе стороны
  /// 5. Heartbeat каждые 30 секунд для предотвращения разрыва
  Future<void> _handleWebSocket(
    HttpRequest request,
    ProxyConfig config,
  ) async {
    WebSocket? ws;
    WebSocket? tgWs;
    Timer? heartbeat;

    try {
      ws = await WebSocketTransformer.upgrade(request);
      _activeConnections.add(ws);
      Logger.info('WebSocket соединение установлено');

      // Формируем URL с secret для подключения к Telegram
      final baseWsUrl = config.webSocketUrl ??
          'wss://pluto.web.telegram.org/apiws';
      final tgUri = _buildTelegramWsUrl(baseWsUrl, _generatedSecret);

      // Подключаемся к Telegram с правильными заголовками
      tgWs = await WebSocket.connect(
        tgUri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; ShadowGate/1.0)',
          'Origin': 'https://telegram.org',
        },
      );
      _activeConnections.add(tgWs);
      Logger.info('WebSocket к Telegram установлен');

      // Heartbeat: ping/pong каждые 30 секунд
      // Предотвращает разрыв соединения из-за неактивности
      heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
        try {
          tgWs?.add([0x09, 0x00]); // Ping frame
        } catch (_) {}
      });

      // Двунаправленная передача данных
      final completer = Completer<void>();
      bool clientDone = false;
      bool serverDone = false;

      void checkDone() {
        if (clientDone && serverDone && !completer.isCompleted) {
          completer.complete();
        }
      }

      // Данные от клиента (Telegram) -> в Telegram через WSS
      ws.listen(
        (data) {
          final len =
              data is List<int> ? data.length : data.toString().length;
          _bytesSent += len;
          try {
            tgWs?.add(data);
          } catch (e) {
            Logger.error('MTProto WS: ошибка записи в Telegram: $e');
          }
        },
        onError: (error) {
          Logger.error('MTProto WS: ошибка от клиента: $error');
          clientDone = true;
          checkDone();
        },
        onDone: () {
          clientDone = true;
          checkDone();
        },
        cancelOnError: false,
      );

      // Данные от Telegram -> клиенту
      tgWs.listen(
        (data) {
          final len =
              data is List<int> ? data.length : data.toString().length;
          _bytesReceived += len;
          try {
            ws?.add(data);
          } catch (e) {
            Logger.error('MTProto WS: ошибка записи клиенту: $e');
          }
        },
        onError: (error) {
          Logger.error('MTProto WS: ошибка от Telegram: $error');
          serverDone = true;
          checkDone();
        },
        onDone: () {
          serverDone = true;
          checkDone();
        },
        cancelOnError: false,
      );

      await completer.future;
    } catch (e) {
      Logger.error('Ошибка WebSocket MTProto: $e');
      try {
        if (ws == null) {
          request.response.statusCode = HttpStatus.badGateway;
          await request.response.close();
        }
      } catch (_) {}
    } finally {
      heartbeat?.cancel();
      if (ws != null) _activeConnections.remove(ws);
      if (tgWs != null) _activeConnections.remove(tgWs);
    }
  }

  /// Формирование WebSocket URL для Telegram с secret
  /// Как в tg-ws-proxy-android: secret передаётся как query параметр
  String _buildTelegramWsUrl(String baseUrl, String? secret) {
    if (secret == null) return baseUrl;

    final uri = Uri.parse(baseUrl);
    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['secret'] = secret;

    return uri.replace(queryParameters: queryParams).toString();
  }

  /// Отправка статусной страницы с секретом
  /// Как в tg-ws-proxy-android: отдаёт HTML с tg:// ссылкой
  Future<void> _sendStatusPage(
    HttpRequest request,
    ProxyConfig config,
  ) async {
    final secret = _generatedSecret ?? 'не сгенерирован';
    final isFakeTls = secret.startsWith('dd');
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
    .badge {
      display: inline-block;
      background: ${isFakeTls ? 'linear-gradient(135deg, #FF6B6B, #FFA500)' : 'linear-gradient(135deg, #6C63FF, #00D9FF)'};
      color: #fff;
      padding: 4px 12px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: bold;
      margin-top: 8px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div><span class="status"></span> MTProto Proxy</div>
    <h1>ShadowGate</h1>
    <p class="info">MTProto прокси-сервер запущен</p>
    <div class="badge">${isFakeTls ? '🔒 Fake TLS (рекомендуется)' : 'Обычный'}</div>
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