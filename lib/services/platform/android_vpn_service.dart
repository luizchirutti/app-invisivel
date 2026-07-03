import 'package:flutter/services.dart';

import '../vpn/vpn_service.dart';
import 'platform_vpn_service.dart';

class AndroidVPNService implements PlatformVPNService {
  static const MethodChannel _vpnChannel = MethodChannel('com.infinityprox/protection');
  static const MethodChannel _securityChannel = MethodChannel('com.infinityprox/security');

  @override
  Future<bool> startVPN(VPNConfig config) async {
    final response = await _vpnChannel.invokeMapMethod<String, dynamic>('startProtection', {
      'serverAddress': config.serverAddress,
      'port': config.port,
      'privateKey': config.privateKey,
      'publicKey': config.publicKey,
      'presharedKey': config.presharedKey,
      'ipAddress': config.ipAddress,
      'dnsServers': config.dnsServers,
    });

    return response?['status'] == 'PROTECTION_STARTING';
  }

  @override
  Future<bool> stopVPN() async {
    final response = await _vpnChannel.invokeMapMethod<String, dynamic>('stopProtection');
    return response?['status'] == 'PROTECTION_STOPPING';
  }

  @override
  Future<Map<String, dynamic>> getVPNStatus() async {
    final response = await _vpnChannel.invokeMapMethod<String, dynamic>('getProtectionStatus');
    return response ?? <String, dynamic>{
      'isConnected': false,
      'status': 'UNKNOWN',
    };
  }

  @override
  Future<bool> setKillSwitch(bool enabled) async {
    final response = await _vpnChannel.invokeMapMethod<String, dynamic>('setProtectionBlock', {
      'enabled': enabled,
    });
    return response?['killSwitch'] == enabled;
  }

  @override
  Future<bool> isDeviceSecure() async {
    final response = await _securityChannel.invokeMapMethod<String, dynamic>('checkDeviceSecurity');
    return response?['isSecure'] == true;
  }

  @override
  Future<bool> isDeviceRooted() async {
    final response = await _securityChannel.invokeMapMethod<String, dynamic>('isRooted');
    return response?['isRooted'] == true;
  }

  @override
  Future<bool> isEmulator() async {
    final response = await _securityChannel.invokeMapMethod<String, dynamic>('isEmulator');
    return response?['isEmulator'] == true;
  }
}
