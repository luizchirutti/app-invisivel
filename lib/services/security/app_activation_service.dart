import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ActivationConfig {
  final bool required;
  final List<String> inviteCodes;
  final String totpSecret;
  final int totpPeriodSeconds;
  final int totpDigits;
  final int totpWindow;

  const ActivationConfig({
    required this.required,
    required this.inviteCodes,
    required this.totpSecret,
    this.totpPeriodSeconds = 30,
    this.totpDigits = 6,
    this.totpWindow = 1,
  });

  factory ActivationConfig.fromEnvironment() {
    final inviteCodes = const String.fromEnvironment('APP_ACTIVATION_CODES')
        .split(',')
        .map((code) => normalizeActivationCode(code))
        .where((code) => code.isNotEmpty)
        .toList(growable: false);
    final totpSecret = normalizeActivationCode(
      const String.fromEnvironment('APP_ACTIVATION_TOTP_SECRET'),
    );
    final required = const String.fromEnvironment(
          'APP_ACTIVATION_REQUIRED',
          defaultValue: 'false',
        ) ==
        'true';
    final period = int.tryParse(
          const String.fromEnvironment('APP_ACTIVATION_TOTP_PERIOD', defaultValue: '30'),
        ) ??
        30;
    final digits = int.tryParse(
          const String.fromEnvironment('APP_ACTIVATION_TOTP_DIGITS', defaultValue: '6'),
        ) ??
        6;
    final window = int.tryParse(
          const String.fromEnvironment('APP_ACTIVATION_TOTP_WINDOW', defaultValue: '1'),
        ) ??
        1;

    return ActivationConfig(
      required: required,
      inviteCodes: inviteCodes,
      totpSecret: totpSecret,
      totpPeriodSeconds: period,
      totpDigits: digits,
      totpWindow: window,
    );
  }

  bool get hasValidationMethod => inviteCodes.isNotEmpty || totpSecret.isNotEmpty;

  bool get isEnforced => required || hasValidationMethod;

  String get hintText {
    if (inviteCodes.isNotEmpty && totpSecret.isNotEmpty) {
      return 'Use um codigo unico ou o codigo do authenticator.';
    }
    if (totpSecret.isNotEmpty) {
      return 'Use o codigo atual do authenticator.';
    }
    return 'Use o codigo de ativacao liberado para esta instalacao.';
  }
}

class ActivationResult {
  final bool isValid;
  final String? method;
  final String? error;

  const ActivationResult._({required this.isValid, this.method, this.error});

  const ActivationResult.success(String method)
      : this._(isValid: true, method: method);

  const ActivationResult.failure(String error)
      : this._(isValid: false, error: error);
}

class AppActivationService {
  static const String _activatedKey = 'app_activation_completed';
  static const String _activatedAtKey = 'app_activation_completed_at';
  static const String _activationMethodKey = 'app_activation_method';

  final FlutterSecureStorage _secureStorage;
  final ActivationConfig config;

  AppActivationService({
    FlutterSecureStorage? secureStorage,
    ActivationConfig? config,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        config = config ?? ActivationConfig.fromEnvironment();

  bool get isActivationRequired => config.isEnforced;

  String get activationHint => config.hintText;

  Future<bool> isActivated() async {
    if (!isActivationRequired) return true;
    final value = await _secureStorage.read(key: _activatedKey);
    return value == 'true';
  }

  Future<ActivationResult> validateCode(
    String input, {
    DateTime? now,
  }) async {
    if (!isActivationRequired) {
      return const ActivationResult.success('not_required');
    }

    final normalizedInput = normalizeActivationCode(input);
    if (normalizedInput.isEmpty) {
      return const ActivationResult.failure('Informe um codigo valido.');
    }

    if (config.inviteCodes.contains(normalizedInput)) {
      return const ActivationResult.success('invite_code');
    }

    if (config.totpSecret.isNotEmpty && _isValidTotp(normalizedInput, now: now)) {
      return const ActivationResult.success('totp');
    }

    return const ActivationResult.failure('Codigo invalido ou expirado.');
  }

  Future<ActivationResult> activate(
    String input, {
    DateTime? now,
  }) async {
    final result = await validateCode(input, now: now);
    if (!result.isValid) {
      return result;
    }

    await _secureStorage.write(key: _activatedKey, value: 'true');
    await _secureStorage.write(
      key: _activatedAtKey,
      value: (now ?? DateTime.now()).toUtc().toIso8601String(),
    );
    await _secureStorage.write(key: _activationMethodKey, value: result.method);
    return result;
  }

  Future<void> resetActivation() async {
    await _secureStorage.delete(key: _activatedKey);
    await _secureStorage.delete(key: _activatedAtKey);
    await _secureStorage.delete(key: _activationMethodKey);
  }

  bool _isValidTotp(String input, {DateTime? now}) {
    if (config.totpSecret.isEmpty) {
      return false;
    }

    final digitsOnlyInput = input.replaceAll(RegExp(r'\D'), '');
    if (digitsOnlyInput.length != config.totpDigits) {
      return false;
    }

    final secretBytes = _decodeBase32(config.totpSecret);
    final currentTime = now ?? DateTime.now();
    final counter = currentTime.toUtc().millisecondsSinceEpoch ~/
        1000 ~/
        config.totpPeriodSeconds;

    for (var offset = -config.totpWindow; offset <= config.totpWindow; offset++) {
      final code = _generateTotp(secretBytes, counter + offset);
      if (code == digitsOnlyInput) {
        return true;
      }
    }

    return false;
  }

  String _generateTotp(List<int> secretBytes, int counter) {
    final byteData = List<int>.filled(8, 0);
    var remainingCounter = counter;
    for (var index = 7; index >= 0; index--) {
      byteData[index] = remainingCounter & 0xff;
      remainingCounter = remainingCounter >> 8;
    }

    final digest = Hmac(sha1, secretBytes).convert(byteData).bytes;
    final offset = digest.last & 0x0f;
    final binary = ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);
    final modulo = _pow10(config.totpDigits);
    final otp = binary % modulo;

    return otp.toString().padLeft(config.totpDigits, '0');
  }

  List<int> _decodeBase32(String value) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final sanitized = value.replaceAll('=', '');
    final output = <int>[];
    var buffer = 0;
    var bitsLeft = 0;

    for (final rune in sanitized.runes) {
      final character = String.fromCharCode(rune);
      final index = alphabet.indexOf(character);
      if (index < 0) {
        throw const FormatException('APP_ACTIVATION_TOTP_SECRET invalido.');
      }
      buffer = (buffer << 5) | index;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        output.add((buffer >> (bitsLeft - 8)) & 0xff);
        bitsLeft -= 8;
      }
    }

    return output;
  }

  int _pow10(int exponent) {
    var result = 1;
    for (var index = 0; index < exponent; index++) {
      result *= 10;
    }
    return result;
  }
}

String normalizeActivationCode(String value) {
  return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
}