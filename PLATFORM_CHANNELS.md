# 🔌 Platform Channels - Integração Flutter ↔ Nativo

## 📱 Android (Kotlin) - Implementado ✅

### Arquitetura de Comunicação

```
Flutter App (Dart)
    ↓
MethodChannel("com.infinityprox/vpn")
    ↓
MainActivity.kt (Method Handler)
    ↓
VPNServiceManager.kt (Gerenciador)
    ↓
VPNServiceImpl.kt (Serviço VPN Nativo)
    ├─ setupVPNInterface()
    ├─ KillSwitchManager
    └─ monitorVPNConnection()
```

### Métodos Implementados (Android)

#### VPN Channel: `com.infinityprox/vpn`

```kotlin
// Iniciar VPN
channel.invokeMethod(
  "startVPN",
  {
    "serverAddress": "185.244.40.1",
    "port": 51820,
    "privateKey": "...",
    "publicKey": "...",
    "presharedKey": "...",
    "ipAddress": "10.0.0.2",
    "dnsServers": "1.1.1.1,1.0.0.1"
  }
)
// Response: {"status": "VPN_STARTING"}

// Parar VPN
channel.invokeMethod("stopVPN", null)
// Response: {"status": "VPN_STOPPING"}

// Obter Status
channel.invokeMethod("getVPNStatus", null)
// Response: {"isConnected": true, "status": "CONNECTED", "timestamp": 1234567890}

// Configurar Kill Switch
channel.invokeMethod("setKillSwitch", {"enabled": true})
// Response: {"killSwitch": true}
```

#### Security Channel: `com.infinityprox/security`

```kotlin
// Verificar Segurança
channel.invokeMethod("checkDeviceSecurity", null)
// Response: {"isSecure": true}

// Verificar Root
channel.invokeMethod("isRooted", null)
// Response: {"isRooted": false}

// Verificar Emulador
channel.invokeMethod("isEmulator", null)
// Response: {"isEmulator": false}
```

### Estrutura de Arquivos Android

```
android/app/src/main/
├── kotlin/com/infinityprox/
│   ├── MainActivity.kt                  [Entry point com method channels]
│   ├── vpn/
│   │   ├── VPNServiceManager.kt        [Gerenciador de VPN]
│   │   ├── VPNServiceImpl.kt            [Implementação do serviço]
│   │   └── VPNConfig.kt                [Data class de config]
│   └── security/
│       ├── KillSwitchManager.kt        [Kill Switch via iptables]
│       └── SecurityChecker.kt          [Root/Jailbreak detection]
└── AndroidManifest.xml                  [Permissões + Serviços]
```

### Permissões Necessárias

```xml
<!-- Rede -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.BIND_VPN_SERVICE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />

<!-- Serviço em Foreground -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Localização (para mock detection) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

<!-- Sistema -->
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
```

### Registro de Serviço

```xml
<service
    android:name=".vpn.VPNServiceImpl"
    android:permission="android.permission.BIND_VPN_SERVICE"
    android:exported="true">
    <intent-filter>
        <action android:name="android.net.VpnService" />
    </intent-filter>
</service>
```

---

## 🍎 iOS (Swift) - Estrutura Preparada

### Arquitetura iOS

```
Flutter App (Dart)
    ↓
MethodChannel("com.infinityprox/vpn")
    ↓
GeneratedPluginRegistrant (Swift)
    ↓
VPNViewController.swift (Handler)
    ↓
NEPacketTunnelProvider (Extensão de Rede)
    ├─ setupVPNConfiguration()
    ├─ handlePackets()
    └─ disconnectVPN()
```

### Estrutura de Arquivos iOS

```
ios/Runner/
├── Info.plist                          [Configurações]
├── Podfile                              [Dependências CocoaPods]
├── GeneratedPluginRegistrant.swift     [Plugins gerados]
└── Security/
    ├── VPNViewController.swift          [Handler de method channel]
    ├── PacketTunnelProvider.swift      [Provider de túnel]
    ├── KillSwitchManager.swift         [Kill Switch iOS]
    └── SecurityChecker.swift           [Root/Jailbreak detection]
```

### Implementação iOS (Próximo Passo)

```swift
// ios/Runner/Security/VPNViewController.swift

import Flutter

class VPNViewController: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.infinityprox/vpn",
            binaryMessenger: registrar.messenger()
        )
        let instance = VPNViewController()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func dummyMethodToEnforceBundling(_ flutterEngine: FlutterEngine) {
        // Este método não faz nada, é apenas para passar pelo análise do Flutter
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startVPN":
            handleStartVPN(call, result: result)
        case "stopVPN":
            handleStopVPN(result: result)
        case "getVPNStatus":
            handleGetStatus(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleStartVPN(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
            return
        }

        // Implementar setup do NEPacketTunnelProvider
        let vpnManager = NEVPNManager.shared()
        
        // Configurar...
        
        result(["status": "VPN_STARTING"])
    }

    private func handleStopVPN(result: @escaping FlutterResult) {
        let vpnManager = NEVPNManager.shared()
        
        do {
            try vpnManager.connection.stopVPN()
            result(["status": "VPN_STOPPING"])
        } catch {
            result(FlutterError(code: "VPN_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func handleGetStatus(result: @escaping FlutterResult) {
        let vpnManager = NEVPNManager.shared()
        
        result([
            "isConnected": vpnManager.connection.status == .connected,
            "status": vpnManager.connection.status.description,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ])
    }
}

// ios/Runner/Security/PacketTunnelProvider.swift

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(
        options: [String: NSObject]? = nil,
        completionHandler: @escaping (Error?) -> Void
    ) {
        // Configurar interface VPN
        let settings = NEVPNSettings()
        
        // IPv4 Settings
        let ipv4Settings = NEIPv4Settings()
        ipv4Settings.addresses = ["10.0.0.2"]
        settings.ipv4Settings = ipv4Settings
        
        // DNS Settings (DoH)
        let dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "1.0.0.1"])
        dnsSettings.matchDomains = [""] // Match all domains
        settings.dnsSettings = dnsSettings
        
        // Salvar configurações
        saveToPreferences {
            completionHandler(nil)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
```

---

## 🔄 Fluxo de Dados: Exemplo Completo

### 1. Iniciar VPN (Dart → Kotlin)

```dart
// lib/services/platform/unified_vpn_service.dart
final result = await _nativeVPN.startVPN(config);

// ↓ Chamada Method Channel
_vpnChannel.invokeMethod('startVPN', {
  'serverAddress': '185.244.40.1',
  'port': 51820,
  // ...
})

// ↓ Recebido em MainActivity.kt
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, vpnChannelName)
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "startVPN" -> {
                    val config = call.arguments as? Map<String, Any>
                    startVPN(config, result)
                }
            }
        }
}

// ↓ Processado em VPNServiceManager.kt
fun startVPN(config: VPNConfig, callback: (Boolean, String?) -> Unit) {
    val intent = Intent(context, VPNServiceImpl::class.java).apply {
        action = ACTION_CONNECT
        putExtra(EXTRA_CONFIG, config)
    }
    context.startForegroundService(intent)
    callback(true, null)
}

// ↓ Executado em VPNServiceImpl.kt
override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
        VPNServiceManager.ACTION_CONNECT -> {
            val config = intent.getParcelableExtra(VPNServiceManager.EXTRA_CONFIG)
            startVPN(config)
        }
    }
    return START_STICKY
}

// ↓ Resultado retorna para Dart
result.success(mapOf("status" to "VPN_STARTING"))

// ↓ Recebido em Dart
final result = await _vpnChannel.invokeMethod<Map>('startVPN', config.toMap());
final success = result?['status'] == 'VPN_STARTING';
```

---

## 🧪 Testando Platform Channels

### Debug no Android

```bash
# Ver logs do serviço VPN
adb logcat | grep VPNService

# Ver todas as permissões
adb shell pm list permissions -d

# Verificar se serviço está rodando
adb shell ps | grep com.infinityprox

# Verificar VPN ativa
adb shell netstat | grep tun
```

### Debug no iOS

```bash
# Ver logs da extensão
log show --predicate 'eventMessage contains "PacketTunnel"' --last 1h

# Verificar permissões
security dump-keychain
```

---

## 🚀 Próximas Implementações

### Android (Phase 2a)
- [ ] Finish VPNServiceImpl com WireGuard real
- [ ] Implementar iptables commands para Kill Switch
- [ ] Verificação real de interface wg0
- [ ] Notificações sistema ao desconectar
- [ ] Teste em dispositivos reais

### iOS (Phase 2b)
- [ ] Implementar PacketTunnelProvider completo
- [ ] Network Extension com NEPacketTunnelProvider
- [ ] App Groups para compartilhamento de dados
- [ ] VPN on-demand rules
- [ ] Teste em dispositivos iOS reais

### Unified (Phase 2c)
- [ ] Sincronizar estado entre nativo e Dart
- [ ] Stream de eventos da interface nativa
- [ ] Cache de configurações
- [ ] Manejo de permissões dinâmicas

---

## 📊 Status de Implementação

| Feature | Android | iOS | Status |
|---------|---------|-----|--------|
| **Method Channels** | ✅ | ⏳ | Estrutura pronta |
| **VPN Service** | ⏳ | ⏳ | Em desenvolvimento |
| **Kill Switch** | ⏳ | ⏳ | Estrutura pronta |
| **Security Checks** | ✅ | ⏳ | Android completo |
| **Testing** | ⏳ | ⏳ | A fazer |

---

## 💡 Best Practices

1. **Error Handling**
   - Sempre validar argumentos em method handlers
   - Retornar erros estruturados com code + message
   - Log detalhado de exceptions

2. **Threading**
   - VPN Service roda em background thread
   - UI updates via callbacks
   - Usar synchronized blocks para state compartilhado

3. **Permissions**
   - Solicitar permissões dinamicamente (API 23+)
   - Validar antes de chamar métodos VPN
   - Documentar permissões necessárias

4. **Lifecycle**
   - VPN Service é independent da activity
   - Usar foreground service notification
   - Handle configuration changes corretamente

---

## 📚 Referências

- [Flutter Platform Channels](https://flutter.dev/docs/development/platform-integration/platform-channels)
- [Android VPN Service API](https://developer.android.com/reference/android/net/VpnService)
- [iOS Network Extension](https://developer.apple.com/documentation/networkextension)
- [WireGuard for Android](https://www.wireguard.com/install/)

---

**Fase 2 - Platform Channels: 40% Completo** ⏳
