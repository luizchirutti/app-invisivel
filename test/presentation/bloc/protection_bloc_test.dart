import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:app_invisivel/core/errors/failures.dart';
import 'package:app_invisivel/domain/entities/entities.dart';
import 'package:app_invisivel/domain/repositories/repositories.dart';
import 'package:app_invisivel/domain/usecases/protection_usecases.dart';
import 'package:app_invisivel/presentation/bloc/protection_bloc.dart';

class MockProtectionRepository extends Mock implements ProtectionRepository {}

void main() {
  late MockProtectionRepository repository;
  late StartProtectionUseCase startUseCase;
  late StopProtectionUseCase stopUseCase;
  late GetProtectionStatusUseCase statusUseCase;

  late AppConfiguration config;
  late ProtectionStatus activeStatus;
  late ProtectionStatus inactiveStatus;

  setUp(() {
    repository = MockProtectionRepository();
    startUseCase = StartProtectionUseCase(repository);
    stopUseCase = StopProtectionUseCase(repository);
    statusUseCase = GetProtectionStatusUseCase(repository);

    config = AppConfiguration(
      preferredVPNServer: 'us-west-1',
      enableKillSwitch: true,
      enableDoH: true,
      enableAntiFingerprinting: true,
      enableThreatDetection: true,
    );

    activeStatus = ProtectionStatus(
      isVPNActive: true,
      isKillSwitchActive: true,
      dohEnabled: true,
      antiFingerprinting: true,
      threatDetectionActive: true,
      activeThreats: const [],
      lastChecked: DateTime(2026, 4, 24),
      bytesTransferred: 0,
      currentServerLocation: 'Conectado',
    );

    inactiveStatus = ProtectionStatus(
      isVPNActive: false,
      isKillSwitchActive: false,
      dohEnabled: false,
      antiFingerprinting: false,
      threatDetectionActive: false,
      activeThreats: const [],
      lastChecked: DateTime(2026, 4, 24),
      bytesTransferred: 0,
      currentServerLocation: 'Desconectado',
    );
  });

  ProtectionBloc buildBloc() {
    return ProtectionBloc(
      startProtectionUseCase: startUseCase,
      stopProtectionUseCase: stopUseCase,
      getProtectionStatusUseCase: statusUseCase,
    );
  }

  test('estado inicial e ProtectionInitial', () {
    expect(buildBloc().state, const ProtectionInitial());
  });

  blocTest<ProtectionBloc, ProtectionState>(
    'StartProtectionEvent sucesso emite Loading e Active',
    build: () {
      when(() => repository.startProtection(config))
          .thenAnswer((_) async => Right(activeStatus));
      return buildBloc();
    },
    act: (bloc) => bloc.add(StartProtectionEvent(config)),
    expect: () => <ProtectionState>[
      const ProtectionLoading(),
      ProtectionActive(activeStatus),
    ],
    verify: (_) {
      verify(() => repository.startProtection(config)).called(1);
    },
  );

  blocTest<ProtectionBloc, ProtectionState>(
    'StartProtectionEvent falha emite Loading e Error',
    build: () {
      when(() => repository.startProtection(config)).thenAnswer(
        (_) async => Left(VPNConnectionFailure('start failed')),
      );
      return buildBloc();
    },
    act: (bloc) => bloc.add(StartProtectionEvent(config)),
    expect: () => <ProtectionState>[
      const ProtectionLoading(),
      const ProtectionError('start failed'),
    ],
  );

  blocTest<ProtectionBloc, ProtectionState>(
    'StopProtectionEvent sucesso emite Loading e Inactive',
    build: () {
      when(() => repository.stopProtection())
          .thenAnswer((_) async => const Right(null));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const StopProtectionEvent()),
    expect: () => <ProtectionState>[
      const ProtectionLoading(),
      const ProtectionInactive(),
    ],
    verify: (_) {
      verify(() => repository.stopProtection()).called(1);
    },
  );

  blocTest<ProtectionBloc, ProtectionState>(
    'StopProtectionEvent falha emite Loading e Error',
    build: () {
      when(() => repository.stopProtection()).thenAnswer(
        (_) async => Left(VPNConnectionFailure('stop failed')),
      );
      return buildBloc();
    },
    act: (bloc) => bloc.add(const StopProtectionEvent()),
    expect: () => <ProtectionState>[
      const ProtectionLoading(),
      const ProtectionError('stop failed'),
    ],
  );

  blocTest<ProtectionBloc, ProtectionState>(
    'GetStatusEvent com VPN ativa emite Active',
    build: () {
      when(() => repository.getStatus())
          .thenAnswer((_) async => Right(activeStatus));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const GetStatusEvent()),
    expect: () => <ProtectionState>[
      ProtectionActive(activeStatus),
    ],
  );

  blocTest<ProtectionBloc, ProtectionState>(
    'GetStatusEvent com VPN inativa emite Inactive',
    build: () {
      when(() => repository.getStatus())
          .thenAnswer((_) async => Right(inactiveStatus));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const GetStatusEvent()),
    expect: () => <ProtectionState>[
      const ProtectionInactive(),
    ],
  );

  blocTest<ProtectionBloc, ProtectionState>(
    'GetStatusEvent com falha emite Error',
    build: () {
      when(() => repository.getStatus())
          .thenAnswer((_) async => Left(AppFailure('status failed')));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const GetStatusEvent()),
    expect: () => <ProtectionState>[
      const ProtectionError('status failed'),
    ],
  );

  blocTest<ProtectionBloc, ProtectionState>(
    'UpdateStatusEvent ativo emite Active',
    build: buildBloc,
    act: (bloc) => bloc.add(UpdateStatusEvent(activeStatus)),
    expect: () => <ProtectionState>[
      ProtectionActive(activeStatus),
    ],
  );

  blocTest<ProtectionBloc, ProtectionState>(
    'UpdateStatusEvent inativo emite Inactive',
    build: buildBloc,
    act: (bloc) => bloc.add(UpdateStatusEvent(inactiveStatus)),
    expect: () => <ProtectionState>[
      const ProtectionInactive(),
    ],
  );
}
