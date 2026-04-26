import Flutter
import Foundation
import NetworkExtension

final class VPNMethodChannelHandler: NSObject {
    private let vpnManager = NEVPNManager.shared()

    func register(with messenger: FlutterBinaryMessenger) {
        let vpnChannel = FlutterMethodChannel(name: "com.infinityprox/vpn", binaryMessenger: messenger)
        vpnChannel.setMethodCallHandler(handleVPNMethod)

        let securityChannel = FlutterMethodChannel(name: "com.infinityprox/security", binaryMessenger: messenger)
        securityChannel.setMethodCallHandler(handleSecurityMethod)
    }

    private func handleVPNMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startVPN":
            startVPN(call: call, result: result)
        case "stopVPN":
            stopVPN(result: result)
        case "getVPNStatus":
            getVPNStatus(result: result)
        case "setKillSwitch":
            setKillSwitch(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleSecurityMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkDeviceSecurity":
            result(["isSecure": SecurityChecker.isDeviceSecure()])
        case "isRooted":
            result(["isRooted": SecurityChecker.isJailbroken()])
        case "isEmulator":
            result(["isEmulator": SecurityChecker.isEmulator()])
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startVPN(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid VPN config payload", details: nil))
            return
        }

        vpnManager.loadFromPreferences { [weak self] loadError in
            if let loadError = loadError {
                result(FlutterError(code: "VPN_LOAD_ERROR", message: loadError.localizedDescription, details: nil))
                return
            }

            let protocolConfig = NETunnelProviderProtocol()
            protocolConfig.providerBundleIdentifier = args["providerBundleIdentifier"] as? String
            protocolConfig.serverAddress = args["serverAddress"] as? String ?? ""
            protocolConfig.disconnectOnSleep = false
            protocolConfig.providerConfiguration = ["config": args]

            self?.vpnManager.protocolConfiguration = protocolConfig
            self?.vpnManager.localizedDescription = "App Invisivel VPN"
            self?.vpnManager.isEnabled = true

            self?.vpnManager.saveToPreferences { saveError in
                if let saveError = saveError {
                    result(FlutterError(code: "VPN_SAVE_ERROR", message: saveError.localizedDescription, details: nil))
                    return
                }

                do {
                    try self?.vpnManager.connection.startVPNTunnel()
                    result(["status": "VPN_STARTING"])
                } catch {
                    result(FlutterError(code: "VPN_START_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func stopVPN(result: @escaping FlutterResult) {
        vpnManager.connection.stopVPNTunnel()
        result(["status": "VPN_STOPPING"])
    }

    private func getVPNStatus(result: @escaping FlutterResult) {
        let status = vpnManager.connection.status
        let isConnected = status == .connected || status == .connecting || status == .reasserting

        result([
            "isConnected": isConnected,
            "status": status.rawValue,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ])
    }

    private func setKillSwitch(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false

        KillSwitchManager.setEnabled(enabled) { success in
            if success {
                result(["killSwitch": enabled])
            } else {
                result(FlutterError(code: "KILL_SWITCH_ERROR", message: "Failed to update iOS kill switch", details: nil))
            }
        }
    }
}
