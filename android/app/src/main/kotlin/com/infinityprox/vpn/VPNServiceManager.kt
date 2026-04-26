// Arquivo: android/app/src/main/kotlin/com/infinityprox/vpn/VPNServiceManager.kt
package com.infinityprox.vpn

import android.content.Context
import android.content.Intent
import android.util.Log
import java.io.Serializable

/**
 * Configuração de VPN
 */
data class VPNConfig(
    val serverAddress: String,
    val port: Int,
    val privateKey: String,
    val publicKey: String,
    val presharedKey: String,
    val ipAddress: String,
    val dnsServers: List<String>
) : Serializable

/**
 * Gerenciador de VPN para Android
 * Responsável por iniciar/parar o serviço VPN
 */
class VPNServiceManager(private val context: Context) {
    companion object {
        private const val TAG = "VPNServiceManager"
        const val ACTION_CONNECT = "com.infinityprox.VPN_CONNECT"
        const val ACTION_DISCONNECT = "com.infinityprox.VPN_DISCONNECT"
        const val EXTRA_CONFIG = "vpn_config"
    }

    fun startVPN(config: VPNConfig, callback: (Boolean, String?) -> Unit) {
        try {
            Log.d(TAG, "Iniciando VPN: ${config.serverAddress}:${config.port}")

            val intent = Intent(context, VPNServiceImpl::class.java).apply {
                action = ACTION_CONNECT
                putExtra(EXTRA_CONFIG, config)
            }

            // Iniciar serviço
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }

            callback(true, null)
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao iniciar VPN", e)
            callback(false, e.message)
        }
    }

    fun stopVPN(callback: (Boolean, String?) -> Unit) {
        try {
            Log.d(TAG, "Parando VPN")

            val intent = Intent(context, VPNServiceImpl::class.java).apply {
                action = ACTION_DISCONNECT
            }

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            callback(true, null)
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao parar VPN", e)
            callback(false, e.message)
        }
    }

    fun getStatus(): Map<String, Any> {
        return try {
            mapOf(
                "isConnected" to isVPNConnected(),
                "status" to getConnectionStatus(),
                "timestamp" to System.currentTimeMillis()
            )
        } catch (e: Exception) {
            mapOf(
                "isConnected" to false,
                "status" to "ERROR",
                "error" to (e.message ?: "Unknown error")
            )
        }
    }

    private fun isVPNConnected(): Boolean {
        // TODO: Implementar verificação real da interface VPN
        return VPNServiceImpl.isRunning
    }

    private fun getConnectionStatus(): String {
        return if (isVPNConnected()) "CONNECTED" else "DISCONNECTED"
    }
}
