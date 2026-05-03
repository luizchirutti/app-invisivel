import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String relativePath) {
  final file = File(relativePath);
  expect(file.existsSync(), isTrue, reason: 'Arquivo obrigatorio ausente: $relativePath');
  return file.readAsStringSync();
}

void main() {
  group('Preflight maximo de seguranca', () {
    test('AndroidManifest contem permissoes e gatilhos criticos', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');

      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.USE_FULL_SCREEN_INTENT'));
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
      expect(manifest, contains('android:directBootAware="true"'));
      expect(manifest, contains('android.intent.action.USER_PRESENT'));
      expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
      expect(manifest, contains('android.intent.action.LOCKED_BOOT_COMPLETED'));
      expect(manifest, contains('android.intent.action.MY_PACKAGE_REPLACED'));
      expect(manifest, contains('android.intent.action.USER_UNLOCKED'));
      expect(manifest, contains('android.intent.action.SCREEN_ON'));
    });

    test('UnlockLaunchReceiver usa estrategia agressiva de reentrada', () {
      final receiver = _read('android/app/src/main/kotlin/com/infinityprox/UnlockLaunchReceiver.kt');

      expect(receiver, contains('context.startActivity(launchIntent)'));
      expect(receiver, contains('.setFullScreenIntent(pendingIntent, true)'));
      expect(receiver, contains('.setOngoing(true)'));
      expect(receiver, contains('Intent.ACTION_USER_PRESENT'));
      expect(receiver, contains('Intent.ACTION_BOOT_COMPLETED'));
      expect(receiver, contains('Intent.ACTION_LOCKED_BOOT_COMPLETED'));
      expect(receiver, contains('Intent.ACTION_MY_PACKAGE_REPLACED'));
      expect(receiver, contains('Intent.ACTION_USER_UNLOCKED'));
      expect(receiver, contains('Intent.ACTION_SCREEN_ON'));
    });

    test('MainActivity contem guardas de lockscreen e full-screen intent', () {
      final mainActivity = _read('android/app/src/main/kotlin/com/infinityprox/MainActivity.kt');

      expect(mainActivity, contains('setShowWhenLocked(true)'));
      expect(mainActivity, contains('setTurnScreenOn(true)'));
      expect(mainActivity, contains('FLAG_SHOW_WHEN_LOCKED'));
      expect(mainActivity, contains('isFullScreenIntentPermissionGranted'));
      expect(mainActivity, contains('canUseFullScreenIntent()'));
      expect(mainActivity, contains('openFullScreenIntentSettings'));
      expect(mainActivity, contains('ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT'));
    });

    test('Security gate trava imediatamente em background e resume', () {
      final gate = _read('lib/presentation/widgets/security_mode_gate.dart');

      expect(gate, contains('case AppLifecycleState.paused:'));
      expect(gate, contains('case AppLifecycleState.resumed:'));
      expect(gate, contains('_lockNow();'));
      expect(gate, contains('_enforceGateFromStorage(lockIfEnabled: true);'));
      expect(gate, contains('Verificando seguranca...'));
    });

    test('ProtectionPage valida permissoes criticas no modo seguranca', () {
      final page = _read('lib/presentation/pages/protection_page.dart');

      expect(page, contains('_ensureCriticalSafetyPermissions'));
      expect(page, contains('Permission.notification.request()'));
      expect(page, contains('openAppSettings()'));
      expect(page, contains('openFullScreenIntentSettings'));
      expect(page, contains('Permissoes criticas ausentes'));
    });

    test('iOS aplica blindagem visual no background e remove no active', () {
      final appDelegate = _read('ios/Runner/AppDelegate.swift');
      final sceneDelegate = _read('ios/Runner/SceneDelegate.swift');

      expect(appDelegate, contains('applicationWillResignActive'));
      expect(appDelegate, contains('applicationDidEnterBackground'));
      expect(appDelegate, contains('applicationDidBecomeActive'));
      expect(appDelegate, contains('applyPrivacyShield'));
      expect(appDelegate, contains('removePrivacyShield'));

      expect(sceneDelegate, contains('sceneWillResignActive'));
      expect(sceneDelegate, contains('sceneDidEnterBackground'));
      expect(sceneDelegate, contains('sceneDidBecomeActive'));
      expect(sceneDelegate, contains('applyPrivacyShield'));
      expect(sceneDelegate, contains('removePrivacyShield'));
    });
  });
}
