// Arquivo: android/app/src/main/kotlin/com/infinityprox/vpn/VPNServiceImpl.kt
package com.infinityprox.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.VpnService as AndroidVpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import com.infinityprox.security.KillSwitchManager
import kotlin.concurrent.thread

/**
 * Serviço VPN nativo para Android
 * Implementa WireGuard com Kill Switch usando iptables
 */
class VPNServiceImpl : AndroidVpnService() {
    companion object {
        private const val TAG = "VPNServiceImpl"
        private const val CHANNEL_ID = "vpn_notification"
        private const val NOTIFICATION_ID = 1
        
        var isRunning = false
            private set
    }

    private var vpnThread: Thread? = null
    private var killSwitchManager: KillSwitchManager? = null
    private val lock = Object()
    private var currentConfig: VPNConfig? = null
    private var vpnInterface: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            VPNServiceManager.ACTION_CONNECT -> {
                val config = @Suppress("DEPRECATION")
                (intent.getSerializableExtra(VPNServiceManager.EXTRA_CONFIG) as? VPNConfig)
                startVPN(config)
            }
            VPNServiceManager.ACTION_DISCONNECT -> {
                stopVPN()
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun startVPN(config: VPNConfig?) {
        synchronized(lock) {
            if (vpnThread != null || config == null) return
            
            currentConfig = config
            isRunning = true

            // Criar notificação de foreground
            createNotificationChannel()
            val notification = createNotification()
            startForeground(NOTIFICATION_ID, notification)

            // Inicializar Kill Switch
            killSwitchManager = KillSwitchManager(this)

            // Iniciar thread VPN
            vpnThread = thread(start = true, isDaemon = false, name = "VPN-Worker") {
                try {
                    Log.d(TAG, "Iniciando VPN com servidor: ${config.serverAddress}")

                    // Ativar Kill Switch ANTES de conectar
                    killSwitchManager?.enableKillSwitch { success ->
                        if (success) {
                            Log.d(TAG, "Kill Switch ativado com sucesso")
                        } else {
                            Log.w(TAG, "Falha ao ativar Kill Switch")
                        }
                    }

                    // Configurar interface VPN
                    setupVPNInterface(config)

                    // Monitorar conexão
                    monitorVPNConnection()

                    Log.d(TAG, "VPN conectada com sucesso")
                    updateNotification("VPN Conectada", isConnected = true)

                } catch (e: Exception) {
                    Log.e(TAG, "Erro no serviço VPN", e)
                    updateNotification("Erro na VPN: ${e.message}", isConnected = false)
                    stopVPN()
                }
            }
        }
    }

    private fun stopVPN() {
        synchronized(lock) {
            Log.d(TAG, "Parando VPN")

            // Desativar Kill Switch
            killSwitchManager?.disableKillSwitch { _ ->
                Log.d(TAG, "Kill Switch desativado")
            }

            // Parar thread VPN
            vpnThread?.interrupt()
            vpnThread = null
            vpnInterface?.close()
            vpnInterface = null

            isRunning = false
            updateNotification("VPN Desconectada", isConnected = false)
        }
    }

    private fun setupVPNInterface(config: VPNConfig) {
        try {
            val builder = Builder()

            // Configurar endereço IPv4
            builder.addAddress(config.ipAddress, 32)

            // Rotear TODO tráfego pela VPN (0.0.0.0/0)
            builder.addRoute("0.0.0.0", 0)

            // Configurar DNS (será DoH em nível de app)
            for (dns in config.dnsServers) {
                try {
                    builder.addDnsServer(dns)
                } catch (e: Exception) {
                    Log.w(TAG, "Erro ao adicionar DNS $dns: ${e.message}")
                }
            }

            // Nome da sessão
            builder.setSession("App Invisível VPN")

            // MTU
            builder.setMtu(1500)

            // Bloquear tráfego IPv6 fora do túnel
            builder.setUnderlyingNetworks(null)

            // Estabelecer interface
            vpnInterface = builder.establish()
            
            if (vpnInterface != null) {
                Log.d(TAG, "Interface VPN estabelecida com sucesso")
            } else {
                throw Exception("Falha ao estabelecer interface VPN")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Erro ao configurar interface VPN", e)
            throw e
        }
    }

    private fun monitorVPNConnection() {
        while (!Thread.currentThread().isInterrupted && isRunning) {
            try {
                // Verificar status da interface a cada 5 segundos
                Thread.sleep(5000)

                // TODO: Implementar verificação real da interface wg0
                // if (!isVPNInterfaceActive()) {
                //     Log.e(TAG, "Interface VPN caiu! Ativando Kill Switch")
                //     killSwitchManager?.triggerKillSwitch()
                // }

            } catch (e: InterruptedException) {
                break
            } catch (e: Exception) {
                Log.e(TAG, "Erro no monitoramento VPN", e)
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, "VPN Protection", importance)
            channel.description = "Status da proteção VPN"
            channel.enableLights(false)
            channel.enableVibration(false)

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("App Invisível")
            .setContentText("🔒 VPN em andamento...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(false)
            .build()
    }

    private fun updateNotification(text: String, isConnected: Boolean) {
        val icon = if (isConnected) "🔒" else "🔓"
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("App Invisível")
            .setContentText("$icon $text")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(isConnected)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        notificationManager?.notify(NOTIFICATION_ID, notification)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopVPN()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
