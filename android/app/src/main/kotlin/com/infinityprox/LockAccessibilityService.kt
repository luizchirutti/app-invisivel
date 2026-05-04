package com.infinityprox

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/**
 * Serviço de acessibilidade que monitora trocas de app em primeiro plano.
 *
 * Quando o Modo Segurança está ativo e o desbloqueio do PIN ainda não ocorreu
 * (pending_unlock=true), qualquer app que entrar em primeiro plano é imediatamente
 * substituído pelo nosso app. Isso garante que o usuário nunca consiga usar outro
 * app ou as Configurações sem antes digitar o PIN seguro.
 *
 * O usuário precisa conceder a permissão de Acessibilidade uma única vez nas
 * Configurações do Android.
 */
class LockAccessibilityService : AccessibilityService() {

    companion object {
        private const val PREFS_NAME = "native_safety_mode"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_PENDING_UNLOCK = "pending_unlock"

        // Pacotes de sistema que nunca devem ser bloqueados (launcher, teclado, etc.)
        private val SYSTEM_PACKAGES = setOf(
            "android",
            "com.android.systemui",
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.sec.android.app.launcher",
            "com.miui.home",
            "com.huawei.android.launcher",
            "com.oppo.launcher",
            "com.vivo.launcher"
        )
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = serviceInfo ?: AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
        info.notificationTimeout = 50
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return

        // Nunca interceptar nosso próprio app
        if (packageName == this.packageName) return

        // Nunca interceptar pacotes de sistema críticos
        if (isSystemPackage(packageName)) return

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val safetyEnabled = prefs.getBoolean(KEY_ENABLED, false)
        val pendingUnlock = prefs.getBoolean(KEY_PENDING_UNLOCK, false)

        if (!safetyEnabled || !pendingUnlock) return

        // Outro app entrou em foco com desbloqueio pendente — trazer nosso app de volta
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        }
        try {
            startActivity(launchIntent)
        } catch (_: Exception) {}
    }

    override fun onInterrupt() {}

    private fun isSystemPackage(pkg: String): Boolean {
        if (SYSTEM_PACKAGES.contains(pkg)) return true
        if (pkg.startsWith("com.android.") && !pkg.contains("settings")) return true
        if (pkg.contains("inputmethod") || pkg.contains("keyboard") || pkg.contains("honeyboard")) return true
        return false
    }
}
