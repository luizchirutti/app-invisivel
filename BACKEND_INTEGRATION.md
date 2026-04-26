/**
 * GUIA DE INTEGRAÇÃO COM BACKEND VPN
 * 
 * Este documento descreve como integrar o aplicativo Flutter
 * com um backend VPN robusto para produção.
 */

## 1. ARQUITETURA DO BACKEND

### Stack Recomendado
- **Linguagem**: Node.js (Express) ou Go (Gin)
- **Database**: PostgreSQL com criptografia
- **VPN**: WireGuard em containers Docker
- **Orquestração**: Kubernetes ou Docker Swarm
- **Monitoring**: Prometheus + Grafana

### Estrutura de Servidores

```
┌─────────────────────────────────────────┐
│          App Flutter (Cliente)           │
└────────────────┬────────────────────────┘
                 │ HTTPS + Cert Pinning
                 ↓
┌─────────────────────────────────────────┐
│       API Gateway (Rate Limiting)        │
├─────────────────────────────────────────┤
│  - Autenticação JWT                     │
│  - Validação de requisições              │
│  - Rate limiting (100 req/min por user) │
└────────────────┬────────────────────────┘
                 │
         ┌───────┴────────┐
         ↓                ↓
    ┌─────────────┐  ┌──────────────┐
    │  Config API │  │  Status API  │
    └─────────────┘  └──────────────┘
         │                │
         └───────┬────────┘
                 ↓
    ┌──────────────────────────┐
    │  Database (PostgreSQL)   │
    │  - User Credentials      │
    │  - VPN Configs (ENC)     │
    │  - Connection Logs       │
    └──────────────────────────┘

    ┌──────────────────────────┐
    │  Vault (HashiCorp)       │
    │  - Private Keys          │
    │  - Preshared Keys        │
    │  - Certificates          │
    └──────────────────────────┘

    ┌──────────────────────────┐
    │  WireGuard Containers    │
    │  - VPN Server 1          │
    │  - VPN Server 2 (Backup) │
    │  - VPN Server N          │
    └──────────────────────────┘
```

## 2. ENDPOINTS API

### 2.1 POST /api/v1/auth/register
Registra novo usuário

```
Request:
{
  "email": "user@example.com",
  "password_hash": "sha512_hash",  // Enviado já com hash
  "device_id": "unique_device_id",
  "device_platform": "android|ios"
}

Response (201):
{
  "user_id": "uuid",
  "access_token": "jwt_token",
  "refresh_token": "jwt_token",
  "expires_in": 3600
}
```

### 2.2 POST /api/v1/auth/login
Autentica usuário

```
Request:
{
  "email": "user@example.com",
  "password_hash": "sha512_hash",
  "device_id": "unique_device_id"
}

Response (200):
{
  "access_token": "jwt_token",
  "refresh_token": "jwt_token",
  "expires_in": 3600
}
```

### 2.3 GET /api/v1/vpn/config
Obtém configuração VPN do usuário

```
Headers:
Authorization: Bearer jwt_token

Response (200):
{
  "vpn_config": {
    "server_address": "185.244.40.1",
    "port": 51820,
    "private_key": "encrypted_with_user_pubkey",
    "public_key": "pubkey...",
    "preshared_key": "encrypted_with_user_pubkey",
    "ip_address": "10.0.0.2/32",
    "dns_servers": "1.1.1.1,1.0.0.1",
    "mtu": 1500
  },
  "certificate": "user_certificate_for_tls",
  "expires_at": "2026-05-24T00:00:00Z"
}
```

### 2.4 GET /api/v1/vpn/status
Status da conexão

```
Headers:
Authorization: Bearer jwt_token

Response (200):
{
  "is_connected": true,
  "server_location": "Amsterdam, Netherlands",
  "ipv4_address": "123.45.67.89",
  "latency_ms": 45,
  "bytes_in": 1024000,
  "bytes_out": 512000,
  "uptime_seconds": 3600,
  "next_rotation": "2026-04-25T12:00:00Z"
}
```

### 2.5 POST /api/v1/vpn/logs
Envia logs de conexão (rate limitado)

```
Request:
{
  "encrypted_logs": "base64_encrypted_content"
}

Response (204): No Content
```

## 3. SEGURANÇA DA API

### 3.1 Autenticação
- JWT com RS256 (RSA-2048)
- Access token: 1 hora
- Refresh token: 30 dias
- Rotation de keys a cada 90 dias

### 3.2 Criptografia em Trânsito
- TLS 1.3 obrigatório
- Certificate pinning (SHA-256)
- Suporte apenas a ciphers modernos

```
GET /api/certs/pin-config
Response:
{
  "pins": [
    "sha256/aaaa...",
    "sha256/bbbb...",
    "sha256/cccc..."
  ],
  "backup_pins": [
    "sha256/xxxx...",
    "sha256/yyyy..."
  ],
  "max_age": 86400
}
```

### 3.3 Criptografia em Repouso
```
Database:
- sensitive_data = AES256_ENCRYPT(data, master_key)

Vault:
- master_key = HSM_STORED_KEY
- Acesso via API autenticada apenas
```

### 3.4 Rate Limiting
```
- 100 requisições/min por usuário
- 10 requisições/min para /vpn/config
- 1 requisição/min para /vpn/logs

Headers de resposta:
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 75
X-RateLimit-Reset: 1619391600
```

## 4. BACKEND IMPLEMENTATION (Node.js Example)

### 4.1 Instalação

```bash
npm install express jsonwebtoken bcryptjs cors helmet dotenv
npm install pg pg-promise # PostgreSQL
npm install axios # Para requisições
npm install helmet # Security headers
```

### 4.2 Estrutura de Diretórios

```
backend/
├── src/
│   ├── config/
│   │   ├── database.js
│   │   └── vault.js
│   ├── routes/
│   │   ├── auth.routes.js
│   │   └── vpn.routes.js
│   ├── controllers/
│   │   ├── auth.controller.js
│   │   └── vpn.controller.js
│   ├── middleware/
│   │   ├── auth.middleware.js
│   │   └── rateLimit.middleware.js
│   ├── services/
│   │   ├── vpn.service.js
│   │   ├── crypto.service.js
│   │   └── user.service.js
│   ├── models/
│   │   ├── User.js
│   │   └── VPNConfig.js
│   └── app.js
├── .env
├── .env.example
└── docker-compose.yml
```

### 4.3 Exemplo de Controller

```javascript
// src/controllers/vpn.controller.js
const VPNService = require('../services/vpn.service');
const CryptoService = require('../services/crypto.service');

class VPNController {
  async getConfig(req, res) {
    try {
      const userId = req.user.id;
      
      // Obter config do banco
      const config = await VPNService.getUserConfig(userId);
      
      // Criptografar chaves privadas com public key do usuário
      const userPublicKey = req.user.public_key;
      const encrypted = CryptoService.encryptWithPublicKey(
        config.private_key,
        userPublicKey
      );
      
      return res.json({
        vpn_config: {
          ...config,
          private_key: encrypted,
          preshared_key: CryptoService.encryptWithPublicKey(
            config.preshared_key,
            userPublicKey
          )
        }
      });
    } catch (error) {
      return res.status(500).json({ error: error.message });
    }
  }

  async getStatus(req, res) {
    try {
      const userId = req.user.id;
      
      // Obter status do WireGuard
      const status = await VPNService.getConnectionStatus(userId);
      
      return res.json(status);
    } catch (error) {
      return res.status(500).json({ error: error.message });
    }
  }

  async submitLogs(req, res) {
    try {
      const userId = req.user.id;
      const { encrypted_logs } = req.body;
      
      // Salvar logs criptografados no banco
      await VPNService.saveLogs(userId, encrypted_logs);
      
      return res.status(204).send();
    } catch (error) {
      return res.status(500).json({ error: error.message });
    }
  }
}

module.exports = new VPNController();
```

## 5. DOCKER COMPOSE PARA DESENVOLVIMENTO

```yaml
version: '3.9'

services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgresql://user:pass@postgres:5432/vpn_db
      VAULT_ADDR: http://vault:8200
    depends_on:
      - postgres
      - vault

  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: vpn_db
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql

  vault:
    image: vault:latest
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: "token123"
      VAULT_DEV_LISTEN_ADDRESS: "0.0.0.0:8200"
    cap_add:
      - IPC_LOCK

  wireguard:
    image: linuxserver/wireguard
    cap_add:
      - NET_ADMIN
      - NET_RAW
      - SYS_MODULE
    environment:
      - SERVERURL=185.244.40.1
      - SERVERPORT=51820
      - PEERS=10
      - PEERDNS=1.1.1.1
    ports:
      - "51820:51820/udp"
    volumes:
      - wireguard_config:/config

volumes:
  postgres_data:
  wireguard_config:
```

## 6. MONITORAMENTO E ALERTAS

```
Prometheus scrape_configs:
  - job_name: 'api'
    static_configs:
      - targets: ['api:3000']

Métricas importantes:
- vpn_connections_active (gauge)
- vpn_connection_errors_total (counter)
- api_request_duration_seconds (histogram)
- database_query_duration_seconds (histogram)
- auth_failures_total (counter)

Alertas:
- VPN Connections < 10% expected
- API Error Rate > 5%
- Database Connection Pool Exhausted
- Certificate Expires in 7 days
```

## 7. DEPLOYMENT

### 7.1 Production Checklist
- [ ] Certificados SSL/TLS válidos
- [ ] Certificate pinning configurado
- [ ] Todas as secrets em Vault
- [ ] Database backups automáticos
- [ ] Monitoring e alertas ativos
- [ ] Rate limiting ativo
- [ ] CORS configurado corretamente
- [ ] HSTS ativado
- [ ] Security headers (CSP, etc)
- [ ] Auditoria de logs
- [ ] Rotação de chaves de criptografia
- [ ] Teste de penetração realizado

### 7.2 Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vpn-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: vpn-api
  template:
    metadata:
      labels:
        app: vpn-api
    spec:
      containers:
      - name: api
        image: vpn-api:latest
        ports:
        - containerPort: 3000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: vpn-secrets
              key: database-url
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

---

**Este é um guia de integração profissional para produção.**
**Sempre realizar security audits antes de deploy!**
