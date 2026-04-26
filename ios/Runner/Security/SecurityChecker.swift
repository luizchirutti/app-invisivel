import Foundation
import UIKit

enum SecurityChecker {
    static func isDeviceSecure() -> Bool {
        return !isJailbroken() && !isEmulator()
    }

    static func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]

        if jailbreakPaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
            return true
        }

        let testPath = "/private/ios_security_test.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
        #endif
    }

    static func isEmulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        #endif
    }
}
