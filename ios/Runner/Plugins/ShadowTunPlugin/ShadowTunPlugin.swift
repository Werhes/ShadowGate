import Flutter
import UIKit
import NetworkExtension

/// Flutter плагин для управления TUN-интерфейсом и MTProto прокси на iOS
///
/// Обрабатывает MethodChannel вызовы из Dart-стороны:
/// - TUN: startTun, stopTun, getTunStatus, requestVpnPermission
/// - MTProto: startMtproto, stopMtproto, getMtprotoStatus, generateSecret
///
/// Этот плагин регистрируется в AppDelegate
public class ShadowTunPlugin: NSObject, FlutterPlugin {
    
    // MARK: - TUN Properties
    
    private var packetTunnelManager: NETunnelProviderManager?
    private var isTunRunning = false
    private var trafficStats: [String: UInt64] = ["bytesSent": 0, "bytesReceived": 0]
    
    // MARK: - MTProto Properties
    
    private var mtprotoProxy: ShadowMtprotoProxy?
    
    // MARK: - FlutterPlugin Registration
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.example.shadowgate/service",
            binaryMessenger: registrar.messenger()
        )
        let instance = ShadowTunPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    // MARK: - Method Channel Handler
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // TUN methods
        case "startTun":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing config", details: nil))
                return
            }
            startTun(config: args, result: result)
            
        case "stopTun":
            stopTun(result: result)
            
        case "getTunStatus":
            result(getTunStatus())
            
        case "requestVpnPermission":
            requestVpnPermission(result: result)
            
        case "getTrafficStats":
            result(getTrafficStats())
            
        // MTProto methods
        case "startMtproto":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing config", details: nil))
                return
            }
            startMtproto(config: args, result: result)
            
        case "stopMtproto":
            stopMtproto(result: result)
            
        case "getMtprotoStatus":
            result(getMtprotoStatus())
            
        case "generateSecret":
            let useFakeTls = (call.arguments as? [String: Any])?["useFakeTls"] as? Bool ?? true
            result(generateMtprotoSecret(useFakeTls: useFakeTls))
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - TUN Methods
    
    /// Запуск TUN через NEPacketTunnelProvider
    private func startTun(config: [String: Any], result: @escaping FlutterResult) {
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "ShadowGate VPN"
        
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "\(Bundle.main.bundleIdentifier ?? "com.example.shadowgate").ShadowTunnel"
        proto.serverAddress = "127.0.0.1"
        proto.providerConfiguration = config
        
        manager.protocolConfiguration = proto
        manager.isEnabled = true
        
        manager.saveToPreferences { [weak self] error in
            if let error = error {
                result(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: nil))
                return
            }
            
            manager.loadFromPreferences { loadError in
                if let loadError = loadError {
                    result(FlutterError(code: "LOAD_ERROR", message: loadError.localizedDescription, details: nil))
                    return
                }
                
                do {
                    try manager.connection.startVPNTunnel(options: [
                        NEVPNConnectionStartOptionUsername: "shadowgate" as NSString
                    ])
                    self?.packetTunnelManager = manager
                    self?.isTunRunning = true
                    result(true)
                } catch {
                    result(FlutterError(code: "START_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    /// Остановка TUN
    private func stopTun(result: @escaping FlutterResult) {
        guard let manager = packetTunnelManager else {
            result(false)
            return
        }
        
        manager.connection.stopVPNTunnel()
        isTunRunning = false
        packetTunnelManager = nil
        result(true)
    }
    
    /// Получение статуса TUN
    private func getTunStatus() -> Bool {
        return isTunRunning
    }
    
    /// Запрос VPN-разрешения
    private func requestVpnPermission(result: @escaping FlutterResult) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                result(FlutterError(code: "PERMISSION_ERROR", message: error.localizedDescription, details: nil))
                return
            }
            result(managers != nil)
        }
    }
    
    /// Получение статистики трафика
    private func getTrafficStats() -> [String: UInt64] {
        return trafficStats
    }
    
    // MARK: - MTProto Methods
    
    /// Запуск MTProto прокси
    private func startMtproto(config: [String: Any], result: @escaping FlutterResult) {
        let port = config["port"] as? Int ?? 443
        let secret = config["secret"] as? String
        let wsUrl = config["webSocketUrl"] as? String ?? "wss://pluto.web.telegram.org/apiws"
        let useFakeTls = config["useFakeTls"] as? Bool ?? true
        
        // Генерируем secret если не передан
        let finalSecret = secret ?? (useFakeTls ? ShadowMtprotoProxy.generateFakeTlsSecret() : ShadowMtprotoProxy.generateSecret())
        
        let proxy = ShadowMtprotoProxy(
            port: UInt16(port),
            secret: finalSecret,
            telegramWsUrl: wsUrl
        )
        
        do {
            try proxy.start()
            self.mtprotoProxy = proxy
            result(finalSecret) // Возвращаем secret в Dart
        } catch {
            result(FlutterError(code: "MTPROTO_START_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    /// Остановка MTProto прокси
    private func stopMtproto(result: @escaping FlutterResult) {
        mtprotoProxy?.stop()
        mtprotoProxy = nil
        result(true)
    }
    
    /// Получение статуса MTProto
    private func getMtprotoStatus() -> [String: Any] {
        return [
            "isRunning": mtprotoProxy?.status == "running",
            "secret": mtprotoProxy?.secret ?? "",
            "bytesSent": mtprotoProxy?.bytesSent ?? 0,
            "bytesReceived": mtprotoProxy?.bytesReceived ?? 0,
        ]
    }
    
    /// Генерация MTProto secret
    private func generateMtprotoSecret(useFakeTls: Bool) -> String {
        return useFakeTls ? ShadowMtprotoProxy.generateFakeTlsSecret() : ShadowMtprotoProxy.generateSecret()
    }
}