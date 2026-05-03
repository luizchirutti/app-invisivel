import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
	private let privacyShieldTag = 901245

	override func sceneWillResignActive(_ scene: UIScene) {
		super.sceneWillResignActive(scene)
		applyPrivacyShield(on: scene)
	}

	override func sceneDidEnterBackground(_ scene: UIScene) {
		super.sceneDidEnterBackground(scene)
		applyPrivacyShield(on: scene)
	}

	override func sceneDidBecomeActive(_ scene: UIScene) {
		super.sceneDidBecomeActive(scene)
		removePrivacyShield(on: scene)
	}

	private func applyPrivacyShield(on scene: UIScene) {
		guard let windowScene = scene as? UIWindowScene else { return }
		for appWindow in windowScene.windows {
			if appWindow.viewWithTag(privacyShieldTag) != nil {
				continue
			}

			let blurEffect = UIBlurEffect(style: .systemChromeMaterialDark)
			let shieldView = UIVisualEffectView(effect: blurEffect)
			shieldView.frame = appWindow.bounds
			shieldView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
			shieldView.tag = privacyShieldTag
			appWindow.addSubview(shieldView)
			appWindow.bringSubviewToFront(shieldView)
		}
	}

	private func removePrivacyShield(on scene: UIScene) {
		guard let windowScene = scene as? UIWindowScene else { return }
		for appWindow in windowScene.windows {
			appWindow.viewWithTag(privacyShieldTag)?.removeFromSuperview()
		}
	}

}
