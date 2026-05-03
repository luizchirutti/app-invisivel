package com.infinityprox

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Receiver estático responsável por reiniciar o LockEnforcementService
 * após boot ou atualização do pacote. O serviço em foreground é quem
 * efetivamente monitora o desbloqueio e abre o app para autenticação.
 */
class UnlockLaunchReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != Intent.ACTION_USER_UNLOCKED
        ) {
            return
        }

        val prefs = context.getSharedPreferences("native_safety_mode", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("enabled", false)) return

        // Inicia o LockEnforcementService que monitora USER_PRESENT/SCREEN_ON
        // via receiver dinâmico e tem permissão para abrir Activities.
        val serviceIntent = Intent(context, LockEnforcementService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
