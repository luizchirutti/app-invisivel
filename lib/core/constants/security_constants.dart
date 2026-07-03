/// Constantes de segurança para toda a aplicação
class SecurityConstants {
  // ==================== CRIPTOGRAFIA ====================
  /// Algoritmo de encriptação padrão: AES-256-GCM
  static const String ENCRYPTION_ALGORITHM = 'AES/GCM/NoPadding';
  static const int AES_KEY_SIZE = 256; // bits
  static const int GCM_IV_SIZE = 96; // bits (12 bytes)
  static const int GCM_TAG_SIZE = 128; // bits (16 bytes)

  // ==================== VPN ====================
  /// Identificador interno da camada protegida
  static const String VPN_PROTOCOL = 'camada protegida';
  static const int WIREGUARD_PORT = 51820;
  static const String WIREGUARD_INTERFACE = 'protected0';

  /// Kill Switch: Bloqueia tráfego se VPN cair
  static const bool ENABLE_KILL_SWITCH = true;
  static const int KILL_SWITCH_CHECK_INTERVAL_MS = 5000;

  // ==================== DNS OVER HTTPS (DoH) ====================
  /// Provedores de DoH privados
  static const String PRIMARY_DOH_SERVER = 'https://1.1.1.1/dns-query';
  static const String SECONDARY_DOH_SERVER = 'https://1.0.0.1/dns-query';
  static const String CLOUDFLARE_DOH = 'https://cloudflare-dns.com/dns-query';
  static const String NEXTDNS_DOH = 'https://dns.nextdns.io';

  /// Timeout para requisições DNS
  static const int DOH_REQUEST_TIMEOUT_MS = 10000;

  // ==================== ANTI-FINGERPRINTING ====================
  /// Headers a serem mascarados
  static const List<String> MASKED_HEADERS = [
    'User-Agent',
    'Accept-Language',
    'Accept-Encoding',
    'X-Requested-With',
  ];

  /// User-Agents genéricos (rotação)
  static const List<String> GENERIC_USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
  ];

  // ==================== DEVICE INTEGRITY ====================
  /// Detecção de Root/Jailbreak
  static const bool CHECK_DEVICE_ROOT = true;

  /// Detecção de Proxies não autorizados
  static const bool CHECK_UNAUTHORIZED_PROXIES = true;

  /// Detecção de Mock Location
  static const bool CHECK_MOCK_LOCATION = true;

  // ==================== LOGGING ====================
  /// Tamanho máximo do arquivo de log (em bytes)
  static const int MAX_LOG_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

  /// Número máximo de arquivos de log a manter
  static const int MAX_LOG_FILES = 5;

  /// Rotação automática de logs
  static const bool ENABLE_LOG_ROTATION = true;

  /// Encriptação de logs
  static const bool ENCRYPT_LOGS = true;

  // ==================== TIMEOUTS ====================
  static const int HTTP_REQUEST_TIMEOUT_MS = 30000;
  static const int VPN_CONNECTION_TIMEOUT_MS = 60000;
  static const int INTEGRITY_CHECK_TIMEOUT_MS = 15000;

  // ==================== CACHE ====================
  static const int CACHE_EXPIRATION_MINUTES = 30;
  static const bool SECURE_CACHE_ENABLED = true;

  // ==================== APP ====================
  static const String APP_NAME = 'App Invisível';
  static const String APP_VERSION = '0.1.0';
  static const String APP_BUILD_NUMBER = '1';
}

/// Configurações de SSL Pinning
class SSLPinningConfig {
  /// Certificados públicos permitidos (SHA-256)
  static const List<String> PINNED_CERTIFICATES = [
    // Adicionar fingerprints de certificados confiáveis aqui
    // Exemplo: 'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
  ];

  static const bool ENABLE_SSL_PINNING = true;
  static const bool ALLOW_INVALID_CERTIFICATES = false; // NUNCA usar em produção
}
