import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

  testWidgets('renderiza header principal', (tester) async {
    when(() => bloc.state).thenReturn(const ProtectionInactive());
    whenListen(bloc, const Stream<ProtectionState>.empty());

    await tester.pumpWidget(_wrapWithBloc(bloc));
    await tester.pumpAndSettle();

    expect(find.text('App Invisível'), findsOneWidget);
    expect(find.byIcon(Icons.privacy_tip_rounded), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
  });
}
