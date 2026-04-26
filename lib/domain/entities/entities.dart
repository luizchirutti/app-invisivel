/// Entidade representando o estado de proteção da aplicação
class ProtectionStatus {
  final bool isVPNActive;
  final bool isKillSwitchActive;
  final bool dohEnabled;
  final bool antiFingerprinting;
  final bool threatDetectionActive;
  final List<String> activeThreats;
  final DateTime lastChecked;
  final int bytesTransferred;
  final String currentServerLocation;

  ProtectionStatus({
    required this.isVPNActive,
    required this.isKillSwitchActive,
    required this.dohEnabled,
    required this.antiFingerprinting,
    required this.threatDetectionActive,
    required this.activeThreats,
    required this.lastChecked,
    required this.bytesTransferred,
    required this.currentServerLocation,
  });

  /// Determina se a proteção está totalmente ativa
  bool get isFullyProtected =>
      isVPNActive &&
      isKillSwitchActive &&
      dohEnabled &&
      antiFingerprinting &&
      threatDetectionActive &&
      activeThreats.isEmpty;

  /// Nível de risco (0-100)
  int get riskLevel => activeThreats.isEmpty ? 0 : (activeThreats.length * 25).clamp(0, 100);

  /// Resumo textual de ameaças ativas
  String get threatsSummary =>
      activeThreats.isEmpty ? 'Nenhuma ameaça detectada' : activeThreats.join(', ');
}

/// Entidade para eventos de conexão
class ConnectionEvent {
  final String id;
  final String type; // 'BLOCKED', 'ALLOWED', 'THREAT_DETECTED', 'VPN_CONNECTED', etc
  final String description;
  final String sourceIP;
  final String destinationHost;
  final DateTime timestamp;
  final int port;
  final String protocol; // TCP, UDP, DNS

  ConnectionEvent({
    required this.id,
    required this.type,
    required this.description,
    required this.sourceIP,
    required this.destinationHost,
    required this.timestamp,
    required this.port,
    required this.protocol,
  });

  String get emoji {
    switch (type) {
      case 'BLOCKED':
        return '🚫';
      case 'ALLOWED':
        return '✅';
      case 'THREAT_DETECTED':
        return '🚨';
      case 'VPN_CONNECTED':
        return '🔒';
      case 'VPN_DISCONNECTED':
        return '🔓';
      case 'KILL_SWITCH_TRIGGERED':
        return '⚡';
      default:
        return '📡';
    }
  }
}

/// Entidade de configuração do aplicativo
class AppConfiguration {
  final bool autoConnectVPN;
  final bool enableKillSwitch;
  final bool enableDoH;
  final bool enableAntiFingerprinting;
  final bool enableThreatDetection;
  final bool enableContinuousMonitoring;
  final String preferredDohServer;
  final String preferredVPNServer;
  final Duration monitoringInterval;
  final bool blockLocalNetworks;
  final bool blockP2PTraffic;

  AppConfiguration({
    this.autoConnectVPN = true,
    this.enableKillSwitch = true,
    this.enableDoH = true,
    this.enableAntiFingerprinting = true,
    this.enableThreatDetection = true,
    this.enableContinuousMonitoring = true,
    this.preferredDohServer = 'https://1.1.1.1/dns-query',
    this.preferredVPNServer = 'default',
    this.monitoringInterval = const Duration(minutes: 5),
    this.blockLocalNetworks = false,
    this.blockP2PTraffic = true,
  });

  /// Cria cópia com sobrescrita
  AppConfiguration copyWith({
    bool? autoConnectVPN,
    bool? enableKillSwitch,
    bool? enableDoH,
    bool? enableAntiFingerprinting,
    bool? enableThreatDetection,
    bool? enableContinuousMonitoring,
    String? preferredDohServer,
    String? preferredVPNServer,
    Duration? monitoringInterval,
    bool? blockLocalNetworks,
    bool? blockP2PTraffic,
  }) {
    return AppConfiguration(
      autoConnectVPN: autoConnectVPN ?? this.autoConnectVPN,
      enableKillSwitch: enableKillSwitch ?? this.enableKillSwitch,
      enableDoH: enableDoH ?? this.enableDoH,
      enableAntiFingerprinting:
          enableAntiFingerprinting ?? this.enableAntiFingerprinting,
      enableThreatDetection: enableThreatDetection ?? this.enableThreatDetection,
      enableContinuousMonitoring:
          enableContinuousMonitoring ?? this.enableContinuousMonitoring,
      preferredDohServer: preferredDohServer ?? this.preferredDohServer,
      preferredVPNServer: preferredVPNServer ?? this.preferredVPNServer,
      monitoringInterval: monitoringInterval ?? this.monitoringInterval,
      blockLocalNetworks: blockLocalNetworks ?? this.blockLocalNetworks,
      blockP2PTraffic: blockP2PTraffic ?? this.blockP2PTraffic,
    );
  }
}
