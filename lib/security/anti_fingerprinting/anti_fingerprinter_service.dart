import 'dart:math';
import '../../core/constants/security_constants.dart';

/// Serviço de Anti-Fingerprinting
/// Intercepta requisições e mascara metadados de identidade do dispositivo
class AntiFingerprinterService {
  static final AntiFingerprinterService _instance =
      AntiFingerprinterService._internal();

  factory AntiFingerprinterService() {
    return _instance;
  }

  AntiFingerprinterService._internal() {
    _initializeObfuscation();
  }

  late String _maskedUserAgent;
  late String _maskedLanguage;
  late String _maskedAcceptEncoding;
  final Random _random = Random.secure();

  void _initializeObfuscation() {
    _maskedUserAgent =
        SecurityConstants.GENERIC_USER_AGENTS[_random.nextInt(
            SecurityConstants.GENERIC_USER_AGENTS.length)];
    _maskedLanguage = _generateRandomLanguage();
    _maskedAcceptEncoding = _generateRandomAcceptEncoding();
  }

  /// Obtém o User-Agent mascarado (aleatório entre genéricos)
  String getMaskedUserAgent() {
    // Rotacionar periodicamente para maior anonimato
    if (_random.nextDouble() < 0.3) {
      _maskedUserAgent = SecurityConstants.GENERIC_USER_AGENTS[
          _random.nextInt(SecurityConstants.GENERIC_USER_AGENTS.length)];
    }
    return _maskedUserAgent;
  }

  /// Gera linguagem aleatória
  String _generateRandomLanguage() {
    const languages = [
      'en-US',
      'en-GB',
      'pt-BR',
      'fr-FR',
      'de-DE',
      'es-ES',
      'it-IT',
      'zh-CN',
      'ja-JP',
      'ko-KR',
    ];
    return languages[_random.nextInt(languages.length)];
  }

  /// Obtém linguagem mascarada
  String getMaskedLanguage() {
    if (_random.nextDouble() < 0.2) {
      _maskedLanguage = _generateRandomLanguage();
    }
    return _maskedLanguage;
  }

  /// Gera Accept-Encoding aleatório
  String _generateRandomAcceptEncoding() {
    const encodings = [
      'gzip, deflate, br',
      'gzip, deflate',
      'br',
      'gzip, br',
    ];
    return encodings[_random.nextInt(encodings.length)];
  }

  /// Obtém encoding mascarado
  String getMaskedAcceptEncoding() {
    if (_random.nextDouble() < 0.2) {
      _maskedAcceptEncoding = _generateRandomAcceptEncoding();
    }
    return _maskedAcceptEncoding;
  }

  /// Mascara metadados de requisição HTTP
  Map<String, String> getMaskedHeaders() {
    return {
      'User-Agent': getMaskedUserAgent(),
      'Accept-Language': getMaskedLanguage(),
      'Accept-Encoding': getMaskedAcceptEncoding(),
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Cache-Control': 'max-age=0',
      'Pragma': 'no-cache',
    };
  }

  /// Remove headers perigosos que identificam a aplicação
  static Map<String, String> stripDangerousHeaders(
      Map<String, String> headers) {
    final stripped = Map<String, String>.from(headers);
    const dangerousHeaders = [
      'X-Requested-With', // Indica requisição AJAX/app
      'X-Application-Id', // ID da aplicação
      'X-App-Version', // Versão da app
      'X-Device-Id', // ID do dispositivo
      'X-Device-Model', // Modelo do dispositivo
      'X-Build-Number', // Build number
    ];

    dangerousHeaders.forEach(stripped.remove);
    return stripped;
  }

  /// Mascara horários de requisição para evitar padrões
  static String getMaskedTimestamp() {
    // Adicionar jitter aleatório ao timestamp (0-5 segundos)
    final now = DateTime.now();
    final jitter = Random.secure().nextInt(5000); // 0-5 segundos em ms
    return now.add(Duration(milliseconds: jitter)).toIso8601String();
  }

  /// Gera Device ID falsificado
  static String generateFakeDeviceId() {
    const chars = 'abcdef0123456789';
    final random = Random.secure();
    return List.generate(32, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Mascara Model ID do dispositivo
  static String maskModelId(String realModelId) {
    // Retornar um modelo genérico mapeado
    const modelMapping = {
      'SM': 'Generic Phone', // Samsung
      'Pixel': 'Generic Phone', // Google
      'iPhone': 'Generic iPhone',
      'iPad': 'Generic Tablet',
    };

    for (var key in modelMapping.keys) {
      if (realModelId.contains(key)) {
        return modelMapping[key]!;
      }
    }

    return 'Generic Device';
  }

  /// Bloqueia canvas fingerprinting
  /// Retorna hash fake de canvas para evitar rastreamento
  static String getCanvasFingerprint() {
    return 'BLOCKED_CANVAS_FINGERPRINT_' + _generateRandomString(16);
  }

  /// Bloqueia WebGL fingerprinting
  static String getWebGLFingerprint() {
    return 'BLOCKED_WEBGL_FINGERPRINT_' + _generateRandomString(16);
  }

  /// Gera string aleatória para obfuscação
  static String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Obtém lista de headers a mascarar
  static List<String> getHeadersToObfuscate() {
    return SecurityConstants.MASKED_HEADERS;
  }
}
