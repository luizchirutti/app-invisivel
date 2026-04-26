import Flutter
import UIKit

@main
@objc final class AppDelegate: FlutterAppDelegate {
    private let vpnChannelHandler = VPNMethodChannelHandler()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        vpnChannelHandler.register(with: controller.binaryMessenger)
        GeneratedPluginRegistrant.register(with: self)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
