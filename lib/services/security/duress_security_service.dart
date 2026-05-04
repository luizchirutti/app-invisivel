import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../security/encryption/crypto_manager.dart';
import '../logging/secure_logging_service.dart';

/// Serviço de senha de coação com suporte a reset de fábrica via Device Admin.
class DuressSecurityService {
  static const String _duressPinHashKey = 'duress_pin_hash';
  static const String _duressEnabledKey = 'duress_pin_enabled';
  static const String _unlockPinHashKey = 'safety_unlock_pin_hash';
  static const String _safetyModeEnabledKey = 'safety_mode_enabled';
  static const MethodChannel _duressChannel = MethodChannel('com.infinityprox/duress');

  static final DuressSecurityService _instance = DuressSecurityService._internal();

  factory DuressSecurityService() => _instance;

  DuressSecurityService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> _syncNativeSafetyFlags() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final safetyModeEnabled = await isSafetyModeEnabled();
      final unlockPinConfigured = await isUnlockPinConfigured();
      await _duressChannel.invokeMethod('setNativeSafetyFlags', {
        'safetyModeEnabled': safetyModeEnabled,
        'unlockPinConfigured': unlockPinConfigured,
      });
    } catch (_) {}
  }

  Future<void> ensureNativeSafetyFlagsSynced() async {
    await _syncNativeSafetyFlags();
  }

  Future<void> saveDuressPin(String pin) async {
    final hash = SecureStorageManager.hashPassword(pin);
    await _secureStorage.write(key: _duressPinHashKey, value: hash);
    await _secureStorage.write(key: _duressEnabledKey, value: 'true');
  }

  Future<bool> isDuressPinConfigured() async {
    final enabled = await _secureStorage.read(key: _duressEnabledKey);
    final hash = await _secureStorage.read(key: _duressPinHashKey);
    return enabled == 'true' && hash != null && hash.isNotEmpty;
  }

  Future<bool> verifyDuressPin(String pin) async {
    final hash = await _secureStorage.read(key: _duressPinHashKey);
    if (hash == null || hash.isEmpty) {
      return false;
    }
    return SecureStorageManager.verifyPassword(pin, hash);
  }

  Future<void> disableDuressPin() async {
    await _secureStorage.delete(key: _duressPinHashKey);
    await _secureStorage.delete(key: _duressEnabledKey);
  }

  Future<void> saveUnlockPin(String pin) async {
    final hash = SecureStorageManager.hashPassword(pin);
    await _secureStorage.write(key: _unlockPinHashKey, value: hash);
    await _syncNativeSafetyFlags();
  }

  Future<bool> isUnlockPinConfigured() async {
    final hash = await _secureStorage.read(key: _unlockPinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<bool> verifyUnlockPin(String pin) async {
    final hash = await _secureStorage.read(key: _unlockPinHashKey);
    if (hash == null || hash.isEmpty) {
      return false;
    }
    return SecureStorageManager.verifyPassword(pin, hash);
  }

  Future<void> disableUnlockPin() async {
    await _secureStorage.delete(key: _unlockPinHashKey);
    await _syncNativeSafetyFlags();
  }

  Future<void> setSafetyModeEnabled(bool enabled) async {
    await _secureStorage.write(key: _safetyModeEnabledKey, value: enabled ? 'true' : 'false');
    await _syncNativeSafetyFlags();
  }

  Future<bool> isSafetyModeEnabled() async {
    final value = await _secureStorage.read(key: _safetyModeEnabledKey);
    return value == 'true';
  }

  Future<void> executeLocalSecurityReset() async {
    final logger = SecureLoggingService();
    await logger.initialize();
    await logger.critical(
      'Senha de coacao acionada. Iniciando hard reset local de seguranca.',
      'DuressReset',
    );

    await logger.clearLogs();
    await _secureStorage.deleteAll();

    if (kIsWeb) {
      return;
    }

    final dirs = await _candidateDirectories();
    for (final dir in dirs) {
      await _deleteDirectoryChildren(dir);
    }
  }

  /// Tenta executar reset de fábrica via Device Admin (Android).
  /// Retorna true se acionado, false se Device Admin não está ativo.
  Future<bool> performFactoryReset() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final result = await _duressChannel.invokeMethod<bool>('performFactoryReset');
      return result == true;
    } on PlatformException catch (e) {
      if (e.code == 'NOT_DEVICE_ADMIN') {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> isDeviceAdminActive() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final result = await _duressChannel.invokeMethod<bool>('isDeviceAdminActive');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestDeviceAdmin() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _duressChannel.invokeMethod('requestDeviceAdmin');
    } catch (_) {}
  }

  Future<bool> isFullScreenIntentPermissionGranted() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final result = await _duressChannel.invokeMethod<bool>('isFullScreenIntentPermissionGranted');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> openFullScreenIntentSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _duressChannel.invokeMethod('openFullScreenIntentSettings');
    } catch (_) {}
  }

  Future<void> startLockEnforcementService() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _duressChannel.invokeMethod('startLockEnforcementService');
    } catch (_) {}
  }

  Future<void> stopLockEnforcementService() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _duressChannel.invokeMethod('stopLockEnforcementService');
    } catch (_) {}
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final result = await _duressChannel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _duressChannel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  Future<void> setPendingUnlockEnforcement(bool pending) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _duressChannel.invokeMethod('setPendingUnlockEnforcement', {
        'pending': pending,
      });
    } catch (_) {}
  }

  Future<List<Directory>> _candidateDirectories() async {
    final dirs = <Directory>[];
    try {
      dirs.add(await getApplicationDocumentsDirectory());
    } catch (_) {}
    try {
      dirs.add(await getApplicationSupportDirectory());
    } catch (_) {}
    try {
      dirs.add(await getTemporaryDirectory());
    } catch (_) {}
    return dirs;
  }

  Future<void> _deleteDirectoryChildren(Directory directory) async {
    if (!await directory.exists()) return;

    final entities = directory.list(recursive: false, followLinks: false);
    await for (final entity in entities) {
      try {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      } catch (_) {
        // Mantem o reset resiliente mesmo se algum arquivo estiver bloqueado.
      }
    }
  }
}