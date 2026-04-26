import 'dart:io';

import '../vpn/vpn_service.dart';
import 'android_vpn_service.dart';
import 'ios_vpn_service.dart';
import 'platform_vpn_service.dart';

class VPNServiceFactory {
  static PlatformVPNService create() {
    if (Platform.isAndroid) {
      return AndroidVPNService();
    }

    if (Platform.isIOS) {
      return IOSVPNService();
    }

    throw UnsupportedError('Platform not supported for native VPN service');
  }

  static Future<bool> supportsNativeVPN() async {
    return Platform.isAndroid || Platform.isIOS;
  }

  static VPNConfig toVPNConfig(Map<String, dynamic> map) {
    return VPNConfig(
      serverAddress: map['serverAddress'] as String? ?? '',
      port: map['port'] as int? ?? 51820,
      privateKey: map['privateKey'] as String? ?? '',
      publicKey: map['publicKey'] as String? ?? '',
      presharedKey: map['presharedKey'] as String? ?? '',
      ipAddress: map['ipAddress'] as String? ?? '10.0.0.2',
      dnsServers: map['dnsServers'] as String? ?? '1.1.1.1,1.0.0.1',
    );
  }
}
