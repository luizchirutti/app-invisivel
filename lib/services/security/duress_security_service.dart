import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../security/encryption/crypto_manager.dart';
import '../logging/secure_logging_service.dart';

/// Serviço de senha de coação para reset local seguro dentro do app.
class DuressSecurityService {
  static const String _duressPinHashKey = 'duress_pin_hash';
  static const String _duressEnabledKey = 'duress_pin_enabled';

  static final DuressSecurityService _instance = DuressSecurityService._internal();

  factory DuressSecurityService() => _instance;

  DuressSecurityService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

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