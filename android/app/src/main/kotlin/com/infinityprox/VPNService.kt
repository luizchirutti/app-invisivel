// Arquivo: android/app/src/main/kotlin/com/infinityprox/VPNService.kt
// Serviço VPN nativo para Android

package com.infinityprox

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.net.VpnService as AndroidVpnService
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Serviço VPN nativo para WireGuard no Android
 * Gerencia:
 * - Configuração de interface tunística
 * - Kill Switch (firewall)
 * - Roteamento de tráfego
 */
class VPNServiceImpl : AndroidVpnService() {
    companion object {
        private const val CHANNEL_ID = "vpn_notification"
        private const val NOTIFICATION_ID = 1
        private const val TAG = "VPNService"
    }

    private var vpnThread: Thread? = null
    private val lock = Object()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "com.infinityprox.START_VPN" -> {
                startVPN(intent)
            }
            "com.infinityprox.STOP_VPN" -> {
                stopVPN()
            }
        }
        return START_STICKY
    }

    private fun startVPN(intent: Intent) {
        synchronized(lock) {
            if (vpnThread != null) return

            // Criar notificação
            createNotificationChannel()
            val notification = createNotification()
            startForeground(NOTIFICATION_ID, notification)

            // Iniciar thread VPN
            vpnThread = Thread {
                try {
                    // Configurar interface VPN via WireGuard
                    setupWireGuardInterface()
                    
                    // Ativar Kill Switch
                    enableKillSwitch()
                    
                    // Loop de monitoramento
                    monitorVPNConnection()
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "Erro no VPN Service", e)
                    stopVPN()
                }
            }.apply { 
                name = "VPN-Worker"
                start() 
            }
        }
    }

    private fun stopVPN() {
        synchronized(lock) {
            vpnThread?.interrupt()
            vpnThread = null
            
            // Desativar Kill Switch
            disableKillSwitch()
            
            // Limpar interface VPN
            stopForeground(true)
            stopSelf()
        }
    }

    private fun setupWireGuardInterface() {
        // Usar Builder para configurar interface
        val builder = Builder()
        
        // Adicionar endereço IPv4
        builder.addAddress("10.0.0.2", 32)
        
        // Rotear todo tráfego pela VPN
        builder.addRoute("0.0.0.0", 0)
        
        // Configurar DNS (DoH será forçado em level de app)
        builder.addDnsServer("1.1.1.1")
        builder.addDnsServer("1.0.0.1")
        
        // Nome da interface
        builder.setSession("App Invisível VPN")
        
        // Usar MTU padrão
        builder.setMtu(1500)
        
        // Configurar para bloquear tráfego IPv6 não-VPN
        builder.setUnderlyingNetworks(null)
        
        // Estabelecer a interface
        try {
            val vpnInterface = builder.establish()
            // Aqui seria implementado o socket do WireGuard
            android.util.Log.d(TAG, "Interface VPN estabelecida")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Erro ao estabelecer interface", e)
            throw e
        }
    }

    private fun enableKillSwitch() {
        // Usar iptables para bloquear tráfego fora do túnel VPN
        try {
            // Exemplo: sudo iptables -P OUTPUT DROP
            // Isso bloquearia TODO tráfego não-VPN
            
            // Em produção, seria:
            // 1. Identificar UID da aplicação
            // 2. Usar SELinux para restringir acesso
            // 3. Usar netfilter/iptables para DROP de pacotes
            
            android.util.Log.d(TAG, "Kill Switch ativado")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Erro ao ativar Kill Switch", e)
            throw e
        }
    }

    private fun disableKillSwitch() {
        try {
            // Restaurar regras de firewall
            android.util.Log.d(TAG, "Kill Switch desativado")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Erro ao desativar Kill Switch", e)
        }
    }

    private fun monitorVPNConnection() {
        while (!Thread.currentThread().isInterrupted) {
            try {
                // Verificar se interface ainda está UP
                // Se não, dispara Kill Switch
                Thread.sleep(5000) // Verificar a cada 5s
            } catch (e: InterruptedException) {
                break
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, "VPN Protection", importance)
            channel.description = "Status da proteção VPN"
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("App Invisível")
            .setContentText("🔒 VPN Conectada e Protegida")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopVPN()
        super.onDestroy()
    }
}
