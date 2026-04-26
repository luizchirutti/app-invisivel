import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:app_invisivel/core/errors/failures.dart';
import 'package:app_invisivel/domain/entities/entities.dart';
import 'package:app_invisivel/domain/repositories/repositories.dart';
import 'package:app_invisivel/domain/usecases/protection_usecases.dart';

class MockProtectionRepository extends Mock implements ProtectionRepository {}

class MockConfigurationRepository extends Mock
    implements ConfigurationRepository {}

class MockLogRepository extends Mock implements LogRepository {}

void main() {
  late MockProtectionRepository protectionRepository;
  late MockConfigurationRepository configurationRepository;
  late MockLogRepository logRepository;

  late AppConfiguration config;
  late ProtectionStatus protectionStatus;

  setUp(() {
    protectionRepository = MockProtectionRepository();
    configurationRepository = MockConfigurationRepository();
    logRepository = MockLogRepository();

    config = AppConfiguration(
      preferredVPNServer: 'us-west-1',
      preferredDohServer: 'https://1.1.1.1/dns-query',
      enableKillSwitch: true,
      enableDoH: true,
    );

    protectionStatus = ProtectionStatus(
      isVPNActive: true,
      isKillSwitchActive: true,
      dohEnabled: true,
      antiFingerprinting: true,
      threatDetectionActive: true,
      activeThreats: const [],
      lastChecked: DateTime(2026, 4, 24),
      bytesTransferred: 1234,
      currentServerLocation: 'Conectado',
    );
  });

  group('StartProtectionUseCase', () {
    test('deve delegar para repository.startProtection e retornar sucesso', () async {
      final useCase = StartProtectionUseCase(protectionRepository);
      when(() => protectionRepository.startProtection(config))
          .thenAnswer((_) async => Right(protectionStatus));

      final result = await useCase(config);

      expect(result, Right<Failure, ProtectionStatus>(protectionStatus));
      verify(() => protectionRepository.startProtection(config)).called(1);
      verifyNoMoreInteractions(protectionRepository);
    });

    test('deve propagar falha do repositório', () async {
      final useCase = StartProtectionUseCase(protectionRepository);
      when(() => protectionRepository.startProtection(config)).thenAnswer(
        (_) async => Left(VPNConnectionFailure('start failed')),
      );

      final result = await useCase(config);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, 'start failed'),
        (_) => fail('Esperava falha'),
      );
    });
  });

  group('StopProtectionUseCase', () {
    test('deve delegar para repository.stopProtection', () async {
      final useCase = StopProtectionUseCase(protectionRepository);
      when(() => protectionRepository.stopProtection())
          .thenAnswer((_) async => const Right(null));

      final result = await useCase();

      expect(result, const Right<Failure, void>(null));
      verify(() => protectionRepository.stopProtection()).called(1);
      verifyNoMoreInteractions(protectionRepository);
    });
  });

  group('GetProtectionStatusUseCase', () {
    test('deve delegar para repository.getStatus', () async {
      final useCase = GetProtectionStatusUseCase(protectionRepository);
      when(() => protectionRepository.getStatus())
          .thenAnswer((_) async => Right(protectionStatus));

      final result = await useCase();

      expect(result, Right<Failure, ProtectionStatus>(protectionStatus));
      verify(() => protectionRepository.getStatus()).called(1);
      verifyNoMoreInteractions(protectionRepository);
    });
  });

  group('LoadConfigurationUseCase', () {
    test('deve delegar para configuration repository', () async {
      final useCase = LoadConfigurationUseCase(configurationRepository);
      when(() => configurationRepository.loadConfiguration())
          .thenAnswer((_) async => Right(config));

      final result = await useCase();

      expect(result, Right<Failure, AppConfiguration>(config));
      verify(() => configurationRepository.loadConfiguration()).called(1);
      verifyNoMoreInteractions(configurationRepository);
    });
  });

  group('SaveConfigurationUseCase', () {
    test('deve delegar para saveConfiguration', () async {
      final useCase = SaveConfigurationUseCase(configurationRepository);
      when(() => configurationRepository.saveConfiguration(config))
          .thenAnswer((_) async => const Right(null));

      final result = await useCase(config);

      expect(result, const Right<Failure, void>(null));
      verify(() => configurationRepository.saveConfiguration(config)).called(1);
      verifyNoMoreInteractions(configurationRepository);
    });
  });

  group('GetRecentLogsUseCase', () {
    test('deve delegar para getRecentLogs', () {
      final useCase = GetRecentLogsUseCase(logRepository);
      when(() => logRepository.getRecentLogs(50))
          .thenReturn(const Right(<String>['log1', 'log2']));

      final result = useCase(50);

      expect(result, const Right<Failure, List<String>>(<String>['log1', 'log2']));
      verify(() => logRepository.getRecentLogs(50)).called(1);
      verifyNoMoreInteractions(logRepository);
    });
  });

  group('ExportLogsUseCase', () {
    test('deve delegar para exportLogs', () async {
      final useCase = ExportLogsUseCase(logRepository);
      when(() => logRepository.exportLogs())
          .thenAnswer((_) async => const Right('encrypted-logs-content'));

      final result = await useCase();

      expect(result, const Right<Failure, String>('encrypted-logs-content'));
      verify(() => logRepository.exportLogs()).called(1);
      verifyNoMoreInteractions(logRepository);
    });

    test('deve propagar falha ao exportar logs', () async {
      final useCase = ExportLogsUseCase(logRepository);
      when(() => logRepository.exportLogs())
          .thenAnswer((_) async => Left(AppFailure('export failed')));

      final result = await useCase();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, 'export failed'),
        (_) => fail('Esperava falha'),
      );
    });
  });
}
