import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_invisivel/presentation/widgets/protection_widgets.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('ProtectionToggleButton', () {
    testWidgets('renderiza icone inativo e dispara callback ao tocar', (
      tester,
    ) async {
      var toggled = false;

      await tester.pumpWidget(
        _wrap(
          ProtectionToggleButton(
            isActive: false,
            isLoading: false,
            onToggle: () => toggled = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.shield_off), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(toggled, isTrue);
    });

    testWidgets('renderiza loading e desabilita clique quando isLoading=true', (
      tester,
    ) async {
      var toggled = false;

      await tester.pumpWidget(
        _wrap(
          ProtectionToggleButton(
            isActive: true,
            isLoading: true,
            onToggle: () => toggled = true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Icon), findsNothing);

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNull);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(toggled, isFalse);
    });
  });

  group('ProtectionStatusCard', () {
    testWidgets('exibe indicadores e estado seguro quando risco=0', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ProtectionStatusCard(
            isVPNActive: true,
            isKillSwitchActive: true,
            dohEnabled: true,
            antiFingerprinting: true,
            riskLevel: 0,
            threatsSummary: '',
          ),
        ),
      );

      expect(find.text('Status de Proteção'), findsOneWidget);
      expect(find.text('✅ Seguro'), findsOneWidget);
      expect(find.text('VPN'), findsOneWidget);
      expect(find.text('Kill Switch'), findsOneWidget);
      expect(find.text('DNS Seguro (DoH)'), findsOneWidget);
      expect(find.text('Anti-Fingerprinting'), findsOneWidget);
      expect(find.text('Ameaças Detectadas:'), findsNothing);
    });

    testWidgets('exibe ameaças e label crítico quando risco alto', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ProtectionStatusCard(
            isVPNActive: false,
            isKillSwitchActive: false,
            dohEnabled: false,
            antiFingerprinting: false,
            riskLevel: 90,
            threatsSummary: 'ROOT_DETECTED, PROXY_DETECTED',
          ),
        ),
      );

      expect(find.text('🚨 Crítico'), findsOneWidget);
      expect(find.text('Ameaças Detectadas:'), findsOneWidget);
      expect(find.text('ROOT_DETECTED, PROXY_DETECTED'), findsOneWidget);
    });
  });

  group('ConnectionLogWidget', () {
    testWidgets('mostra placeholder quando lista vazia', (tester) async {
      await tester.pumpWidget(
        _wrap(const ConnectionLogWidget(logEntries: <String>[])),
      );

      expect(find.text('Log de Conexões em Tempo Real'), findsOneWidget);
      expect(find.text('Aguardando conexões...'), findsOneWidget);
    });

    testWidgets('mostra entradas de log em ordem reversa', (tester) async {
      const logs = <String>[
        '[10:00:00] first',
        '[10:00:01] second',
        '[10:00:02] third',
      ];

      await tester.pumpWidget(
        _wrap(const ConnectionLogWidget(logEntries: logs)),
      );

      expect(find.text('[10:00:02] third'), findsOneWidget);
      expect(find.text('[10:00:01] second'), findsOneWidget);
      expect(find.text('[10:00:00] first'), findsOneWidget);

      final thirdTop = tester.getTopLeft(find.text('[10:00:02] third')).dy;
      final firstTop = tester.getTopLeft(find.text('[10:00:00] first')).dy;
      expect(thirdTop < firstTop, isTrue);
    });
  });
}
