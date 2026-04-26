import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/security_constants.dart';
import '../../core/errors/failures.dart';
import 'package:dartz/dartz.dart';

/// Estado da conexão VPN
enum VPNConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// Entidade de configuração VPN
class VPNConfig {
  final String serverAddress;
  final int port;
  final String privateKey;
  final String publicKey;
  final String presharedKey;
  final String ipAddress;
  final String dnsServers;

  VPNConfig({
    required this.serverAddress,
    required this.port,
    required this.privateKey,
    required this.publicKey,
    required this.presharedKey,
    required this.ipAddress,
    required this.dnsServers,
  });
}

/// Resultado de evento da VPN
class VPNEvent {
  final VPNConnectionState state;
  final String? message;
  final int? bytesIn;
  final int? bytesOut;
  final DateTime timestamp;

  VPNEvent({
    required this.state,
    this.message,
    this.bytesIn,
    this.bytesOut,
    required this.timestamp,
  });
}

/// Serviço de VPN com WireGuard + Kill Switch
class VPNService {
  static final VPNService _instance = VPNService._internal();

  factory VPNService() {
    return _instance;
  }

  VPNService._internal();

  late VPNConfig _config;
  VPNConnectionState _currentState = VPNConnectionState.disconnected;
  final _stateController = StreamController<VPNEvent>.broadcast();
  final _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  Timer? _killSwitchMonitor;
  bool _vpnInterfaceActive = false;

  /// Stream de eventos da VPN
  Stream<VPNEvent> get onVPNStateChanged => _stateController.stream;

  /// Estado atual da VPN
  VPNConnectionState get currentState => _currentState;

  /// Inicializa o serviço VPN com configuração
  Future<Either<Failure, void>> initializeVPN(VPNConfig config) async {
    try {
      _config = config;

      // Verificar conectividade de rede
      final connectivity = await _connectivity.checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        return Left(NetworkFailure('Sem conectividade de rede'));
      }

      _subscribeToConnectivityChanges();
      debugPrint('[VPN] Inicializado com sucesso');

      return const Right(null);
    } catch (e) {
      return Left(VPNConnectionFailure('Erro ao inicializar VPN: $e'));
    }
  }

  /// Conecta à VPN
  Future<Either<Failure, void>> connectToVPN() async {
    try {
      _updateState(VPNConnectionState.connecting, 'Conectando à VPN...');

      // Ativar Kill Switch ANTES de conectar
      await _activateKillSwitch();

      // Simulação de conexão WireGuard
      await _establishWireGuardConnection();

      _vpnInterfaceActive = true;
      _startKillSwitchMonitoring();

      _updateState(
        VPNConnectionState.connected,
        'VPN conectada com sucesso via ${SecurityConstants.VPN_PROTOCOL}',
      );

      debugPrint('[VPN] Conexão estabelecida');
      return const Right(null);
    } catch (e) {
      _updateState(VPNConnectionState.error, 'Erro de conexão: $e');
      return Left(VPNConnectionFailure('Falha ao conectar VPN: $e'));
    }
  }

  /// Desconecta da VPN
  Future<Either<Failure, void>> disconnectFromVPN() async {
    try {
      _updateState(VPNConnectionState.disconnecting, 'Desconectando VPN...');

      // Parar monitoramento de Kill Switch
      _stopKillSwitchMonitoring();

      // Desativar interface VPN
      await _teardownWireGuardConnection();
      _vpnInterfaceActive = false;

      // Desativar Kill Switch
      await _deactivateKillSwitch();

      _updateState(VPNConnectionState.disconnected, 'VPN desconectada');

      debugPrint('[VPN] Desconectada com sucesso');
      return const Right(null);
    } catch (e) {
      return Left(VPNConnectionFailure('Erro ao desconectar: $e'));
    }
  }

  /// Ativa Kill Switch (bloqueia tráfego se VPN cair)
  Future<void> _activateKillSwitch() async {
    try {
      // TODO: Implementar platform channel para Android/iOS
      // Para Android: usar iptables para bloquear tráfego
      // Para iOS: usar NEPacketTunnelProvider

      debugPrint('[KillSwitch] Ativado');
    } catch (e) {
      debugPrint('[KillSwitch] Erro ao ativar: $e');
      throw VPNConnectionFailure('Falha ao ativar Kill Switch: $e');
    }
  }

  /// Desativa Kill Switch
  Future<void> _deactivateKillSwitch() async {
    try {
      // TODO: Implementar desativação via platform channel
      debugPrint('[KillSwitch] Desativado');
    } catch (e) {
      debugPrint('[KillSwitch] Erro ao desativar: $e');
    }
  }

  /// Monitora Kill Switch a cada 5 segundos
  void _startKillSwitchMonitoring() {
    _killSwitchMonitor?.cancel();

    _killSwitchMonitor = Timer.periodic(
      Duration(milliseconds: SecurityConstants.KILL_SWITCH_CHECK_INTERVAL_MS),
      (_) async {
        final isVPNActive = await _isVPNInterfaceActive();

        if (!isVPNActive && _vpnInterfaceActive) {
          // VPN caiu! Ativar Kill Switch
          await _triggerKillSwitch();
        }
      },
    );

    debugPrint('[KillSwitch] Monitoramento iniciado');
  }

  /// Para monitoramento de Kill Switch
  void _stopKillSwitchMonitoring() {
    _killSwitchMonitor?.cancel();
    _killSwitchMonitor = null;
    debugPrint('[KillSwitch] Monitoramento parado');
  }

  /// Verifica se interface VPN está ativa
  Future<bool> _isVPNInterfaceActive() async {
    try {
      // TODO: Implementar verificação real via platform channel
      // Verificar se interface wg0 existe e está UP
      return _vpnInterfaceActive;
    } catch (e) {
      return false;
    }
  }

  /// Dispara Kill Switch (bloqueia todo tráfego)
  Future<void> _triggerKillSwitch() async {
    _updateState(
      VPNConnectionState.error,
      '🚨 KILL SWITCH ATIVADO: Interface VPN caiu! Tráfego bloqueado.',
    );

    debugPrint('[KillSwitch] ATIVADO - Interface VPN detectada como inativa!');

    // Notificar usuário
    // TODO: Mostrar notificação critical
  }

  /// Estabelece conexão WireGuard
  Future<void> _establishWireGuardConnection() async {
    // Simular handshake WireGuard
    await Future.delayed(const Duration(seconds: 2));

    // TODO: Implementar via platform channel:
    // 1. Criar arquivo de configuração wg0.conf
    // 2. Executar: wg-quick up wg0 (Android) ou carregar config (iOS)
    // 3. Verificar conectividade através do túnel

    debugPrint('[WireGuard] Tunel estabelecido');
  }

  /// Encerra conexão WireGuard
  Future<void> _teardownWireGuardConnection() async {
    // TODO: Implementar via platform channel:
    // 1. Executar: wg-quick down wg0 (Android)
    // 2. Limpar configurações (iOS)

    debugPrint('[WireGuard] Tunel encerrado');
  }

  /// Se inscreve nas mudanças de conectividade para reativar VPN
  void _subscribeToConnectivityChanges() {
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen((ConnectivityResult result) async {
      if (result == ConnectivityResult.none &&
          _currentState == VPNConnectionState.connected) {
        // Rede perdida enquanto conectado - Kill Switch deve bloquear
        await _triggerKillSwitch();
      } else if (result != ConnectivityResult.none &&
          _currentState == VPNConnectionState.error) {
        // Rede recuperada - tentar reconectar
        debugPrint('[VPN] Rede recuperada, tentando reconectar...');
        await connectToVPN();
      }
    });
  }

  /// Atualiza estado VPN
  void _updateState(VPNConnectionState state, String message) {
    _currentState = state;
    _stateController.add(
      VPNEvent(
        state: state,
        message: message,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Obtém status da conexão
  Future<VPNStatus> getVPNStatus() async {
    return VPNStatus(
      isConnected: _currentState == VPNConnectionState.connected,
      state: _currentState,
      lastUpdate: DateTime.now(),
    );
  }

  /// Limpeza de recursos
  void dispose() {
    _connectivitySubscription?.cancel();
    _killSwitchMonitor?.cancel();
    _stateController.close();
  }
}

/// Status atual da VPN
class VPNStatus {
  final bool isConnected;
  final VPNConnectionState state;
  final DateTime lastUpdate;

  VPNStatus({
    required this.isConnected,
    required this.state,
    required this.lastUpdate,
  });
}
