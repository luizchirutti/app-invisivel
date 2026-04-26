// Arquivo: android/app/src/main/kotlin/com/infinityprox/security/SecurityChecker.kt
package com.infinityprox.security

import android.content.Context
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
