// Arquivo: android/app/src/main/kotlin/com/infinityprox/MainActivity.kt
package com.infinityprox

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.infinityprox.security.KillSwitchManager
import com.infinityprox.security.SecurityChecker
import com.infinityprox.vpn.VPNConfig
import com.infinityprox.vpn.VPNServiceManager

class MainActivity: FlutterActivity() {
    private val vpnChannelName = "com.infinityprox/vpn"
    private val securityChannelName = "com.infinityprox/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal VPN
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, vpnChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startVPN" -> {
                        val config = call.arguments as? Map<String, Any>
                        startVPN(config, result)
                    }
                    "stopVPN" -> {
                        stopVPN(result)
                    }
                    "getVPNStatus" -> {
                        getVPNStatus(result)
                    }
                    "setKillSwitch" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setKillSwitch(enabled, result)
                    }
                    else -> result.notImplemented()
                }
            }

        // Canal Security
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkDeviceSecurity" -> {
                        checkDeviceSecurity(result)
                    }
                    "isRooted" -> {
                        isRooted(result)
                    }
                    "isEmulator" -> {
                        isEmulator(result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ==================== VPN Methods ====================

    private fun startVPN(config: Map<String, Any>?, result: MethodChannel.Result) {
        try {
            val vpnService = VPNServiceManager(this)
            
            val vpnConfig = VPNConfig(
                serverAddress = config?.get("serverAddress") as? String ?: "",
                port = (config?.get("port") as? Number)?.toInt() ?: 51820,
                privateKey = config?.get("privateKey") as? String ?: "",
                publicKey = config?.get("publicKey") as? String ?: "",
                presharedKey = config?.get("presharedKey") as? String ?: "",
                ipAddress = config?.get("ipAddress") as? String ?: "10.0.0.2",
                dnsServers = (config?.get("dnsServers") as? String ?: "1.1.1.1,1.0.0.1").split(",")
            )

            vpnService.startVPN(vpnConfig) { success, error ->
                if (success) {
                    result.success(mapOf("status" to "VPN_STARTING"))
                } else {
                    result.error("VPN_ERROR", error, null)
                }
            }
        } catch (e: Exception) {
            result.error("START_VPN_ERROR", e.message, e.stackTrace.toString())
        }
    }

    private fun stopVPN(result: MethodChannel.Result) {
        try {
            val vpnService = VPNServiceManager(this)
            vpnService.stopVPN() { success, error ->
                if (success) {
                    result.success(mapOf("status" to "VPN_STOPPING"))
                } else {
                    result.error("VPN_ERROR", error, null)
                }
            }
        } catch (e: Exception) {
            result.error("STOP_VPN_ERROR", e.message, e.stackTrace.toString())
        }
    }

    private fun getVPNStatus(result: MethodChannel.Result) {
        try {
            val vpnService = VPNServiceManager(this)
            val status = vpnService.getStatus()
            result.success(status)
        } catch (e: Exception) {
            result.error("STATUS_ERROR", e.message, null)
        }
    }

    private fun setKillSwitch(enabled: Boolean, result: MethodChannel.Result) {
        try {
            val killSwitch = KillSwitchManager(this)
            killSwitch.setEnabled(enabled) { success ->
                if (success) {
                    result.success(mapOf("killSwitch" to enabled))
                } else {
                    result.error("KILL_SWITCH_ERROR", "Falha ao ativar kill switch", null)
                }
            }
        } catch (e: Exception) {
            result.error("KILL_SWITCH_ERROR", e.message, null)
        }
    }

    // ==================== Security Methods ====================

    private fun checkDeviceSecurity(result: MethodChannel.Result) {
        try {
            val checker = SecurityChecker(this)
            val isSecure = checker.isDeviceSecure()
            result.success(mapOf("isSecure" to isSecure))
        } catch (e: Exception) {
            result.error("SECURITY_CHECK_ERROR", e.message, null)
        }
    }

    private fun isRooted(result: MethodChannel.Result) {
        try {
            val checker = SecurityChecker(this)
            val rooted = checker.isDeviceRooted()
            result.success(mapOf("isRooted" to rooted))
        } catch (e: Exception) {
            result.error("ROOT_CHECK_ERROR", e.message, null)
        }
    }

    private fun isEmulator(result: MethodChannel.Result) {
        try {
            val checker = SecurityChecker(this)
            val emulator = checker.isEmulator()
            result.success(mapOf("isEmulator" to emulator))
        } catch (e: Exception) {
            result.error("EMULATOR_CHECK_ERROR", e.message, null)
        }
    }
}
