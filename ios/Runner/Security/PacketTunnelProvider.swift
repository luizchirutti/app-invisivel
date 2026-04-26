import Foundation
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var startCompletion: ((Error?) -> Void)?

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        startCompletion = completionHandler

        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")

        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.255"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        tunnelSettings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: ["1.1.1.1", "1.0.0.1"])
        dns.matchDomains = [""]
        tunnelSettings.dnsSettings = dns

        tunnelSettings.mtu = 1500 as NSNumber

        setTunnelNetworkSettings(tunnelSettings) { [weak self] error in
            if let error = error {
                completionHandler(error)
                return
            }

            self?.beginPacketLoop()
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        completionHandler?(messageData)
    }

    private func beginPacketLoop() {
        packetFlow.readPackets { [weak self] _, _ in
            guard self != nil else { return }
            self?.beginPacketLoop()
        }
    }
}
