// Arquivo: android/app/src/main/kotlin/com/infinityprox/MainActivity.kt
package com.infinityprox

import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.infinityprox.security.KillSwitchManager
import com.infinityprox.security.SecurityChecker
import com.infinityprox.vpn.VPNConfig
import com.infinityprox.vpn.VPNServiceManager

class MainActivity: FlutterActivity() {
    private val vpnChannelName = "com.infinityprox/protection"
    private val securityChannelName = "com.infinityprox/security"
    private val duressChannelName = "com.infinityprox/duress"
    private val nativeSafetyPrefs = "native_safety_mode"
    private val nativeSafetyEnabledKey = "enabled"
    private val nativeSafetyPendingUnlockKey = "pending_unlock"

    override fun onStart() {
        super.onStart()
        // Melhor esforço para permitir exibição imediata da tela protegida
        // em dispositivos com lockscreen.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal VPN
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, vpnChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startProtection" -> {
                        val config = call.arguments as? Map<String, Any>
                        startVPN(config, result)
                    }
                    "stopProtection" -> {
                        stopVPN(result)
                    }
                    "getProtectionStatus" -> {
                        getVPNStatus(result)
                    }
                    "setProtectionBlock" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setKillSwitch(enabled, result)
                    }
                    "triggerProtectionBlock" -> {
                        triggerEmergencyBlock(result)
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
                    "runAdvancedSecurityScan" -> {
                        val config = call.arguments as? Map<String, Any>
                        runAdvancedSecurityScan(config, result)
                    }
                    else -> result.notImplemented()
                }
            }

        // Canal Duress (reset de fábrica via Device Admin)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, duressChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isDeviceAdminActive" -> isDeviceAdminActive(result)
                    "requestDeviceAdmin" -> requestDeviceAdmin(result)
                    "performFactoryReset" -> performFactoryReset(result)
                    "setNativeSafetyFlags" -> {
                        val safetyModeEnabled = call.argument<Boolean>("safetyModeEnabled") ?: false
                        val unlockPinConfigured = call.argument<Boolean>("unlockPinConfigured") ?: false
                        setNativeSafetyFlags(safetyModeEnabled, unlockPinConfigured, result)
                    }
                    "setPendingUnlockEnforcement" -> {
                        val pending = call.argument<Boolean>("pending") ?: false
                        setPendingUnlockEnforcement(pending, result)
                    }
                    "startLockEnforcementService" -> startLockEnforcementService(result)
                    "stopLockEnforcementService" -> stopLockEnforcementService(result)
                    "isAccessibilityServiceEnabled" -> isAccessibilityServiceEnabled(result)
                    "openAccessibilitySettings" -> openAccessibilitySettings(result)
                    "isFullScreenIntentPermissionGranted" -> isFullScreenIntentPermissionGranted(result)
                    "openFullScreenIntentSettings" -> openFullScreenIntentSettings(result)
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
                    result.success(mapOf("status" to "PROTECTION_STARTING"))
                } else {
                    result.error("PROTECTION_ERROR", error, null)
                }
            }
        } catch (e: Exception) {
            result.error("START_PROTECTION_ERROR", e.message, e.stackTrace.toString())
        }
    }

    private fun stopVPN(result: MethodChannel.Result) {
        try {
            val vpnService = VPNServiceManager(this)
            vpnService.stopVPN() { success, error ->
                if (success) {
                    result.success(mapOf("status" to "PROTECTION_STOPPING"))
                } else {
                    result.error("PROTECTION_ERROR", error, null)
                }
            }
        } catch (e: Exception) {
            result.error("STOP_PROTECTION_ERROR", e.message, e.stackTrace.toString())
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

    private fun triggerEmergencyBlock(result: MethodChannel.Result) {
        try {
            val killSwitch = KillSwitchManager(this)
            killSwitch.triggerKillSwitch()
            result.success(mapOf("blocked" to true))
        } catch (e: Exception) {
            result.error("EMERGENCY_BLOCK_ERROR", e.message, null)
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

    private fun runAdvancedSecurityScan(config: Map<String, Any>?, result: MethodChannel.Result) {
        try {
            val checker = SecurityChecker(this)
            val scan = checker.runAdvancedSecurityScan(config)
            result.success(scan)
        } catch (e: Exception) {
            result.error("ADV_SECURITY_SCAN_ERROR", e.message, null)
        }
    }

    // ==================== Duress / Device Admin Methods ====================

    private fun getDevicePolicyManager(): DevicePolicyManager =
        getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager

    private fun getAdminComponent(): ComponentName =
        ComponentName(this, AppDeviceAdminReceiver::class.java)

    private fun isDeviceAdminActive(result: MethodChannel.Result) {
        try {
            val dpm = getDevicePolicyManager()
            val active = dpm.isAdminActive(getAdminComponent())
            result.success(active)
        } catch (e: Exception) {
            result.error("DEVICE_ADMIN_ERROR", e.message, null)
        }
    }

    private fun requestDeviceAdmin(result: MethodChannel.Result) {
        try {
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, getAdminComponent())
                putExtra(
                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                    "Necessário para executar reset de segurança em caso de coação."
                )
            }
            startActivityForResult(intent, 0)
            result.success(true)
        } catch (e: Exception) {
            result.error("DEVICE_ADMIN_REQUEST_ERROR", e.message, null)
        }
    }

    private fun performFactoryReset(result: MethodChannel.Result) {
        try {
            val dpm = getDevicePolicyManager()
            if (!dpm.isAdminActive(getAdminComponent())) {
                result.error("NOT_DEVICE_ADMIN", "App não é administrador do dispositivo", null)
                return
            }
            result.success(true)
            // Pequeno delay para garantir que o resultado chegue ao Flutter antes do wipe
            android.os.Handler(mainLooper).postDelayed({
                dpm.wipeData(0)
            }, 500)
        } catch (e: Exception) {
            result.error("FACTORY_RESET_ERROR", e.message, null)
        }
    }

    private fun setNativeSafetyFlags(
        safetyModeEnabled: Boolean,
        unlockPinConfigured: Boolean,
        result: MethodChannel.Result
    ) {
        try {
            val shouldEnforce = safetyModeEnabled && unlockPinConfigured
            getSharedPreferences(nativeSafetyPrefs, MODE_PRIVATE)
                .edit()
                .putBoolean(nativeSafetyEnabledKey, shouldEnforce)
                .putBoolean(nativeSafetyPendingUnlockKey, shouldEnforce)
                .apply()
            // Inicia ou para o serviço de vigilância de forma automática
            if (shouldEnforce) {
                doStartLockEnforcementService()
            } else {
                doStopLockEnforcementService()
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("NATIVE_SAFETY_FLAGS_ERROR", e.message, null)
        }
    }

    private fun setPendingUnlockEnforcement(
        pending: Boolean,
        result: MethodChannel.Result
    ) {
        try {
            val prefs = getSharedPreferences(nativeSafetyPrefs, MODE_PRIVATE)
            val safetyEnabled = prefs.getBoolean(nativeSafetyEnabledKey, false)
            prefs.edit()
                .putBoolean(nativeSafetyPendingUnlockKey, safetyEnabled && pending)
                .apply()
            if (safetyEnabled && pending) {
                doStartLockEnforcementService()
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("PENDING_UNLOCK_ERROR", e.message, null)
        }
    }

    private fun startLockEnforcementService(result: MethodChannel.Result) {
        try {
            doStartLockEnforcementService()
            result.success(true)
        } catch (e: Exception) {
            result.error("LOCK_SERVICE_START_ERROR", e.message, null)
        }
    }

    private fun stopLockEnforcementService(result: MethodChannel.Result) {
        try {
            doStopLockEnforcementService()
            result.success(true)
        } catch (e: Exception) {
            result.error("LOCK_SERVICE_STOP_ERROR", e.message, null)
        }
    }

    private fun doStartLockEnforcementService() {
        val serviceIntent = Intent(this, LockEnforcementService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun doStopLockEnforcementService() {
        val serviceIntent = Intent(this, LockEnforcementService::class.java).apply {
            action = LockEnforcementService.ACTION_STOP
        }
        startService(serviceIntent)
    }

    private fun isAccessibilityServiceEnabled(result: MethodChannel.Result) {
        try {
            val enabled = isLockAccessibilityServiceEnabled()
            result.success(enabled)
        } catch (e: Exception) {
            result.error("ACCESSIBILITY_CHECK_ERROR", e.message, null)
        }
    }

    private fun isLockAccessibilityServiceEnabled(): Boolean {
        val expectedServiceId = "$packageName/${LockAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        while (colonSplitter.hasNext()) {
            if (colonSplitter.next().equals(expectedServiceId, ignoreCase = true)) return true
        }
        return false
    }

    private fun openAccessibilitySettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("ACCESSIBILITY_SETTINGS_ERROR", e.message, null)
        }
    }

    private fun isFullScreenIntentPermissionGranted(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                result.success(true)
                return
            }

            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            result.success(nm.canUseFullScreenIntent())
        } catch (e: Exception) {
            result.error("FULL_SCREEN_PERMISSION_CHECK_ERROR", e.message, null)
        }
    }

    private fun openFullScreenIntentSettings(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } else {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("FULL_SCREEN_PERMISSION_SETTINGS_ERROR", e.message, null)
        }
    }
}
