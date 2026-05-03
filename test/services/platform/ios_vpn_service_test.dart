import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/platform/ios_vpn_service.dart';
import '../../../lib/services/vpn/vpn_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel vpnChannel = MethodChannel('com.infinityprox/vpn');
  const MethodChannel securityChannel = MethodChannel('com.infinityprox/security');

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late IOSVPNService service;

  setUp(() {
    service = IOSVPNService();
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(vpnChannel, null);
    messenger.setMockMethodCallHandler(securityChannel, null);
  });

  test('startVPN retorna false para status inesperado', () async {
    messenger.setMockMethodCallHandler(vpnChannel, (MethodCall call) async {
      expect(call.method, 'startVPN');
      return <String, dynamic>{'status': 'FAILED'};
    });

    final config = VPNConfig(
      serverAddress: 'us-1.server',
      port: 51820,
      privateKey: 'private',
      publicKey: 'public',
      presharedKey: 'psk',
      ipAddress: '10.0.0.2',
      dnsServers: '1.1.1.1,1.0.0.1',
    );

    final result = await service.startVPN(config);
    expect(result, isFalse);
  });

  test('getVPNStatus retorna valor do canal', () async {
    messenger.setMockMethodCallHandler(vpnChannel, (MethodCall call) async {
      expect(call.method, 'getVPNStatus');
      return <String, dynamic>{
        'isConnected': true,
        'status': 'CONNECTED',
      };
    });

    final status = await service.getVPNStatus();

    expect(status['isConnected'], isTrue);
    expect(status['status'], 'CONNECTED');
  });

  test('stopVPN e setKillSwitch retornam true no caso de sucesso', () async {
    messenger.setMockMethodCallHandler(vpnChannel, (MethodCall call) async {
      if (call.method == 'stopVPN') {
        return <String, dynamic>{'status': 'VPN_STOPPING'};
      }

      if (call.method == 'setKillSwitch') {
        return <String, dynamic>{'killSwitch': false};
      }

      return <String, dynamic>{};
    });

    expect(await service.stopVPN(), isTrue);
    expect(await service.setKillSwitch(false), isTrue);
  });

  test('security methods iOS mapeiam retorno do canal', () async {
    messenger.setMockMethodCallHandler(
      securityChannel,
      (MethodCall call) async {
        switch (call.method) {
          case 'checkDeviceSecurity':
            return <String, dynamic>{'isSecure': true};
          case 'isRooted':
            return <String, dynamic>{'isRooted': true};
          case 'isEmulator':
            return <String, dynamic>{'isEmulator': true};
          default:
            return <String, dynamic>{};
        }
      },
    );

    expect(await service.isDeviceSecure(), isTrue);
    expect(await service.isDeviceRooted(), isTrue);
    expect(await service.isEmulator(), isTrue);
  });
}
