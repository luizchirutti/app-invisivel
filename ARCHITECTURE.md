# 🏗️ Arquitetura Técnica - App Invisível MVP

## Executive Summary

**App Invisível** é uma aplicação de segurança privada que implementa múltiplas camadas de proteção combinando:
- **Criptografia simétrica** (AES-256-GCM)
- **VPN com tunelamento seguro** (WireGuard)
- **DNS criptografado** (DoH)
- **Anti-rastreio** (Anti-fingerprinting)
- **Detecção de ameaças** (Root/Jailbreak detection)

---

## 🎯 Objetivos de Arquitetura

| Objetivo | Métrica | Status |
|----------|---------|--------|
| Privacidade Total | Zero dados pessoais expostos | ✅ MVP |
| Segurança Máxima | Detecção de 100% das ameaças conhecidas | ✅ MVP |
| Performance | < 100ms latência de VPN | ⏳ Otimização |
| Escalabilidade | 1M+ usuários simultâneos | ⏳ Backend |
| Usabilidade | UI simples com 1-click activation | ✅ MVP |

---

## 📊 Arquitetura em Camadas

```
┌──────────────────────────────────────────────┐
│         CAMADA DE APRESENTAÇÃO (UI)          │
│  ┌──────────────────────────────────────┐   │
│  │  ProtectionPage + ProtectionBloc    │   │
│  │  - Estado centralizador              │   │
│  │  - Widgets reusáveis                 │   │
│  │  - Responsivo (Material 3)           │   │
│  └──────────────────────────────────────┘   │
└────────────────┬─────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────┐
│      CAMADA DE LÓGICA DE NEGÓCIO (BLoC)      │
│  ┌──────────────────────────────────────┐   │
│  │  ProtectionBloc                     │   │
│  │  - StartProtectionEvent             │   │
│  │  - StopProtectionEvent              │   │
│  │  - GetStatusEvent                   │   │
│  └──────────────────────────────────────┘   │
└────────────────┬─────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────┐
│         CAMADA DE DOMÍNIO (Use Cases)        │
│  ┌──────────────────────────────────────┐   │
│  │  StartProtectionUseCase             │   │
│  │  StopProtectionUseCase              │   │
│  │  GetProtectionStatusUseCase         │   │
│  └──────────────────────────────────────┘   │
└────────────────┬─────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────┐
│      CAMADA DE DADOS (Repositories)          │
│  ┌──────────────────────────────────────┐   │
│  │  ProtectionRepositoryImpl           │   │
│  │  ConfigurationRepositoryImpl        │   │
│  │  LogRepositoryImpl                  │   │
│  └──────────────────────────────────────┘   │
└────────────────┬─────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────┐
│       CAMADA DE SERVIÇOS (Business Logic)    │
│  ┌──────────────────────────────────────┐   │
│  │  VPNService (WireGuard)             │   │
│  │  DoHService (DNS)                   │   │
│  │  DeviceIntegrityService            │   │
│  │  AntiFingerprinterService          │   │
│  │  SecureLoggingService              │   │
│  └──────────────────────────────────────┘   │
└────────────────┬─────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────┐
│      CAMADA DE SEGURANÇA (Criptografia)      │
│  ┌──────────────────────────────────────┐   │
│  │  CryptoManager (AES-256-GCM)        │   │
│  │  SecureStorageManager (PBKDF2)      │   │
│  │  SSL Pinning & Cert Validation      │   │
│  └──────────────────────────────────────┘   │
└────────────────┬─────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────┐
│      CAMADA NATIVA (Platform Channels)       │
│  ┌──────────────────────────────────────┐   │
│  │  Android: VPNServiceImpl (Kotlin)    │   │
│  │  iOS: PacketTunnelProvider (Swift)  │   │
│  │  - Kill Switch via iptables/NEP     │   │
│  │  - Monitoramento de interface       │   │
│  └──────────────────────────────────────┘   │
└──────────────────────────────────────────────┘
```

---

## 🔐 Fluxo de Segurança Detalhado

### 1️⃣ Inicialização

```
App Launch
    ↓
[Init] Secure Logging Service
    ├─ Criar diretórios criptografados
    └─ Carregar chave de encriptação
    ↓
[Init] Device Integrity Service
    ├─ Verificar Root/Jailbreak
    ├─ Verificar versão SO
    └─ Iniciar monitoramento contínuo (5 min)
    ↓
[Init] Anti-Fingerprinter Service
    ├─ Gerar User-Agent aleatório
    ├─ Gerar Language aleatória
    └─ Preparar headers mascarados
    ↓
[Ready] UI com botão "Ativar Proteção"
```

### 2️⃣ Ativação de Proteção

```
User Tap: Ativar Proteção
    ↓
BLoC: StartProtectionEvent
    ↓
UseCase: StartProtectionUseCase.call()
    ↓
Repository: ProtectionRepository.startProtection()
    ↓
[1] Device Integrity Check
    ├─ Verify not rooted/jailbroken
    ├─ Verify not on emulator
    └─ ⚠️ Se falhar → Return IntegrityFailure
    ↓
[2] VPN Service Init
    ├─ Load encrypted VPN config
    ├─ Initialize WireGuard interface
    └─ ⚠️ Se falhar → Return VPNConnectionFailure
    ↓
[3] Activate Kill Switch
    ├─ Setup iptables rules (Android)
    ├─ Setup NEPacketTunnelProvider (iOS)
    └─ Start monitoring timer (5s interval)
    ↓
[4] Connect to VPN
    ├─ Establish WireGuard tunnel
    ├─ Wait for connection (2-3s)
    └─ Verify tunnel is UP
    ↓
[5] Enforce DoH
    ├─ Configure system DNS resolver
    ├─ Setup fallback servers
    └─ Rotate query servers
    ↓
[6] Activate Anti-Fingerprinting
    ├─ Start User-Agent rotation
    ├─ Inject masked headers in requests
    └─ Block canvas fingerprinting
    ↓
[7] Start Continuous Monitoring
    ├─ Monitor VPN interface (5s)
    ├─ Monitor Device Integrity (5 min)
    ├─ Monitor connection logs
    └─ Encrypt logs to disk
    ↓
✅ ProtectionStatus returned
    {
      isVPNActive: true,
      isKillSwitchActive: true,
      dohEnabled: true,
      antiFingerprinting: true,
      threatDetectionActive: true,
      activeThreats: [],
      riskLevel: 0  // 100% Seguro
    }
```

### 3️⃣ Monitoramento Contínuo

```
Timer: 5s interval
    ├─ Check VPN interface status
    │   ├─ Is wg0/NEP interface UP? ✓
    │   └─ Has IP address? ✓
    ├─ If interface down:
    │   ├─ TRIGGER KILL SWITCH
    │   ├─ Block ALL outgoing traffic
    │   ├─ Log critical event
    │   └─ Notify user
    └─ Continue monitoring

Timer: 5 min interval
    ├─ Re-check device integrity
    │   ├─ Still not rooted? ✓
    │   └─ No suspicious apps? ✓
    ├─ If threat detected:
    │   ├─ Log critical event
    │   ├─ Update UI with threat
    │   └─ Optional: Auto disconnect
    └─ Continue monitoring
```

### 4️⃣ Kill Switch Ativado

```
VPN Interface DOWN detected
    ↓
Kill Switch Immediately:
    ├─ Android:
    │   └─ iptables -P OUTPUT DROP
    │       (Block ALL outgoing packets)
    ├─ iOS:
    │   └─ NEPacketTunnelProvider
    │       (Force traffic through tunnel or block)
    ↓
Notify User:
    ├─ Critical notification
    ├─ Status shows "🚨 KILL SWITCH ACTIVE"
    └─ Options: Retry/Disconnect
    ↓
Recovery Options:
    ├─ [Retry] Reconnect to VPN
    ├─ [Disconnect] Turn off protection
    └─ [Auto-Reconnect] Enabled by default
```

---

## 🔑 Fluxo de Criptografia

### Entrada de Dados → Saída Criptografada

```
Plaintext Data (ex: log entry)
    │
    ├─→ [CryptoManager.generateAESKey()]
    │   └─ Secure Random 256-bit key
    │
    ├─→ [CryptoManager.generateGCMIV()]
    │   └─ Secure Random 96-bit IV
    │
    ├─→ [Encrypt with AES-256-GCM]
    │   ├─ Plaintext
    │   ├─ Key (256-bit)
    │   ├─ IV (96-bit)
    │   └─ Output: Ciphertext + AuthTag (128-bit)
    │
    └─→ [Combine & Encode]
        ├─ Combined = IV || Ciphertext || AuthTag
        └─ Output = base64(Combined)

Storage File:
    └─ log_2026-04-24T12-30-45.enc
       │
       ├─ Line 1: base64_encrypted_log_entry_1
       ├─ Line 2: base64_encrypted_log_entry_2
       └─ Line N: base64_encrypted_log_entry_N

Decryption Flow (Reverse):
    Encrypted Data
    ↓
    [base64.decode()]
    ↓
    Extract: IV (12 bytes) | Ciphertext | AuthTag (16 bytes)
    ↓
    [AES-256-GCM.decrypt(key, IV, ciphertext, authTag)]
    ↓
    Plaintext (if AuthTag valid)
    or Exception (if tampered)
```

---

## 📡 Fluxo de Rede & DNS

```
App Request (ex: GET https://example.com)
    │
    ├─→ [AntiFingerprinter]
    │   ├─ Inject masked User-Agent
    │   ├─ Inject masked Accept-Language
    │   ├─ Remove dangerous headers
    │   └─ Add jitter to timestamp
    │
    ├─→ [DoH Client]
    │   ├─ Query: example.com via HTTPS
    │   ├─ POST /dns-query
    │   ├─ Primary: https://1.1.1.1/dns-query
    │   ├─ Fallback: https://dns.nextdns.io
    │   └─ Cache result (TTL-aware)
    │
    ├─→ [VPN Tunnel]
    │   ├─ Request encrypted via WireGuard
    │   ├─ Routes through virtual interface (wg0)
    │   ├─ Encrypted to VPN server
    │   └─ Server relays to destination
    │
    └─→ [Remote Server]
        ├─ Sees request from VPN server IP
        ├─ No knowledge of real user identity
        └─ Returns response through VPN

Response Flow (Reverse):
    VPN Server
    ↓
    [WireGuard Decrypt]
    ↓
    App Receives (masked headers)
    ↓
    [Cache & Log (encrypted)]
```

---

## 🛡️ Matriz de Segurança

| Ameaça | Mitigação | Implementação |
|--------|-----------|---------------|
| **IP Leak** | Kill Switch | iptables + NEPacketTunnelProvider |
| **DNS Leak** | DoH + Fallback | https://1.1.1.1/dns-query |
| **Fingerprinting** | Header Masking | AntiFingerprinterService |
| **Root/Jailbreak** | Detecção | DeviceIntegrityService |
| **MITM Attack** | Certificate Pinning | SSL Pinning Config |
| **Data Breach** | AES-256-GCM | CryptoManager |
| **Timing Attack** | Constant-time Comparison | SecureStorageManager |
| **Side Channel** | Secure Random | SecureRandom (Fortuna) |

---

## ⚡ Performance & Optimization

### Métricas Alvo

```
VPN Connection Time:  < 3 seconds
DNS Resolution:       < 500 ms
First Request:        < 1 second
Ongoing Latency:      < 100 ms overhead
Memory Usage:         < 150 MB (idle)
Battery Impact:       < 5% additional drain
```

### Otimizações Implementadas

✅ **Caching**
- DNS queries (TTL-aware)
- Device integrity check (5 min)
- Anti-fingerprinting headers (reuse)

✅ **Lazy Loading**
- VPN config carregado sob demanda
- Services inicializados assincronamente
- UI renderizada incrementalmente

✅ **Connection Pooling**
- HTTP client reutiliza conexões
- Database pooling para backend
- VPN tunnel reutilizado

---

## 🧪 Estratégia de Testes

### Testes Unitários
```
- CryptoManager (encrypção/decripção)
- AntiFingerprinterService (header masking)
- DeviceIntegrityService (detection logic)
- DoHService (DNS resolution)
```

### Testes de Integração
```
- VPNService + Kill Switch
- DoH + Fallback servers
- Logging + Encryption
- BLoC state transitions
```

### Testes de Segurança
```
- Penetration testing com proxies
- Root detection evasion
- MITM attack simulation
- Certificate pinning validation
```

---

## 📈 Escalabilidade

### Backend (Para Futura Fase)

**Horizontal Scaling:**
```
- Load Balancer (HTTPS) → API Gateway
- API Gateway → 3-5 API Instances (containers)
- Database Replication (Primary + Replicas)
- Redis Cache (session + DNS cache)
- WireGuard Servers (multi-region)
```

**Vertical Scaling:**
```
- Database: PostgreSQL with partitioning
- Cache: Redis cluster
- Logging: Elasticsearch + Kibana
- Monitoring: Prometheus + Grafana
```

---

## 🔄 CI/CD Pipeline (Futuro)

```yaml
GitHub Actions:
  1. Lint (Dart Analyzer)
  2. Test (Unit + Integration)
  3. Security Scan (OWASP)
  4. Build (APK + IPA)
  5. Deploy to TestFlight/Google Play Internal
  6. E2E Tests (Real devices)
  7. Security Audit
  8. Production Deployment
```

---

## 📋 Decisões de Design

### 1. Por que Clean Architecture?
✅ Separação clara de responsabilidades  
✅ Fácil de testar  
✅ Independente de frameworks  
✅ Escalável  

### 2. Por que BLoC?
✅ State management robusto  
✅ Testável  
✅ Reativo (Streams)  
✅ Community suporte  

### 3. Por que AES-256-GCM?
✅ Padrão NIST  
✅ Autenticação incluída (integridade)  
✅ Implementação madura  
✅ Hardware acceleration (AES-NI)  

### 4. Por que WireGuard?
✅ Moderno (< 4000 linhas código)  
✅ Criptografia moderna  
✅ Performance superior  
✅ Auditado por independentes  

---

## 🚀 Roadmap Futuro

**Fase 1 (MVP - Atual):**
- ✅ VPN + Kill Switch
- ✅ DoH + Anti-Fingerprinting
- ✅ Device Integrity
- ✅ Logging Seguro

**Fase 2 (V1.0):**
- ⏳ Interface de Configuração avançada
- ⏳ Múltiplos servidores VPN
- ⏳ Estatísticas de uso
- ⏳ Temas UI customizáveis

**Fase 3 (V2.0):**
- ⏳ Backend completo
- ⏳ Dashboard Admin
- ⏳ Suporte a Tor
- ⏳ Suporte a WireGuard 2.0

---

## 📞 Discussão de Arquitetura

Para discussões sobre decisões de design ou otimizações:
- 📧 architecture@appinvisivel.dev
- 🔐 Usar PGP para comunicações sensíveis

---

**Última Atualização**: 2026-04-24  
**Versão da Arquitetura**: 1.0  
**Status**: MVP Production-Ready
