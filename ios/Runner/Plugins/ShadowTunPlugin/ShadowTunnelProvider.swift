import NetworkExtension
import Foundation

/// NEPacketTunnelProvider для ShadowGate VPN
///
/// Этот провайдер обрабатывает все VPN-пакеты на iOS:
/// - Создаёт виртуальный TUN-интерфейс
/// - Маршрутизирует трафик через прокси
/// - Применяет DPI-обход (передаётся из Dart)
///
/// Для работы требуется:
/// - Capability: Network Extension (Packet Tunnel)
/// - Entitlement: com.apple.developer.networking.vpn.api.allow
class ShadowTunnelProvider: NEPacketTunnelProvider {
    
    private var tunnelInterface: NEPacketTunnelFlow?
    private var isRunning = false
    
    // MARK: - Tunnel Lifecycle
    
    /// Вызывается системой при запуске VPN
    override func startTunnel(options: [String : NSObject]? = nil) throws {
        NSLog("ShadowTunnel: startTunnel called")
        
        guard let proto = protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfig = proto.providerConfiguration else {
            throw NSError(domain: "ShadowTunnel", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Missing provider configuration"])
        }
        
        // Настройка виртуального интерфейса
        let tunConfig = createTunnelNetworkSettings(from: providerConfig)
        
        // Устанавливаем туннель
        setTunnelNetworkSettings(tunConfig) { [weak self] error in
            if let error = error {
                NSLog("ShadowTunnel: Failed to set tunnel network settings: \(error.localizedDescription)")
                self?.cancelTunnelWithError(error)
                return
            }
            
            NSLog("ShadowTunnel: Tunnel network settings applied successfully")
            self?.isRunning = true
            
            // Начинаем обработку пакетов
            self?.startPacketProcessing()
        }
    }
    
    /// Вызывается системой при остановке VPN
    override func stopTunnel(with reason: NEProviderStopReason) {
        NSLog("ShadowTunnel: stopTunnel called, reason: \(reason.rawValue)")
        isRunning = false
    }
    
    /// Вызывается при изменении настроек
    override func handleAppMessage(_ messageData: Data) {
        // Получаем команды от основного приложения через IPC
        guard let message = String(data: messageData, encoding: .utf8) else { return }
        NSLog("ShadowTunnel: received message: \(message)")
        
        // Отвечаем статусом
        let response = "{\"status\": \"\(isRunning ? "running" : "stopped")\"}"
        if let responseData = response.data(using: .utf8) {
            self.sendProviderMessage(responseData) { _ in }
        }
    }
    
    // MARK: - Configuration
    
    /// Создание настроек туннеля из конфигурации Dart
    private func createTunnelNetworkSettings(from config: [String: Any]) -> NEPacketTunnelNetworkSettings {
        let tunConfig = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.8.0.1")
        
        // MTU — для iOS оптимально 1280 (минимальный для сотовых сетей)
        let mtu = config["mtu"] as? Int ?? 1280
        tunConfig.mtu = NSNumber(value: mtu)
        
        // IPv4 настройки
        let ipv4Address = config["ipv4Address"] as? String ?? "10.8.0.2"
        let ipv4SubnetMask = config["ipv4SubnetMask"] as? String ?? "255.255.255.0"
        
        let ipv4Settings = NEIPv4Settings(
            addresses: [ipv4Address],
            subnetMasks: [ipv4SubnetMask]
        )
        
        // Маршрутизация всего трафика через VPN
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        
        // Обход локального трафика если нужно
        let bypassLocal = config["bypassLocalTraffic"] as? Bool ?? true
        if bypassLocal {
            ipv4Settings.excludedRoutes = [
                NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
                NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
                NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
                NEIPv4Route(destinationAddress: "127.0.0.0", subnetMask: "255.0.0.0"),
            ]
        }
        
        tunConfig.ipv4Settings = ipv4Settings
        
        // IPv6 настройки
        let ipv6Address = config["ipv6Address"] as? String ?? "fd00:1:2:3::2"
        let ipv6PrefixLength = config["ipv6PrefixLength"] as? Int ?? 64
        
        let ipv6Settings = NEIPv6Settings(
            addresses: [ipv6Address],
            networkPrefixLengths: [NSNumber(value: ipv6PrefixLength)]
        )
        ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        
        tunConfig.ipv6Settings = ipv6Settings
        
        // DNS настройки
        let dnsServer = config["dns"] as? String ?? "8.8.8.8"
        let dnsSettings = NEDNSSettings(servers: [dnsServer])
        tunConfig.dnsSettings = dnsSettings
        
        // Прокси-настройки (если указаны)
        if let proxyPort = config["proxyServerPort"] as? Int, proxyPort > 0,
           let proxyAddress = config["proxyServerAddress"] as? String, !proxyAddress.isEmpty {
            let proxySettings = NEProxySettings()
            proxySettings.httpServer = NEProxyServer(address: proxyAddress, port: proxyPort)
            proxySettings.httpsServer = NEProxyServer(address: proxyAddress, port: proxyPort)
            proxySettings.autoProxyConfigurationEnabled = false
            tunConfig.proxySettings = proxySettings
        }
        
        return tunConfig
    }
    
    // MARK: - Packet Processing
    
    /// Запуск обработки пакетов из TUN-интерфейса
    private func startPacketProcessing() {
        guard isRunning else { return }
        
        // Читаем пакеты из TUN
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self, self.isRunning else { return }
            
            var processedPackets: [Data] = []
            var processedProtocols: [NSNumber] = []
            
            for (index, packet) in packets.enumerated() {
                let proto = protocols[index]
                
                // Применяем DPI-обход к пакету
                let processed = self.processPacket(packet, protocolType: proto.intValue)
                processedPackets.append(processed)
                processedProtocols.append(proto)
            }
            
            // Отправляем обработанные пакеты обратно в TUN
            if !processedPackets.isEmpty {
                self.packetFlow.writePackets(processedPackets, withProtocols: processedProtocols)
            }
            
            // Продолжаем чтение
            self.startPacketProcessing()
        }
    }
    
    /// Обработка одного пакета
    /// В реальном приложении здесь применяются методы DPI-обхода
    private func processPacket(_ packet: Data, protocolType: Int) -> Data {
        // TODO: В реальном приложении здесь нужно применять DPI-методы,
        // переданные из Dart-конфигурации
        // Пока просто возвращаем пакет как есть
        return packet
    }
}