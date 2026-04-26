import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/platform/android_vpn_service.dart';
import '../../../lib/services/vpn/vpn_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel vpnChannel = MethodChannel('com.infinityprox/vpn');
  const MethodChannel securityChannel = MethodChannel('com.infinityprox/security');

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late AndroidVPNService service;

  setUp(() {
    service = AndroidVPNService();
  });

  tearDown(() async {
    await messenger.setMockMethodCallHandler(vpnChannel, null);
    await messenger.setMockMethodCallHandler(securityChannel, null);
  });

  test('startVPN envia payload e retorna true com status esperado', () async {
    Map<dynamic, dynamic>? received;

    await messenger.setMockMethodCallHandler(vpnChannel, (MethodCall call) async {
      expect(call.method, 'startVPN');
      received = call.arguments as Map<dynamic, dynamic>;
      return <String, dynamic>{'status': 'VPN_STARTING'};
    });

    final config = VPNConfig(
      serverAddress: '185.1.1.1',
      port: 51820,
      privateKey: 'private',
      publicKey: 'public',
      presharedKey: 'psk',
      ipAddress: '10.0.0.2',
      dnsServers: '1.1.1.1,1.0.0.1',
    );

    final result = await service.startVPN(config);

    expect(result, isTrue);
    expect(received?['serverAddress'], '185.1.1.1');
    expect(received?['port'], 51820);
    expect(received?['dnsServers'], '1.1.1.1,1.0.0.1');
  });

  test('stopVPN retorna true quando status VPN_STOPPING', () async {
    await messenger.setMockMethodCallHandler(vpnChannel, (MethodCall call) async {
      expect(call.method, 'stopVPN');
      return <String, dynamic>{'status': 'VPN_STOPPING'};
    });

    final result = await service.stopVPN();
    expect(result, isTrue);
  });

  test('getVPNStatus retorna fallback quando resposta nula', () async {
    await messenger.setMockMethodCallHandler(vpnChannel, (MethodCall call) async {
      expect(call.method, 'getVPNStatus');
      return null;
    });

    final status = await service.getVPNStatus();

    expect(status['isConnected'], isFalse);
    expect(status['status'], 'UNKNOWN');
  });

  test('setKillSwitch envia enabled e retorna true', () async {
    await messenger.setMockMethodCallHandler(vpnChannel, (MethodCall call) async {
      expect(call.method, 'setKillSwitch');
      final args = call.arguments as Map<dynamic, dynamic>;
      expect(args['enabled'], isTrue);
      return <String, dynamic>{'killSwitch': true};
    });

    final result = await service.setKillSwitch(true);
    expect(result, isTrue);
  });

  test('security methods retornam valores esperados', () async {
    await messenger.setMockMethodCallHandler(
      securityChannel,
      (MethodCall call) async {
        switch (call.method) {
          case 'checkDeviceSecurity':
            return <String, dynamic>{'isSecure': true};
          case 'isRooted':
            return <String, dynamic>{'isRooted': false};
          case 'isEmulator':
            return <String, dynamic>{'isEmulator': false};
          default:
            return <String, dynamic>{};
        }
      },
    );

    expect(await service.isDeviceSecure(), isTrue);
    expect(await service.isDeviceRooted(), isFalse);
    expect(await service.isEmulator(), isFalse);
  });
}
