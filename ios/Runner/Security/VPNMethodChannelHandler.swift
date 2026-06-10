import Flutter
import Foundation

final class VPNMethodChannelHandler: NSObject {
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
        result(["status": "UNAVAILABLE", "isConnected": false])
    }

    private func stopVPN(result: @escaping FlutterResult) {
        result(["status": "UNAVAILABLE", "isConnected": false])
    }

    private func getVPNStatus(result: @escaping FlutterResult) {
        result([
            "isConnected": false,
            "status": "UNAVAILABLE",
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ])
    }

    private func setKillSwitch(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
        result(["killSwitch": enabled, "status": "UNAVAILABLE"])
    }
}
