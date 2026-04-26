import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../lib/core/errors/failures.dart';
import '../../../lib/data/repositories/protection_repository_impl.dart';
import '../../../lib/domain/entities/entities.dart';
import '../../../lib/security/anti_fingerprinting/anti_fingerprinter_service.dart';
import '../../../lib/security/device_integrity/device_integrity_service.dart';
import '../../../lib/services/doh/doh_service.dart';
import '../../../lib/services/platform/unified_vpn_service.dart';

class MockUnifiedVPNService extends Mock implements UnifiedVPNService {}

class MockDoHService extends Mock implements DoHService {}

class MockDeviceIntegrityService extends Mock implements DeviceIntegrityService {}

class MockAntiFingerprinterService extends Mock
    implements AntiFingerprinterService {}

void main() {
  late MockUnifiedVPNService vpnService;
  late MockDoHService dohService;
  late MockDeviceIntegrityService integrityService;
  late MockAntiFingerprinterService antiFingerprinterService;
  late ProtectionRepositoryImpl repository;

  DeviceIntegrityResult secureIntegrityResult() {
    return DeviceIntegrityResult(
      isSecure: true,
      isRooted: false,
      isJailbroken: false,
      hasUnauthorizedProxies: false,
      hasMockLocation: false,
      threats: const [],
      checkedAt: DateTime.now(),
    );
  }

  DeviceIntegrityResult insecureIntegrityResult() {
    return DeviceIntegrityResult(
      isSecure: false,
      isRooted: true,
      isJailbroken: false,
      hasUnauthorizedProxies: false,
      hasMockLocation: false,
      threats: const ['ROOT_DETECTED'],
      checkedAt: DateTime.now(),
    );
  }

  final config = AppConfiguration(
    preferredVPNServer: 'us-west-1',
    enableKillSwitch: true,
    enableDoH: true,
    enableAntiFingerprinting: true,
    enableThreatDetection: true,
  );

  setUp(() {
    vpnService = MockUnifiedVPNService();
    dohService = MockDoHService();
    integrityService = MockDeviceIntegrityService();
    antiFingerprinterService = MockAntiFingerprinterService();

    repository = ProtectionRepositoryImpl(
      vpnService: vpnService,
      dohService: dohService,
      integrityService: integrityService,
      antiFingerprinterService: antiFingerprinterService,
    );

    when(() => dohService.enforceDoHForDioRequests()).thenReturn(null);
  });

  group('startProtection', () {
    test('retorna status ativo quando tudo ocorre com sucesso', () async {
      when(() => integrityService.checkDeviceIntegrity())
          .thenAnswer((_) async => secureIntegrityResult());
      when(
        () => vpnService.connect(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenAnswer((_) async => const Right(null));
      when(() => vpnService.setKillSwitch(true))
          .thenAnswer((_) async => const Right(null));

      final result = await repository.startProtection(config);

      expect(result.isRight(), isTrue);
      final status = result.getOrElse(
        () => throw StateError('Esperava status de sucesso'),
      );
      expect(status.isVPNActive, isTrue);
      expect(status.isKillSwitchActive, isTrue);
      expect(status.dohEnabled, isTrue);

      verify(() => integrityService.checkDeviceIntegrity()).called(1);
      verify(
        () => vpnService.connect(
          'us-west-1',
          51820,
          any(),
          any(),
          any(),
          '10.0.0.2',
          '1.1.1.1,1.0.0.1',
        ),
      ).called(1);
      verify(() => vpnService.setKillSwitch(true)).called(1);
      verify(() => dohService.enforceDoHForDioRequests()).called(1);
    });

    test('retorna IntegrityFailure quando dispositivo nao e seguro', () async {
      when(() => integrityService.checkDeviceIntegrity())
          .thenAnswer((_) async => insecureIntegrityResult());

      final result = await repository.startProtection(config);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<IntegrityFailure>()),
        (_) => fail('Esperava falha de integridade'),
      );

      verify(() => integrityService.checkDeviceIntegrity()).called(1);
      verifyNever(
        () => vpnService.connect(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      );
      verifyNever(() => dohService.enforceDoHForDioRequests());
    });

    test('retorna falha quando connect da VPN falha', () async {
      when(() => integrityService.checkDeviceIntegrity())
          .thenAnswer((_) async => secureIntegrityResult());
      when(
        () => vpnService.connect(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenAnswer((_) async => Left(VPNConnectionFailure('connect error')));

      final result = await repository.startProtection(config);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<VPNConnectionFailure>()),
        (_) => fail('Esperava falha da VPN'),
      );

      verifyNever(() => vpnService.setKillSwitch(true));
      verifyNever(() => dohService.enforceDoHForDioRequests());
    });

    test('retorna falha quando kill switch falha', () async {
      when(() => integrityService.checkDeviceIntegrity())
          .thenAnswer((_) async => secureIntegrityResult());
      when(
        () => vpnService.connect(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenAnswer((_) async => const Right(null));
      when(() => vpnService.setKillSwitch(true)).thenAnswer(
        (_) async => Left(VPNConnectionFailure('ks error')),
      );

      final result = await repository.startProtection(config);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<VPNConnectionFailure>()),
        (_) => fail('Esperava falha no kill switch'),
      );
      verifyNever(() => dohService.enforceDoHForDioRequests());
    });
  });

  group('stopProtection', () {
    test('retorna Right quando desconecta com sucesso', () async {
      when(() => vpnService.disconnect()).thenAnswer((_) async => const Right(null));

      final result = await repository.stopProtection();

      expect(result.isRight(), isTrue);
      verify(() => vpnService.disconnect()).called(1);
    });

    test('propaga falha quando disconnect falha', () async {
      when(() => vpnService.disconnect())
          .thenAnswer((_) async => Left(VPNConnectionFailure('disconnect error')));

      final result = await repository.stopProtection();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<VPNConnectionFailure>()),
        (_) => fail('Esperava falha de disconnect'),
      );
    });
  });

  group('getStatus', () {
    test('retorna ProtectionStatus conectado quando VPN conectada', () async {
      when(() => integrityService.checkDeviceIntegrity())
          .thenAnswer((_) async => secureIntegrityResult());
      when(() => vpnService.getStatus()).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'isConnected': true,
          'status': 'CONNECTED',
        }),
      );

      final result = await repository.getStatus();

      expect(result.isRight(), isTrue);
      final status = result.getOrElse(
        () => throw StateError('Esperava status de sucesso'),
      );
      expect(status.isVPNActive, isTrue);
      expect(status.isKillSwitchActive, isTrue);
      expect(status.currentServerLocation, 'Conectado');
    });

    test('retorna Left quando getStatus da VPN falha', () async {
      when(() => integrityService.checkDeviceIntegrity())
          .thenAnswer((_) async => secureIntegrityResult());
      when(() => vpnService.getStatus())
          .thenAnswer((_) async => Left(AppFailure('status error')));

      final result = await repository.getStatus();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<AppFailure>()),
        (_) => fail('Esperava falha de status'),
      );
    });
  });
}
