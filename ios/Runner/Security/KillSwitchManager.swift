import Foundation
import NetworkExtension

enum KillSwitchManager {
    static func setEnabled(_ enabled: Bool, completion: @escaping (Bool) -> Void) {
        let manager = NEVPNManager.shared()

        manager.loadFromPreferences { error in
            guard error == nil else {
                completion(false)
                return
            }

            if let protocolConfig = manager.protocolConfiguration as? NETunnelProviderProtocol {
                var config = protocolConfig.providerConfiguration ?? [:]
                config["killSwitchEnabled"] = enabled
                protocolConfig.providerConfiguration = config
                manager.protocolConfiguration = protocolConfig
            }

            manager.isOnDemandEnabled = enabled
            manager.onDemandRules = enabled ? [NEOnDemandRuleConnect()] : []

            manager.saveToPreferences { saveError in
                completion(saveError == nil)
            }
        }
    }
}
