import '../vpn/vpn_service.dart';

abstract class PlatformVPNService {
  Future<bool> startVPN(VPNConfig config);
  Future<bool> stopVPN();
  Future<Map<String, dynamic>> getVPNStatus();
  Future<bool> setKillSwitch(bool enabled);

  Future<bool> isDeviceSecure();
  Future<bool> isDeviceRooted();
  Future<bool> isEmulator();
}
