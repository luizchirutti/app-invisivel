# App Invisível - MVP de Segurança Privada

## Ativacao controlada na primeira execucao

O app pode exigir liberacao na primeira abertura usando `--dart-define` no build.

```bash
flutter build ipa --release \
  --dart-define=APP_ACTIVATION_REQUIRED=true \
  --dart-define=APP_ACTIVATION_CODES=INV001,INV002,INV003
```

```bash
flutter build ipa --release \
  --dart-define=APP_ACTIVATION_REQUIRED=true \
  --dart-define=APP_ACTIVATION_TOTP_SECRET=JBSWY3DPEHPK3PXP
```

Variaveis aceitas:

- `APP_ACTIVATION_REQUIRED=true` para forcar a ativacao.
- `APP_ACTIVATION_CODES=INV001,INV002` para aceitar codigos predefinidos.
- `APP_ACTIVATION_TOTP_SECRET=...` para aceitar codigo temporario de app authenticator.
- `APP_ACTIVATION_TOTP_PERIOD=30`, `APP_ACTIVATION_TOTP_DIGITS=6` e `APP_ACTIVATION_TOTP_WINDOW=1` para ajuste fino.

Observacao importante: este controle e local ao app. Ele ajuda a bloquear o primeiro acesso, mas nao conta instalacoes nem impede compartilhamento de codigo. Para controle real de quantidade de instalacoes, revogacao e auditoria, o correto e validar a ativacao em backend.

## 📋 Visão Geral

**App Invisível** é um MVP (Minimum Viable Product) de aplicativo de segurança privada desenvolvido em Flutter, focado em **anonimato extremo** e **anti-rastreio**. O projeto implementa uma arquitetura de segurança de classe empresarial com as melhores práticas de criptografia e privacidade.

### Funcionalidades Principais

✅ **VPN com WireGuard + Kill Switch** - Túnel seguro com bloqueio automático  
✅ **DNS sobre HTTPS (DoH)** - Privacidade total em requisições DNS  
✅ **Anti-Fingerprinting** - Mascara identidade do dispositivo  
✅ **Detecção de Ameaças** - Verifica Root/Jailbreak e proxies  
✅ **Logging Criptografado** - Todos os eventos registrados com AES-256  
✅ **Multiplataforma** - Android e iOS com código compartilhado  

---

## 🏗️ Estrutura do Projeto

```
APP_INVISIVEL/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   └── security_constants.dart          # Constantes de segurança
│   │   ├── errors/
│   │   │   └── failures.dart                    # Definições de erros
│   │   └── utils/
│   ├── data/
│   │   ├── datasources/                          # APIs de dados
│   │   ├── models/                               # Modelos de dados
│   │   └── repositories/
│   │       └── protection_repository_impl.dart   # Implementação
│   ├── domain/
│   │   ├── entities/
│   │   │   └── entities.dart                     # Entidades de domínio
│   │   ├── repositories/
│   │   │   └── repositories.dart                 # Contratos
│   │   └── usecases/
│   │       └── protection_usecases.dart          # Lógica de negócio
│   ├── presentation/
│   │   ├── bloc/
│   │   │   └── protection_bloc.dart              # BLoC de proteção
│   │   ├── pages/
│   │   │   └── protection_page.dart              # Página principal
│   │   └── widgets/
│   │       └── protection_widgets.dart           # Componentes UI
│   ├── security/
│   │   ├── encryption/
│   │   │   └── crypto_manager.dart               # Criptografia AES-256-GCM
│   │   ├── anti_fingerprinting/
│   │   │   └── anti_fingerprinter_service.dart   # Mascaramento de identidade
│   │   └── device_integrity/
│   │       └── device_integrity_service.dart     # Detecção de ameaças
│   ├── services/
│   │   ├── vpn/
│   │   │   └── vpn_service.dart                  # WireGuard + Kill Switch
│   │   ├── doh/
│   │   │   └── doh_service.dart                  # DNS sobre HTTPS
│   │   └── logging/
│   │       └── secure_logging_service.dart       # Logging criptografado
│   └── main.dart                                  # Ponto de entrada
├── android/                                       # Configurações Android
├── ios/                                           # Configurações iOS
├── server/                                        # Backend VPN (Node.js/Go)
├── pubspec.yaml                                   # Dependências Flutter
└── README.md                                      # Este arquivo
```

---

## 🔐 Arquitetura de Segurança

### 1. Camada de Criptografia (AES-256-GCM)

```dart
// Encriptação simétrica
final key = CryptoManager.generateAESKey();  // 256 bits
final encrypted = CryptoManager.encryptAES256GCM(plaintext, key);
final decrypted = CryptoManager.decryptAES256GCM(encrypted, key);

// Derivação de chaves (PBKDF2 com 100k iterações)
final derivedKey = CryptoManager.derivePBKDF2Key(
  password: 'senha',
  salt: salt,
  iterations: 100000,
  keyLength: 32,
);
```

**Detalhes Técnicos:**
- **Algoritmo**: AES-256-GCM (Galois/Counter Mode)
- **Tamanho da Chave**: 256 bits (32 bytes)
- **IV**: 96 bits (12 bytes) - gerado aleatoriamente
- **Tag de Autenticação**: 128 bits (16 bytes) - Integridade garantida
- **Derivação de Chave**: PBKDF2-SHA256 com 100.000 iterações (OWASP)

### 2. VPN com WireGuard + Kill Switch

```dart
// Inicializar e conectar
final vpnConfig = VPNConfig(
  serverAddress: '185.244.40.1',
  port: 51820,
  privateKey: 'SIx...',
  publicKey: 'bGg...',
  ipAddress: '10.0.0.2',
);

await vpnService.initializeVPN(vpnConfig);
await vpnService.connectToVPN();

// Kill Switch monitora a cada 5 segundos
// Se interface wg0 cair → bloqueia tráfego automaticamente
```

**Kill Switch Logic:**
1. Monitor verifica a cada 5 segundos se interface VPN está ativa
2. Se cair → ativa firewall que bloqueia TODO tráfego
3. Usuário é notificado crítico
4. Opção de reconectar automaticamente

### 3. DNS sobre HTTPS (DoH)

```dart
// Resolver domínio via DoH privado
final result = await doHService.resolveDomain('example.com', recordType: 'A');

result.fold(
  (failure) => print('Erro: ${failure.message}'),
  (record) => print('IP: ${record.answers}'),
);

// Suporta fallback automático entre múltiplos servidores
// Primário: Cloudflare (1.1.1.1)
// Secundário: NextDNS
// Terciário: Outro provedor
```

### 4. Anti-Fingerprinting

```dart
// Mascara identidade do dispositivo em requisições
final maskedHeaders = antiFingerprinter.getMaskedHeaders();
// {
//   'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)...',
//   'Accept-Language': 'fr-FR',
//   'Accept-Encoding': 'gzip, deflate, br',
// }

// Rotação periódica de User-Agents
// Mascaramento de Model ID
// Bloqueio de Canvas/WebGL Fingerprinting
```

### 5. Detecção de Ameaças

```dart
final integrity = await integrityService.checkDeviceIntegrity();

if (!integrity.isSecure) {
  print('Ameaças: ${integrity.threats}');
  // Exemplo:
  // - 🚨 ROOT DETECTADO: Dispositivo foi enraizado
  // - ⚠️ PROXY DETECTADO: Proxy interceptador identificado
  // - ⚠️ VERSÃO DESATUALIZADA: iOS < 13 detectado
}

// Monitoramento contínuo
integrityService.startContinuousMonitoring(
  interval: Duration(minutes: 5),
  onThreatDetected: (result) {
    logger.critical('Ameaça: ${result.threatsSummary}');
  },
);
```

### 6. Logging Seguro e Criptografado

```dart
// Todos os logs são encriptados com AES-256
await logger.info('Evento importante', 'Tag');
await logger.critical('Ameaça detectada', 'Security');

// Arquivo de log: log_2026-04-24T12-30-45.enc
// Conteúdo: AES-256-GCM criptografado + IV + AuthTag

// Rotação automática quando > 10 MB
// Máximo 5 arquivos mantidos
```

---

## 🚀 Quick Start

### 1. Pré-requisitos

- **Flutter**: >= 3.16.0
- **Dart**: >= 3.2.0
- **Android SDK**: >= API 26
- **iOS**: >= iOS 13
- **Xcode/Android Studio**

### 2. Instalação

```bash
# Clone o repositório
git clone https://github.com/seu-usuario/app-invisivel.git
cd APP_INVISIVEL

# Instale dependências
flutter pub get

# Gere código (json_serializable, etc)
dart run build_runner build

# Execute no emulador/dispositivo
flutter run
```

### 3. Configuração

#### Android (`android/app/build.gradle`)

```gradle
defaultConfig {
    minSdkVersion 26
    targetSdkVersion 34
}

// Permissões em AndroidManifest.xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

#### iOS (`ios/Podfile`)

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_NETWORK=1',
      ]
    end
  end
end
```

---

## 📦 Dependências Principais

| Pacote | Versão | Propósito |
|--------|--------|----------|
| `flutter_bloc` | 8.1.5 | State management |
| `dio` | 5.3.3 | HTTP client |
| `encrypt` | 4.4.4 | Criptografia simétrica |
| `crypto` | 3.0.3 | Hashing |
| `flutter_secure_storage` | 9.0.0 | Armazenamento seguro |
| `connectivity_plus` | 5.0.0 | Monitoramento de rede |
| `device_info_plus` | 10.0.0 | Info do dispositivo |
| `sqflite` | 2.3.0 | Banco de dados local |

---

## 🔌 Integração Backend VPN

O aplicativo espera um backend que sirva:

### 1. **Configuração VPN**

```json
GET /api/vpn/config
{
  "serverAddress": "185.244.40.1",
  "port": 51820,
  "privateKey": "...",
  "publicKey": "...",
  "presharedKey": "...",
  "ipAddress": "10.0.0.2",
  "dnsServers": "1.1.1.1,1.0.0.1"
}
```

### 2. **Verificação de Status**

```json
GET /api/vpn/status
{
  "isConnected": true,
  "bytesIn": 1024000,
  "bytesOut": 512000,
  "latency": 45,
  "serverLocation": "Amsterdam"
}
```

### 3. **Segredos Criptografados**

Todas as chaves privadas devem ser:
- Armazenadas em HSM ou Vault
- Transmitidas apenas via HTTPS com certificate pinning
- Nunca expostas em logs

---

## 🛡️ Boas Práticas Implementadas

### ✅ Criptografia

- [x] AES-256-GCM para dados em repouso
- [x] HTTPS/TLS 1.3+ para dados em trânsito
- [x] PBKDF2 com 100.000 iterações para senhas
- [x] Geração de números aleatórios com `SecureRandom`
- [x] Constant-time comparison para evitar timing attacks

### ✅ Armazenamento Seguro

- [x] Sensitive data em `flutter_secure_storage`
- [x] Criptografia de logs
- [x] Sem hardcoding de secrets
- [x] Rotação automática de chaves

### ✅ Network Security

- [x] HTTPS obrigatório
- [x] Certificate pinning preparado
- [x] DoH para privacidade DNS
- [x] Anti-DNS rebinding

### ✅ Code Security

- [x] Sem hardcoding de URLs/IPs
- [x] Input validation em todas as entradas
- [x] Error handling sem exposição de stack traces
- [x] Logging sem informações sensíveis

### ✅ Device Security

- [x] Detecção de Root/Jailbreak
- [x] Detecção de emulador
- [x] Detecção de mock location
- [x] Verificação de integridade contínua

---

## 📝 Fluxo de Proteção

```
Usuário clica "Ativar Proteção"
    ↓
[1] Verificar integridade do dispositivo
    - Detectar Root/Jailbreak
    - Detectar emulador
    - Verificar versão SO
    ↓
[2] Inicializar VPN (WireGuard)
    - Carregar config privada
    - Estabelecer túnel
    - Ativar Kill Switch
    ↓
[3] Ativar DoH
    - Forçar DNS via HTTPS
    - Fallback automático
    - Cache de queries
    ↓
[4] Ativar Anti-Fingerprinting
    - Rotacionar User-Agent
    - Mascarar headers
    - Bloquear canvas fingerprinting
    ↓
[5] Iniciar Monitoramento
    - Monitor Kill Switch (5s)
    - Detecção de ameaças (5min)
    - Logging criptografado
    ↓
✅ Proteção Completa
```

---

## 🐛 Testing

```bash
# Testes unitários
flutter test

# Teste de integração
flutter test integration_test/

# Coverage
flutter test --coverage
lcov --list coverage/lcov.info
```

---

## 🔒 Security Checklist

- [ ] Realizar pentest de rede
- [ ] Auditar código de criptografia
- [ ] Verificar SSL pinning em produção
- [ ] Testar contra proxy man-in-the-middle
- [ ] Verificar logs não contêm dados sensíveis
- [ ] Testar em dispositivos rooted/jailbroken
- [ ] Validar com security tools (MobSF, etc)

---

## 📱 Próximas Fases

**Fase 2:** 
- [ ] Interface de configuração avançada
- [ ] Múltiplos servidores VPN
- [ ] Estatísticas de uso
- [ ] Suporte a Tor

**Fase 3:**
- [ ] Backend Node.js com Infraestrutura VPN
- [ ] Dashboard de admin
- [ ] Relatórios de segurança
- [ ] Suporte a 2FA

---

## 📄 Licença

Proprietary - Desenvolvimento Fechado

---

## 👨‍💻 Autor

**Desenvolvido como MVP de Cibersegurança**  
Foco: Anonimato Extremo + Anti-Rastreio

---

## 📞 Suporte

Para issues e features:
- 📧 Email: security@appinvisivel.dev
- 🔐 PGP: Disponível em request

---

**Last Updated**: 2026-04-24  
**Version**: 0.1.0 (MVP)
