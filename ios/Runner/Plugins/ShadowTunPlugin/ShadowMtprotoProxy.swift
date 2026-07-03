import Foundation
import Network

// MARK: - C FFI Bridge to Rust (libmtproto_proxy.a)

/// Запуск MTProto прокси сервера (Rust)
/// - Returns: 0 при успехе, -1 если уже запущен, -3 если bind не удался
private func rust_start_proxy(
    _ host: UnsafePointer<CChar>?,
    _ port: Int32,
    _ dcIps: UnsafePointer<CChar>?,
    _ secret: UnsafePointer<CChar>?,
    _ verbose: Int32
) -> Int32

/// Остановка прокси
private func rust_stop_proxy() -> Int32

/// Установка размера пула
private func rust_set_pool_size(_ size: Int32)

/// Настройка Cloudflare proxy
private func rust_set_cfproxy_config(
    _ enabled: Int32,
    _ priority: Int32,
    _ userDomain: UnsafePointer<CChar>?
)

/// Получение статистики
private func rust_get_stats() -> UnsafeMutablePointer<CChar>?

/// Получение secret с префиксом
private func rust_get_secret_with_prefix() -> UnsafeMutablePointer<CChar>?

/// Освобождение C-строки
private func rust_free_string(_ s: UnsafeMutablePointer<CChar>?)

/// Нативный MTProto прокси для iOS
///
/// Использует Rust-библиотеку (libmtproto_proxy.a) через C FFI.
/// Если Rust-библиотека не загружена, использует Swift fallback.
class ShadowMtprotoProxy {
    
    // MARK: - Properties
    
    private var useRust: Bool = false
    private var isRunning = false
    private var secret: String
    private var port: UInt16
    private var bindIp: String = "127.0.0.1"
    private var dcIps: String = ""
    private var poolSize: Int = 4
    private var cfEnabled: Bool = true
    private var cfDomain: String = ""
    
    /// Статистика трафика
    private(set) var bytesSent: UInt64 = 0
    private(set) var bytesReceived: UInt64 = 0
    
    /// Колбэк для обновления статистики
    var onTrafficUpdate: ((UInt64, UInt64) -> Void)?
    
    // MARK: - Init
    
    init(port: UInt16 = 1443, secret: String? = nil, dcIps: String = "") {
        self.port = port
        self.secret = secret ?? ShadowMtprotoProxy.generateSecret()
        self.dcIps = dcIps
        
        // Пробуем загрузить Rust-библиотеку
        self.useRust = Self.loadRustLibrary()
        if useRust {
            NSLog("ShadowMTProto: Using Rust native library")
        } else {
            NSLog("ShadowMTProto: Rust library not available, using Swift fallback")
        }
    }
    
    // MARK: - Rust Library Loading
    
    /// Попытка загрузить Rust-библиотеку через dlsym
    private static func loadRustLibrary() -> Bool {
        let handle = dlopen(nil, RTLD_LAZY)
        defer { dlclose(handle) }
        
        guard let handle = handle else { return false }
        
        let symbol = dlsym(handle, "StartProxy")
        return symbol != nil
    }
    
    // MARK: - Public Methods
    
    /// Запуск MTProto прокси
    func start() throws {
        guard !isRunning else { return }
        
        if useRust {
            startRust()
        } else {
            try startSwift()
        }
    }
    
    /// Остановка MTProto прокси
    func stop() {
        guard isRunning else { return }
        
        if useRust {
            stopRust()
        } else {
            stopSwift()
        }
    }
    
    /// Получение статуса
    var status: String {
        return isRunning ? "running" : "stopped"
    }
    
    /// Генерация случайного MTProto secret (32 hex-символа)
    static func generateSecret() -> String {
        let bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Генерация Fake TLS secret
    static func generateFakeTlsSecret() -> String {
        return "dd\(generateSecret())"
    }
    
    // MARK: - Rust Implementation
    
    private func startRust() {
        let hostPtr = (bindIp as NSString).utf8String
        let dcIpsPtr = (dcIps as NSString).utf8String
        let secretPtr = (secret as NSString).utf8String
        
        let result = rust_start_proxy(hostPtr, Int32(port), dcIpsPtr, secretPtr, 1)
        
        if result == 0 {
            isRunning = true
            NSLog("ShadowMTProto (Rust): Server started on \(bindIp):\(port)")
        } else {
            NSLog("ShadowMTProto (Rust): Failed to start, error code: \(result)")
        }
    }
    
    private func stopRust() {
        let _ = rust_stop_proxy()
        isRunning = false
        NSLog("ShadowMTProto (Rust): Server stopped")
    }
    
    // MARK: - Swift Fallback Implementation
    
    private var swiftListener: NWListener?
    
    private func startSwift() throws {
        let params = NWParameters.tcp
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
                NSLog("ShadowMTProto (Swift): Server started on port \(self?.port ?? 0)")
            case .failed(let error):
                NSLog("ShadowMTProto (Swift): Server failed: \(error.localizedDescription)")
            default:
                break
            }
        }
        
        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener.start(queue: .main)
        swiftListener = listener
    }
    
    private func stopSwift() {
        swiftListener?.cancel()
        swiftListener = nil
        isRunning = false
        NSLog("ShadowMTProto (Swift): Server stopped")
    }
    
    // MARK: - Connection Handling (Swift Fallback)
    
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveLoop(connection)
            case .failed(let error):
                NSLog("ShadowMTProto: Connection failed: \(error.localizedDescription)")
            default:
                break
            }
        }
        connection.start(queue: .main)
    }
    
    private func receiveLoop(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.bytesReceived += UInt64(data.count)
                self?.onTrafficUpdate?(self?.bytesSent ?? 0, self?.bytesReceived ?? 0)
                
                // Просто отвечаем 404 для HTTP запросов
                let response = "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n"
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            }
            
            if isComplete || error != nil {
                connection.cancel()
            } else {
                self?.receiveLoop(connection)
            }
        }
    }
}