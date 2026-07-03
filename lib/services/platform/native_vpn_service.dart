import 'dart:io';
import 'package:flutter/services.dart';

/// Modelo de configuração VPN nativa
class NativeVPNConfig {
  final String serverAddress;
  final int port;
  final String privateKey;
  final String publicKey;
  final String presharedKey;
  final String ipAddress;
  final String dnsServers;

  NativeVPNConfig({
    required this.serverAddress,
    required this.port,
    required this.privateKey,
    required this.publicKey,
    required this.presharedKey,
    required this.ipAddress,
    required this.dnsServers,
  });

  Map<String, dynamic> toMap() => {
    'serverAddress': serverAddress,
    'port': port,
    'privateKey': privateKey,
    'publicKey': publicKey,
    'presharedKey': presharedKey,
    'ipAddress': ipAddress,
    'dnsServers': dnsServers,
  };
}

/// Resultado de status da VPN nativa
class NativeVPNStatus {
  final bool isConnected;
  final String status;
  final int? latency;
  final String? error;

  NativeVPNStatus({
    required this.isConnected,
    required this.status,
    this.latency,
    this.error,
  });

  factory NativeVPNStatus.fromMap(Map<dynamic, dynamic> map) {
    return NativeVPNStatus(
      isConnected: map['isConnected'] ?? false,
      status: map['status'] ?? 'UNKNOWN',
      latency: map['latency'],
      error: map['error'],
    );
  }
}

/// Serviço de VPN nativa usando platform channels
class NativeVPNService {
  static const String _vpnChannelName = 'com.infinityprox/protection';
  static const String _securityChannelName = 'com.infinityprox/security';

  static final NativeVPNService _instance = NativeVPNService._internal();

  factory NativeVPNService() {
    return _instance;
  }

  NativeVPNService._internal() {
    _vpnChannel = MethodChannel(_vpnChannelName);
    _securityChannel = MethodChannel(_securityChannelName);
  }

  late MethodChannel _vpnChannel;
  late MethodChannel _securityChannel;

  bool _isInitialized = false;

  /// Inicializa os method channels
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError(
        'Native protection services only supported on Android and iOS',
      );
    }

    _isInitialized = true;
  }

  // ==================== VPN Methods ====================

  /// Inicia VPN com configuração
  Future<bool> startVPN(NativeVPNConfig config) async {
    try {
      await initialize();

      final result = await _vpnChannel.invokeMethod<Map>(
        'startProtection',
        config.toMap(),
      );

      return result?['status'] == 'PROTECTION_STARTING';
    } on PlatformException catch (e) {
      throw Exception('Erro ao iniciar proteção: ${e.message}');
    }
  }

  /// Para VPN
  Future<bool> stopVPN() async {
    try {
      await initialize();

      final result = await _vpnChannel.invokeMethod<Map>('stopProtection');

      return result?['status'] == 'PROTECTION_STOPPING';
    } on PlatformException catch (e) {
      throw Exception('Erro ao parar proteção: ${e.message}');
    }
  }

  /// Obtém status da VPN
  Future<NativeVPNStatus> getVPNStatus() async {
    try {
      await initialize();

      final result = await _vpnChannel.invokeMethod<Map>('getProtectionStatus');

      if (result == null) {
        return NativeVPNStatus(
          isConnected: false,
          status: 'ERROR',
          error: 'Null response',
        );
      }

      return NativeVPNStatus.fromMap(result);
    } on PlatformException catch (e) {
      return NativeVPNStatus(
        isConnected: false,
        status: 'ERROR',
        error: e.message,
      );
    }
  }

  /// Habilita/desabilita Kill Switch
  Future<bool> setKillSwitch(bool enabled) async {
    try {
      await initialize();

      final result = await _vpnChannel.invokeMethod<Map>(
        'setProtectionBlock',
        {'enabled': enabled},
      );

      return result?['killSwitch'] == enabled;
    } on PlatformException catch (e) {
      throw Exception('Erro ao configurar Kill Switch: ${e.message}');
    }
  }

  // ==================== Security Methods ====================

  /// Verifica se dispositivo é seguro
  Future<bool> isDeviceSecure() async {
    try {
      await initialize();

      final result = await _securityChannel.invokeMethod<Map>(
        'checkDeviceSecurity',
      );

      return result?['isSecure'] ?? false;
    } on PlatformException catch (e) {
      throw Exception('Erro ao verificar segurança: ${e.message}');
    }
  }

  /// Verifica se dispositivo está rooted
  Future<bool> isDeviceRooted() async {
    try {
      await initialize();

      final result = await _securityChannel.invokeMethod<Map>('isRooted');

      return result?['isRooted'] ?? false;
    } on PlatformException catch (e) {
      throw Exception('Erro ao verificar root: ${e.message}');
    }
  }

  /// Verifica se está em emulador
  Future<bool> isEmulator() async {
    try {
      await initialize();

      final result = await _securityChannel.invokeMethod<Map>('isEmulator');

      return result?['isEmulator'] ?? false;
    } on PlatformException catch (e) {
      throw Exception('Erro ao verificar emulador: ${e.message}');
    }
  }

  /// Verifica se está no Android
  bool get isAndroid => Platform.isAndroid;

  /// Verifica se está no iOS
  bool get isIOS => Platform.isIOS;
}
