import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/platform/android_vpn_service.dart';
import '../../../lib/services/platform/ios_vpn_service.dart';
import '../../../lib/services/platform/vpn_service_factory.dart';

void main() {
  group('VPNServiceFactory', () {
    test('supportsNativeVPN reflete plataforma atual', () async {
      final supportsNative = await VPNServiceFactory.supportsNativeVPN();
      expect(supportsNative, Platform.isAndroid || Platform.isIOS);
    });

    test('toVPNConfig converte com defaults seguros', () {
      final cfg = VPNServiceFactory.toVPNConfig(<String, dynamic>{});

      expect(cfg.serverAddress, '');
      expect(cfg.port, 51820);
      expect(cfg.ipAddress, '10.0.0.2');
      expect(cfg.dnsServers, '1.1.1.1,1.0.0.1');
    });

    test('create retorna implementação adequada ou lança erro', () {
      if (Platform.isAndroid) {
        expect(VPNServiceFactory.create(), isA<AndroidVPNService>());
        return;
      }

      if (Platform.isIOS) {
        expect(VPNServiceFactory.create(), isA<IOSVPNService>());
        return;
      }

      expect(() => VPNServiceFactory.create(), throwsA(isA<UnsupportedError>()));
    });
  });
}
