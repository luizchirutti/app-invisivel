import Foundation

enum KillSwitchManager {
    static func setEnabled(_ enabled: Bool, completion: @escaping (Bool) -> Void) {
        _ = enabled
        completion(true)
    }
}
