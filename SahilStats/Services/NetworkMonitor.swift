//
//  WifiNetworkMonitor.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/3/25.
//
// File: SahilStats/Services/NetworkMonitor.swift
// Monitors network connectivity and WiFi status

import Foundation
import Network
import Combine

class WifiNetworkMonitor: ObservableObject {
    static let shared = WifiNetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var isWiFi = false
    @Published var connectionType: ConnectionType = .none
    
    private var previousWiFiState = false
    
    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case none
        
        var displayName: String {
            switch self {
            case .wifi: return "WiFi"
            case .cellular: return "Cellular"
            case .wired: return "Wired"
            case .none: return "No Connection"
            }
        }
    }
    
    // Callback for when WiFi becomes available
    var onWiFiConnected: (() -> Void)?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
                
                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                    self.isWiFi = true
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                    self.isWiFi = false
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .wired
                    self.isWiFi = false
                } else {
                    self.connectionType = .none
                    self.isWiFi = false
                }
                
                // Trigger callback when WiFi becomes available
                if self.isWiFi && !self.previousWiFiState {
                    print("✅ WiFi connection detected!")
                    self.onWiFiConnected?()
                }
                
                self.previousWiFiState = self.isWiFi
                
                print("📡 Network status: \(self.connectionType.displayName)")
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    deinit {
        stopMonitoring()
    }
}
