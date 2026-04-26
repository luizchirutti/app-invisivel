// Arquivo: android/app/src/main/kotlin/com/infinityprox/security/KillSwitchManager.kt
package com.infinityprox.security

import android.content.Context
import android.util.Log
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * Gerenciador de Kill Switch para Android
 * Usa iptables para bloquear tráfego se VPN cair
 */
class KillSwitchManager(private val context: Context) {
    companion object {
        private const val TAG = "KillSwitchManager"
    }

    fun setEnabled(enabled: Boolean, callback: (Boolean) -> Unit) {
        try {
            if (enabled) {
                enableKillSwitch(callback)
            } else {
                disableKillSwitch(callback)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao configurar Kill Switch", e)
            callback(false)
        }
    }

    fun enableKillSwitch(callback: (Boolean) -> Unit) {
        try {
            Log.d(TAG, "Ativando Kill Switch")

            // Kill Switch rules usando iptables:
            // 1. Bloquear todo tráfego OUTPUT
            // 2. Permitir apenas traffic pela interface VPN
            // 3. Permitir localhost

            executeIptablesCommand("iptables -P OUTPUT DROP")
            executeIptablesCommand("iptables -P INPUT ACCEPT")
            executeIptablesCommand("iptables -P FORWARD ACCEPT")

            // Permitir loopback
            executeIptablesCommand("iptables -A OUTPUT -o lo -j ACCEPT")

            // Permitir interface VPN (será wg0)
            executeIptablesCommand("iptables -A OUTPUT -o wg0 -j ACCEPT")

            // Permitir DNS local
            executeIptablesCommand("iptables -A OUTPUT -d 8.8.8.8 -p udp --dport 53 -j ACCEPT")
            executeIptablesCommand("iptables -A OUTPUT -d 8.8.4.4 -p udp --dport 53 -j ACCEPT")

            Log.d(TAG, "Kill Switch ativado com sucesso")
            callback(true)

        } catch (e: Exception) {
            Log.e(TAG, "Erro ao ativar Kill Switch", e)
            callback(false)
        }
    }

    fun disableKillSwitch(callback: (Boolean) -> Unit) {
        try {
            Log.d(TAG, "Desativando Kill Switch")

            // Restaurar regras padrão
            executeIptablesCommand("iptables -P OUTPUT ACCEPT")
            executeIptablesCommand("iptables -F OUTPUT")
            executeIptablesCommand("iptables -F INPUT")
            executeIptablesCommand("iptables -F FORWARD")

            Log.d(TAG, "Kill Switch desativado")
            callback(true)

        } catch (e: Exception) {
            Log.e(TAG, "Erro ao desativar Kill Switch", e)
            callback(false)
        }
    }

    fun triggerKillSwitch() {
        try {
            Log.e(TAG, "🚨 KILL SWITCH ACIONADO - TRÁFEGO BLOQUEADO!")

            // Bloquear TODOS os pacotes
            executeIptablesCommand("iptables -P OUTPUT DROP")
            executeIptablesCommand("iptables -F OUTPUT")
            executeIptablesCommand("iptables -A OUTPUT -o lo -j ACCEPT")

            // TODO: Notificar usuário com intent
            
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao acionar Kill Switch", e)
        }
    }

    private fun executeIptablesCommand(command: String): String {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val output = reader.readText()
            reader.close()

            process.waitFor()
            Log.d(TAG, "Comando executado: $command")
            output

        } catch (e: Exception) {
            Log.w(TAG, "Erro ao executar comando iptables: $command", e)
            throw e
        }
    }
}
