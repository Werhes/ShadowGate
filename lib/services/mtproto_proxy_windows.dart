import 'dart:ffi';
import 'package:ffi/ffi.dart';

import '../utils/logger.dart';

/// Dart FFI binding для нативной Rust-библиотеки mtproto_proxy.dll
///
/// Использует C ABI (те же функции что и в mtproto_proxy.h):
/// - StartProxy, StopProxy, SetPoolSize, SetCfProxyConfig
/// - GetStats, GetSecretWithPrefix, FreeString
class MtprotoProxyWindows {
  static MtprotoProxyWindows? _instance;
  DynamicLibrary? _lib;
  bool _loaded = false;

  MtprotoProxyWindows._();

  static MtprotoProxyWindows get instance {
    _instance ??= MtprotoProxyWindows._();
    return _instance!;
  }

  bool get isLoaded => _loaded;

  /// Загрузка библиотеки mtproto_proxy.dll
  bool load() {
    if (_loaded) return true;

    try {
      final paths = [
        'mtproto_proxy.dll',
        'native\\mtproto_proxy\\target\\release\\mtproto_proxy.dll',
        'native\\mtproto_proxy\\target\\x86_64-pc-windows-msvc\\release\\mtproto_proxy.dll',
      ];

      for (final path in paths) {
        try {
          _lib = DynamicLibrary.open(path);
          _loaded = true;
          Logger.info('MtprotoProxyWindows: loaded from $path');
          return true;
        } catch (_) {
          continue;
        }
      }

      Logger.warn('MtprotoProxyWindows: library not found');
      return false;
    } catch (e) {
      Logger.error('MtprotoProxyWindows: load error: $e');
      return false;
    }
  }

  // ============================================================
  // C ABI function typedefs
  // ============================================================

  int _startProxy(
    Pointer<Utf8> host,
    int port,
    Pointer<Utf8> dcIps,
    Pointer<Utf8> secret,
    int verbose,
  ) {
    final func = _lib!.lookupFunction<
        Int32 Function(Pointer<Utf8>, Int32, Pointer<Utf8>, Pointer<Utf8>, Int32),
        int Function(Pointer<Utf8>, int, Pointer<Utf8>, Pointer<Utf8>, int)>('StartProxy');
    return func(host, port, dcIps, secret, verbose);
  }

  int _stopProxy() {
    final func = _lib!.lookupFunction<Int32 Function(), int Function()>('StopProxy');
    return func();
  }

  // ignore: unused_element
  void _setPoolSize(int size) {
    final func = _lib!.lookupFunction<Void Function(Int32), void Function(int)>('SetPoolSize');
    func(size);
  }

  // ignore: unused_element
  void _setCfProxyConfig(int enabled, int priority, Pointer<Utf8> userDomain) {
    final func = _lib!.lookupFunction<
        Void Function(Int32, Int32, Pointer<Utf8>),
        void Function(int, int, Pointer<Utf8>)>('SetCfProxyConfig');
    func(enabled, priority, userDomain);
  }

  Pointer<Utf8> _getStats() {
    final func = _lib!.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>('GetStats');
    return func();
  }

  Pointer<Utf8> _getSecretWithPrefix() {
    final func = _lib!.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
        'GetSecretWithPrefix');
    return func();
  }

  void _freeString(Pointer<Utf8> p) {
    final func = _lib!.lookupFunction<Void Function(Pointer<Utf8>), void Function(Pointer<Utf8>)>(
        'FreeString');
    func(p);
  }

  // ============================================================
  // High-level API
  // ============================================================

  /// Запуск прокси
  int startProxy({
    required String host,
    required int port,
    required String dcIps,
    required String secret,
    bool verbose = true,
  }) {
    if (!_loaded) return -99;

    final hostPtr = host.toNativeUtf8();
    final dcIpsPtr = dcIps.toNativeUtf8();
    final secretPtr = secret.toNativeUtf8();

    try {
      return _startProxy(hostPtr, port, dcIpsPtr, secretPtr, verbose ? 1 : 0);
    } finally {
      calloc.free(hostPtr);
      calloc.free(dcIpsPtr);
      calloc.free(secretPtr);
    }
  }

  /// Остановка прокси
  int stopProxy() {
    if (!_loaded) return -99;
    return _stopProxy();
  }

  /// Получение статистики
  String? getStats() {
    if (!_loaded) return null;
    final ptr = _getStats();
    if (ptr == nullptr) return null;
    final result = ptr.toDartString();
    _freeString(ptr);
    return result;
  }

  /// Получение secret с префиксом
  String? getSecretWithPrefix() {
    if (!_loaded) return null;
    final ptr = _getSecretWithPrefix();
    if (ptr == nullptr) return null;
    final result = ptr.toDartString();
    _freeString(ptr);
    return result;
  }
}