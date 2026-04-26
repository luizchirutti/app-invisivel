import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/security_constants.dart';

/// Resultado da verificação de integridade do dispositivo
class DeviceIntegrityResult {
  final bool isSecure;
  final bool isRooted;
  final bool isJailbroken;
  final bool hasUnauthorizedProxies;
  final bool hasMockLocation;
  final List<String> threats;
  final DateTime checkedAt;

  DeviceIntegrityResult({
    required this.isSecure,
    required this.isRooted,
    required this.isJailbroken,
    required this.hasUnauthorizedProxies,
    required this.hasMockLocation,
    required this.threats,
    required this.checkedAt,
  });

  String get threatsSummary => threats.isEmpty ? 'Nenhuma ameaça detectada' : threats.join(', ');
}

/// Serviço de detecção de ameaças de integridade do dispositivo
class DeviceIntegrityService {
  static final DeviceIntegrityService _instance =
      DeviceIntegrityService._internal();

  factory DeviceIntegrityService() {
    return _instance;
  }

  DeviceIntegrityService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  Timer? _continuousMonitoring;

  /// Realiza verificação completa de integridade
  Future<DeviceIntegrityResult> checkDeviceIntegrity() async {
    final threats = <String>[];
    bool isRooted = false;
    bool isJailbroken = false;
    bool hasProxies = false;
    bool hasMock = false;

    try {
      // Verificação 1: Root/Jailbreak
      if (SecurityConstants.CHECK_DEVICE_ROOT) {
        final rootCheck = await _checkRootAccess();
        if (rootCheck.isRooted) {
          threats.add('🚨 ROOT DETECTADO: Dispositivo foi enraizado');
          isRooted = true;
        }
        if (rootCheck.isJailbroken) {
          threats.add('🚨 JAILBREAK DETECTADO: iOS foi desbloqueado');
          isJailbroken = true;
        }
      }

      // Verificação 2: Proxies não autorizados
      if (SecurityConstants.CHECK_UNAUTHORIZED_PROXIES) {
        final proxyCheck = await _checkUnauthorizedProxies();
        if (proxyCheck) {
          threats.add('⚠️ PROXY DETECTADO: Proxy interceptador identificado');
          hasProxies = true;
        }
      }

      // Verificação 3: Mock Location
      if (SecurityConstants.CHECK_MOCK_LOCATION) {
        final mockCheck = await _checkMockLocation();
        if (mockCheck) {
          threats.add('⚠️ LOCALIZAÇÃO FALSA: Aplicativo de mock localizado');
          hasMock = true;
        }
      }

      // Verificação 4: Verificações do Sistema
      final systemCheck = await _checkSystemIntegrity();
      threats.addAll(systemCheck);

    } catch (e) {
      threats.add('❌ ERRO NA VERIFICAÇÃO: $e');
    }

    final isSecure = threats.isEmpty;

    return DeviceIntegrityResult(
      isSecure: isSecure,
      isRooted: isRooted,
      isJailbroken: isJailbroken,
      hasUnauthorizedProxies: hasProxies,
      hasMockLocation: hasMock,
      threats: threats,
      checkedAt: DateTime.now(),
    );
  }

  /// Verifica acesso Root (Android) ou Jailbreak (iOS)
  Future<_RootCheckResult> _checkRootAccess() async {
    bool isRooted = false;
    bool isJailbroken = false;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Verificações básicas de root
        isRooted = await _checkAndroidRoot(androidInfo);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Verificações básicas de jailbreak
        isJailbroken = await _checkIOSJailbreak(iosInfo);
      }
    } catch (e) {
      debugPrint('Erro ao verificar root/jailbreak: $e');
    }

    return _RootCheckResult(isRooted, isJailbroken);
  }

  /// Verificações específicas para Android
  Future<bool> _checkAndroidRoot(AndroidDeviceInfo info) async {
    // Verificar se é emulador (potencial risco)
    if (info.isPhysicalDevice == false) {
      return true;
    }

    // Verificar build tags suspeitas
    if ((info.tags ?? '').contains('test-keys')) {
      return true;
    }

    // Verificar se há aplicativos de root conhecidos
    // (Seria necessário verificar diretórios do sistema)
    return false;
  }

  /// Verificações específicas para iOS
  Future<bool> _checkIOSJailbreak(IosDeviceInfo info) async {
    // Verificar se é simulator
    if (info.isPhysicalDevice == false) {
      return true;
    }

    // Verificar modelo do dispositivo
    if (info.model.contains('Simulator')) {
      return true;
    }

    return false;
  }

  /// Verifica proxies não autorizados
  Future<bool> _checkUnauthorizedProxies() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Verificar se há proxy do sistema configurado
        // Seria necessário usar platform channel para acessar
        // ProxyInfo do Android
        return false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Verificação similar para iOS
        return false;
      }
    } catch (e) {
      debugPrint('Erro ao verificar proxies: $e');
    }
    return false;
  }

  /// Verifica if Mock Location está ativado
  Future<bool> _checkMockLocation() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Em Android, existem flags de desenvolvimento que indicam mock location
        // Seria necessário usar platform channel para verificar
        return false;
      }
    } catch (e) {
      debugPrint('Erro ao verificar mock location: $e');
    }
    return false;
  }

  /// Verificações gerais de integridade do sistema
  Future<List<String>> _checkSystemIntegrity() async {
    final threats = <String>[];

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;

        // Verificar versão Android
        if ((androidInfo.version.sdkInt ?? 0) < 26) {
          threats.add('⚠️ VERSÃO DESATUALIZADA: Android SDK < 26 detectado');
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;

        // Verificar versão iOS
        final version = int.tryParse(iosInfo.systemVersion.split('.').first) ?? 0;
        if (version < 13) {
          threats.add('⚠️ VERSÃO DESATUALIZADA: iOS < 13 detectado');
        }
      }
    } catch (e) {
      debugPrint('Erro ao verificar integridade do sistema: $e');
    }

    return threats;
  }

  /// Inicia monitoramento contínuo de integridade
  void startContinuousMonitoring({
    Duration interval = const Duration(minutes: 5),
    Function(DeviceIntegrityResult)? onThreatDetected,
  }) {
    _continuousMonitoring?.cancel();

    _continuousMonitoring = Timer.periodic(interval, (_) async {
      final result = await checkDeviceIntegrity();
      if (!result.isSecure && onThreatDetected != null) {
        onThreatDetected(result);
      }
    });
  }

  /// Para monitoramento contínuo
  void stopContinuousMonitoring() {
    _continuousMonitoring?.cancel();
    _continuousMonitoring = null;
  }

  /// Destruição segura
  void dispose() {
    stopContinuousMonitoring();
  }
}

/// Resultado da verificação de root
class _RootCheckResult {
  final bool isRooted;
  final bool isJailbroken;

  _RootCheckResult(this.isRooted, this.isJailbroken);
}
