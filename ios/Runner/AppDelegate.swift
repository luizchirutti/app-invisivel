import Flutter
import UIKit

@main
@objc final class AppDelegate: FlutterAppDelegate {
    private let vpnChannelHandler = VPNMethodChannelHandler()
    private let privacyShieldTag = 901245

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

    override func applicationWillResignActive(_ application: UIApplication) {
        super.applicationWillResignActive(application)
        applyPrivacyShield()
    }

    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        applyPrivacyShield()
    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        removePrivacyShield()
    }

    private func activeWindows() -> [UIWindow] {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
        }

        if let appWindow = window {
            return [appWindow]
        }

        return []
    }

    private func applyPrivacyShield() {
        for appWindow in activeWindows() {
            if appWindow.viewWithTag(privacyShieldTag) != nil {
                continue
            }

            let blurEffect = UIBlurEffect(style: .systemChromeMaterialDark)
            let shieldView = UIVisualEffectView(effect: blurEffect)
            shieldView.frame = appWindow.bounds
            shieldView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            shieldView.tag = privacyShieldTag

            let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
            icon.tintColor = UIColor.white
            icon.contentMode = .scaleAspectFit
            icon.translatesAutoresizingMaskIntoConstraints = false

            let label = UILabel()
            label.text = "Modo Segurança"
            label.textColor = UIColor.white
            label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            label.translatesAutoresizingMaskIntoConstraints = false

            shieldView.contentView.addSubview(icon)
            shieldView.contentView.addSubview(label)

            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: shieldView.contentView.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: shieldView.contentView.centerYAnchor, constant: -12),
                icon.widthAnchor.constraint(equalToConstant: 42),
                icon.heightAnchor.constraint(equalToConstant: 42),
                label.centerXAnchor.constraint(equalTo: shieldView.contentView.centerXAnchor),
                label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 10),
            ])

            appWindow.addSubview(shieldView)
            appWindow.bringSubviewToFront(shieldView)
        }
    }

    private func removePrivacyShield() {
        for appWindow in activeWindows() {
            appWindow.viewWithTag(privacyShieldTag)?.removeFromSuperview()
        }
    }
}
