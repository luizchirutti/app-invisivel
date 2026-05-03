package com.infinityprox

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Serviço em foreground que monitora desbloqueio do dispositivo e força
 * a abertura do app para autenticação via PIN.
 *
 * Diferente de um BroadcastReceiver estático, um Foreground Service tem
 * permissão para chamar startActivity() no Android 10+ (background launch
 * restriction não se aplica a serviços em foreground).
 */
class LockEnforcementService : Service() {

    companion object {
        private const val CHANNEL_ID = "lock_enforcement_fg"
        private const val NOTIFICATION_ID = 8888
        private const val ENFORCEMENT_INTERVAL_MS = 15_000L
        private const val PREFS_NAME = "native_safety_mode"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_PENDING_UNLOCK = "pending_unlock"
        const val ACTION_STOP = "com.infinityprox.ACTION_STOP_LOCK_ENFORCEMENT"
    }

    private var screenReceiver: BroadcastReceiver? = null
    private val handler = Handler(Looper.getMainLooper())
    private val enforcementRunnable = object : Runnable {
        override fun run() {
            if (!shouldKeepEnforcing()) {
                return
            }
            launchMainActivity()
            sendUrgentNotification()
            handler.postDelayed(this, ENFORCEMENT_INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        registerScreenReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        // Re-registra o receiver caso tenha sido perdido (ex: após restart do serviço)
        if (screenReceiver == null) {
            registerScreenReceiver()
        }
        if (shouldKeepEnforcing()) {
            startEnforcementLoop()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        stopEnforcementLoop()
        unregisterScreenReceiver()
    }

    // ==================== Notificação de Foreground ====================

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Modo Segurança",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Proteção ativa em segundo plano"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 1, launchIntent, piFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Modo Segurança Ativo")
            .setContentText("Proteção em execução. Toque para abrir.")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    // ==================== Receiver Dinâmico ====================

    private fun registerScreenReceiver() {
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent?) {
                val action = intent?.action ?: return
                if (action != Intent.ACTION_USER_PRESENT) return

                val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                if (!prefs.getBoolean(KEY_ENABLED, false)) return

                prefs.edit().putBoolean(KEY_PENDING_UNLOCK, true).apply()
                launchMainActivity()
                sendUrgentNotification()
                startEnforcementLoop()
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(screenReceiver, filter)
        }
    }

    private fun unregisterScreenReceiver() {
        try {
            screenReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        screenReceiver = null
    }

    private fun shouldKeepEnforcing(): Boolean {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        return prefs.getBoolean(KEY_ENABLED, false) && prefs.getBoolean(KEY_PENDING_UNLOCK, false)
    }

    private fun startEnforcementLoop() {
        handler.removeCallbacks(enforcementRunnable)
        handler.postDelayed(enforcementRunnable, ENFORCEMENT_INTERVAL_MS)
    }

    private fun stopEnforcementLoop() {
        handler.removeCallbacks(enforcementRunnable)
    }

    // ==================== Lançamento do App ====================

    private fun launchMainActivity() {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        }
        try {
            startActivity(launchIntent)
        } catch (_: Exception) {
            // Fallback: envia notificação de alta prioridade se startActivity falhar
            sendUrgentNotification()
        }
    }

    private fun sendUrgentNotification() {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 2, launchIntent, piFlags)

        val urgentChannelId = "lock_urgent_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val urgentChannel = NotificationChannel(
                urgentChannelId,
                "Alerta de Segurança",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setBypassDnd(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(urgentChannel)
        }

        val notification = NotificationCompat.Builder(this, urgentChannelId)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Modo Segurança – PIN Necessário")
            .setContentText("Toque para inserir seu PIN de segurança.")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setFullScreenIntent(pendingIntent, true)
            .setContentIntent(pendingIntent)
            .build()

        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(9998, notification)
    }
}
