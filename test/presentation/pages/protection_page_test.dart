import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:app_invisivel/domain/entities/entities.dart';
import 'package:app_invisivel/presentation/bloc/protection_bloc.dart';
import 'package:app_invisivel/presentation/pages/protection_page.dart';

class MockProtectionBloc extends MockBloc<ProtectionEvent, ProtectionState>
    implements ProtectionBloc {}

class FakeProtectionEvent extends Fake implements ProtectionEvent {}

class FakeProtectionState extends Fake implements ProtectionState {}

Widget _wrapWithBloc(ProtectionBloc bloc) {
  return MaterialApp(
    home: BlocProvider<ProtectionBloc>.value(
      value: bloc,
      child: const ProtectionPage(),
    ),
  );
}

ProtectionStatus _activeStatus() {
  return ProtectionStatus(
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
}

void main() {
  late MockProtectionBloc bloc;

  setUpAll(() {
    registerFallbackValue(FakeProtectionEvent());
    registerFallbackValue(FakeProtectionState());
  });

  setUp(() {
    bloc = MockProtectionBloc();
    when(() => bloc.add(any())).thenReturn(null);
  });

  testWidgets('dispara GetStatusEvent no initState', (tester) async {
    when(() => bloc.state).thenReturn(const ProtectionInitial());
    whenListen(bloc, Stream<ProtectionState>.empty());

    await tester.pumpWidget(_wrapWithBloc(bloc));

    verify(
      () => bloc.add(any(that: isA<GetStatusEvent>())),
    ).called(1);
  });

  testWidgets('renderiza estrutura base da pagina', (tester) async {
    when(() => bloc.state).thenReturn(const ProtectionInactive());
    whenListen(bloc, const Stream<ProtectionState>.empty());

    await tester.pumpWidget(_wrapWithBloc(bloc));

    expect(find.text('App Invisível'), findsOneWidget);
    expect(find.text('Status de Proteção'), findsOneWidget);
    expect(find.text('Log de Conexões em Tempo Real'), findsOneWidget);
    expect(find.text('ℹ️ Informações'), findsOneWidget);
  });

  testWidgets('estado de erro renderiza card com mensagem', (tester) async {
    const errorMessage = 'Falha ao conectar VPN';

    when(() => bloc.state).thenReturn(const ProtectionError(errorMessage));
    whenListen(bloc, const Stream<ProtectionState>.empty());

    await tester.pumpWidget(_wrapWithBloc(bloc));

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text(errorMessage), findsOneWidget);
  });

  testWidgets('estado loading mostra indicador de progresso', (tester) async {
    when(() => bloc.state).thenReturn(const ProtectionLoading());
    whenListen(bloc, const Stream<ProtectionState>.empty());

    await tester.pumpWidget(_wrapWithBloc(bloc));

    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('tap no toggle em estado inativo dispara StartProtectionEvent', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ProtectionInactive());
    whenListen(bloc, const Stream<ProtectionState>.empty());

    await tester.pumpWidget(_wrapWithBloc(bloc));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    verify(
      () => bloc.add(any(that: isA<StartProtectionEvent>())),
    ).called(1);
  });

  testWidgets('tap no toggle em estado ativo dispara StopProtectionEvent', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(ProtectionActive(_activeStatus()));
    whenListen(bloc, const Stream<ProtectionState>.empty());

    await tester.pumpWidget(_wrapWithBloc(bloc));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    verify(
      () => bloc.add(any(that: isA<StopProtectionEvent>())),
    ).called(1);
  });

  testWidgets('listener adiciona log quando estado muda para ativo', (tester) async {
    when(() => bloc.state).thenReturn(const ProtectionInactive());
    whenListen(
      bloc,
      Stream<ProtectionState>.fromIterable([
        ProtectionActive(_activeStatus()),
      ]),
    );

    await tester.pumpWidget(_wrapWithBloc(bloc));
    await tester.pump();

    expect(find.textContaining('VPN Conectada'), findsOneWidget);
  });

  testWidgets('listener adiciona log quando estado muda para erro', (tester) async {
    when(() => bloc.state).thenReturn(const ProtectionInactive());
    whenListen(
      bloc,
      const Stream<ProtectionState>.fromIterable([
        ProtectionError('erro de teste'),
      ]),
    );

    await tester.pumpWidget(_wrapWithBloc(bloc));
    await tester.pump();

    expect(find.textContaining('Erro: erro de teste'), findsOneWidget);
  });
}
