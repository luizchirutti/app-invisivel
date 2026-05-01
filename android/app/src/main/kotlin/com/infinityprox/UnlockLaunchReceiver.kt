package com.infinityprox

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class UnlockLaunchReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_USER_PRESENT) {
            return
        }

        val prefs = context.getSharedPreferences("native_safety_mode", Context.MODE_PRIVATE)
        val shouldEnforce = prefs.getBoolean("enabled", false)
        if (!shouldEnforce) {
            return
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        context.startActivity(launchIntent)
    }
}
