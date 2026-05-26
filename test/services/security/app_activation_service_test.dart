import 'package:flutter_test/flutter_test.dart';

import 'package:app_invisivel/services/security/app_activation_service.dart';

void main() {
  group('AppActivationService.validateCode', () {
    test('aceita codigo unico configurado', () async {
      final service = AppActivationService(
        config: const ActivationConfig(
          required: true,
          inviteCodes: ['INV001', 'INV002'],
          totpSecret: '',
        ),
      );

      final result = await service.validateCode('inv-001');

      expect(result.isValid, isTrue);
      expect(result.method, 'invite_code');
    });

    test('aceita TOTP configurado', () async {
      final service = AppActivationService(
        config: const ActivationConfig(
          required: true,
          inviteCodes: [],
          totpSecret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
        ),
      );

      final result = await service.validateCode(
        '287082',
        now: DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true),
      );

      expect(result.isValid, isTrue);
      expect(result.method, 'totp');
    });

    test('rejeita codigo invalido', () async {
      final service = AppActivationService(
        config: const ActivationConfig(
          required: true,
          inviteCodes: ['INV001'],
          totpSecret: '',
        ),
      );

      final result = await service.validateCode('INV999');

      expect(result.isValid, isFalse);
      expect(result.error, 'Codigo invalido ou expirado.');
    });
  });
}