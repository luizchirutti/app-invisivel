// Arquivo: android/app/src/main/kotlin/com/infinityprox/security/SecurityChecker.kt
package com.infinityprox.security

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

/**
 * Verificador de Segurança do Dispositivo
 * Detecta: Root, Jailbreak, Emulador, Mock Location
 */
class SecurityChecker(private val context: Context) {
    companion object {
        private const val TAG = "SecurityChecker"
    }

    fun isDeviceSecure(): Boolean {
        return !isDeviceRooted() && !isEmulator() && !isMockLocationEnabled()
    }

    fun isDeviceRooted(): Boolean {
        return checkRootMethod1() || checkRootMethod2() || checkRootMethod3()
    }

    private fun checkRootMethod1(): Boolean {
        // Verificar arquivo "su"
        val suPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/system/xbin/su",
            "/system/bin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )

        return suPaths.any { File(it).exists() }.also { rooted ->
            if (rooted) Log.w(TAG, "Root detectado via su binaries")
        }
    }

    private fun checkRootMethod2(): Boolean {
        // Verificar propriedades do sistema
        val properties = mapOf(
            "ro.debuggable" to "1",
            "ro.secure" to "0",
            "ro.build.tags" to "test-keys",
            "ro.bootloader" to "unknown"
        )

        return properties.any { (prop, expected) ->
            getSystemProperty(prop) == expected
        }.also { rooted ->
            if (rooted) Log.w(TAG, "Root detectado via system properties")
        }
    }

    private fun checkRootMethod3(): Boolean {
        // Tentar executar comando como root
        return try {
            Runtime.getRuntime().exec("su")
            Log.w(TAG, "Root detectado via su command")
            true
        } catch (e: Exception) {
            false
        }
    }

    fun isEmulator(): Boolean {
        return checkEmulatorMethod1() || checkEmulatorMethod2() || checkEmulatorMethod3()
    }

    private fun checkEmulatorMethod1(): Boolean {
        // Verificar build fingerprint
        val fingerprint = Build.FINGERPRINT
        val isEmulator = fingerprint.contains("generic") || 
                         fingerprint.contains("unknown") ||
                         fingerprint.contains("emulator")
        
        if (isEmulator) Log.w(TAG, "Emulador detectado via fingerprint")
        return isEmulator
    }

    private fun checkEmulatorMethod2(): Boolean {
        // Verificar modelo do dispositivo
        val model = Build.MODEL
        val manufacturer = Build.MANUFACTURER
        
        val isEmulator = model.contains("SDK") || 
                         model.contains("emulator") ||
                         manufacturer.contains("unknown") ||
                         manufacturer == "Genymotion"
        
        if (isEmulator) Log.w(TAG, "Emulador detectado via model/manufacturer")
        return isEmulator
    }

    private fun checkEmulatorMethod3(): Boolean {
        // Verificar features do dispositivo
        val hasQemu = File("/system/lib/libqemu.so").exists() ||
                      File("/system/lib64/libqemu.so").exists()
        
        val isKvm = File("/dev/kvm").exists()
        
        val hasGoldfish = getSystemProperty("ro.hardware").contains("goldfish")

        val isEmulator = hasQemu || (isKvm && hasGoldfish)
        
        if (isEmulator) Log.w(TAG, "Emulador detectado via QEMU/KVM")
        return isEmulator
    }

    fun isMockLocationEnabled(): Boolean {
        return try {
            val isMockLocation = Settings.Secure.getInt(
                context.contentResolver,
                Settings.Secure.ALLOW_MOCK_LOCATION,
                0
            ) == 1

            if (isMockLocation) Log.w(TAG, "Mock location detectado")
            isMockLocation
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao verificar mock location", e)
            false
        }
    }

    fun getAllSecurityIssues(): List<String> {
        val issues = mutableListOf<String>()

        if (isDeviceRooted()) issues.add("ROOT_DETECTED")
        if (isEmulator()) issues.add("EMULATOR_DETECTED")
        if (isMockLocationEnabled()) issues.add("MOCK_LOCATION_ENABLED")

        // Verificar versão SDK
        if (Build.VERSION.SDK_INT < 26) {
            issues.add("OUTDATED_ANDROID_VERSION")
        }

        // Verificar se é teste/debug
        if (Build.VERSION_CODES.S <= Build.VERSION.SDK_INT) {
            if (Settings.Global.getInt(
                    context.contentResolver,
                    Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                    0
                ) == 1
            ) {
                issues.add("DEVELOPER_MODE_ENABLED")
            }
        }

        return issues
    }

    fun runAdvancedSecurityScan(config: Map<String, Any>? = null): Map<String, Any> {
        val customBlocklist = ((config?.get("customBlocklist") as? List<*>) ?: emptyList<Any>())
            .mapNotNull { it?.toString()?.trim()?.takeIf { value -> value.isNotEmpty() } }
            .toSet()

        val customAllowlist = ((config?.get("customAllowlist") as? List<*>) ?: emptyList<Any>())
            .mapNotNull { it?.toString()?.trim()?.takeIf { value -> value.isNotEmpty() } }
            .toSet()

        val suspiciousApps = detectSuspiciousApps(customBlocklist, customAllowlist)
        val rooted = isDeviceRooted()
        val emulator = isEmulator()
        val mock = isMockLocationEnabled()
        val devMode = isDeveloperModeEnabled()
        val monitoringRisk = hasMonitoringRisk()
        val phoneTapRisk = hasPhoneTapRisk(suspiciousApps)

        val hasUnsafeApps = suspiciousApps.isNotEmpty()
        val hasMalware = rooted || suspiciousApps.any {
            it.contains("spy", ignoreCase = true) ||
            it.contains("malware", ignoreCase = true)
        }
        val hasTracking = hasUnsafeApps || devMode
        val hasActiveMonitoring = monitoringRisk || mock || emulator

        val findings = mutableListOf<String>()
        if (hasUnsafeApps) findings.add("Apps suspeitos instalados detectados")
        if (hasMalware) findings.add("Sinais de malware/spyware detectados")
        if (hasTracking) findings.add("Sinais de rastreio/interceptacao detectados")
        if (hasActiveMonitoring) findings.add("Monitoramento ativo suspeito detectado")
        if (phoneTapRisk) findings.add("Possivel risco de escuta telefonica detectado")

        return mapOf(
            "hasUnsafeApps" to hasUnsafeApps,
            "hasMalware" to hasMalware,
            "hasTracking" to hasTracking,
            "hasActiveMonitoring" to hasActiveMonitoring,
            "hasPhoneTapRisk" to phoneTapRisk,
            "isRooted" to rooted,
            "isEmulator" to emulator,
            "isMockLocationEnabled" to mock,
            "suspiciousApps" to suspiciousApps,
            "findings" to findings,
        )
    }

    private fun detectSuspiciousApps(
        customBlocklist: Set<String>,
        customAllowlist: Set<String>,
    ): List<String> {
        val suspiciousPackages = setOf(
            "com.cerberus",
            "com.flexispy.android",
            "com.mspy.android",
            "com.spyera",
            "com.eyezy",
            "com.thetruthspy",
            "com.titanium.trackview",
            "com.callrecorder.auto",
            "com.cube.acr",
            "com.google.android.apps.work.clouddpc",
        ) + customBlocklist

        return try {
            val installedApps = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getInstalledApplications(
                    PackageManager.ApplicationInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getInstalledApplications(0)
            }

            installedApps
                .mapNotNull { app ->
                    val pkg = app.packageName ?: return@mapNotNull null
                    val lower = pkg.lowercase()

                    val packageMatched = suspiciousPackages.contains(pkg)
                    val keywordMatched = lower.contains("spy") ||
                        lower.contains("monitor") ||
                        lower.contains("record") ||
                        lower.contains("tracker")

                    if (!(packageMatched || keywordMatched)) {
                        return@mapNotNull null
                    }

                    val allowed = customAllowlist.any {
                        it.equals(pkg, ignoreCase = true)
                    }

                    if (allowed) null else pkg
                }
                .distinct()
                .take(20)
        } catch (e: Exception) {
            Log.w(TAG, "Erro ao verificar apps suspeitos", e)
            emptyList()
        }
    }

    private fun hasMonitoringRisk(): Boolean {
        return try {
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: ""

            enabledServices.isNotBlank()
        } catch (e: Exception) {
            Log.w(TAG, "Erro ao verificar servicos de monitoramento", e)
            false
        }
    }

    private fun isDeveloperModeEnabled(): Boolean {
        return try {
            Settings.Global.getInt(
                context.contentResolver,
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                0,
            ) == 1
        } catch (e: Exception) {
            false
        }
    }

    private fun hasPhoneTapRisk(suspiciousApps: List<String>): Boolean {
        val recorderSignals = suspiciousApps.any {
            it.contains("record", ignoreCase = true) ||
            it.contains("spy", ignoreCase = true) ||
            it.contains("call", ignoreCase = true)
        }

        val micPermissionSignals = try {
            val micCheck = context.checkSelfPermission(android.Manifest.permission.RECORD_AUDIO)
            micCheck == PackageManager.PERMISSION_GRANTED
        } catch (e: Exception) {
            false
        }

        return recorderSignals || micPermissionSignals
    }

    private fun getSystemProperty(key: String): String {
        return try {
            val process = Runtime.getRuntime().exec("getprop $key")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val value = reader.readLine()
            reader.close()
            value ?: ""
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao obter propriedade $key", e)
            ""
        }
    }
}
