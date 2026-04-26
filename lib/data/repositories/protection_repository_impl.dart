import 'package:dartz/dartz.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../../core/errors/failures.dart';
import '../../services/doh/doh_service.dart';
import '../../security/device_integrity/device_integrity_service.dart';
import '../../security/anti_fingerprinting/anti_fingerprinter_service.dart';
import '../../services/platform/unified_vpn_service.dart';

/// Implementação do repositório de proteção
class ProtectionRepositoryImpl implements ProtectionRepository {
  final UnifiedVPNService vpnService;
  final DoHService dohService;
  final DeviceIntegrityService integrityService;
  final AntiFingerprinterService antiFingerprinterService;

  ProtectionRepositoryImpl({
    required this.vpnService,
    required this.dohService,
    required this.integrityService,
    required this.antiFingerprinterService,
  });

  @override
  Future<Either<Failure, ProtectionStatus>> startProtection(
    AppConfiguration config,
  ) async {
    try {
      // Verificar integridade do dispositivo
      final integrityResult = await integrityService.checkDeviceIntegrity();
      if (!integrityResult.isSecure) {
        return Left(IntegrityFailure(integrityResult.threatsSummary));
      }

      // Configurar VPN
      final connectResult = await vpnService.connect(
        config.preferredVPNServer,
        51820,
        'PLACEHOLDER_KEY',
        'PLACEHOLDER_KEY',
        'PLACEHOLDER_KEY',
        '10.0.0.2',
        '1.1.1.1,1.0.0.1',
      );

      if (connectResult.isLeft()) {
        return Left(
          connectResult.swap().getOrElse(
            () => VPNConnectionFailure('Falha ao conectar VPN'),
          ),
        );
      }

      if (config.enableKillSwitch) {
        final ksResult = await vpnService.setKillSwitch(true);
        if (ksResult.isLeft()) {
          return Left(
            ksResult.swap().getOrElse(
              () => VPNConnectionFailure('Falha ao ativar Kill Switch'),
            ),
          );
        }
      }

      // Ativar DoH
      dohService.enforceDoHForDioRequests();

      // Obter status atual
      return Right(
        ProtectionStatus(
          isVPNActive: true,
          isKillSwitchActive: true,
          dohEnabled: config.enableDoH,
          antiFingerprinting: config.enableAntiFingerprinting,
          threatDetectionActive: config.enableThreatDetection,
          activeThreats: integrityResult.threats,
          lastChecked: DateTime.now(),
          bytesTransferred: 0,
          currentServerLocation: 'Conectado',
        ),
      );
    } catch (e) {
      return Left(VPNConnectionFailure('Erro ao iniciar proteção: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> stopProtection() async {
    try {
      final stopResult = await vpnService.disconnect();
      return stopResult;
    } catch (e) {
      return Left(VPNConnectionFailure('Erro ao parar proteção: $e'));
    }
  }

  @override
  Future<Either<Failure, ProtectionStatus>> getStatus() async {
    try {
      final vpnStatusResult = await vpnService.getStatus();
      final integrityResult = await integrityService.checkDeviceIntegrity();

      if (vpnStatusResult.isLeft()) {
        return Left(
          vpnStatusResult.swap().getOrElse(
            () => AppFailure('Falha ao obter status da VPN'),
          ),
        );
      }

      final vpnMap = vpnStatusResult.getOrElse(() => const {});
      final isConnected = vpnMap['isConnected'] == true;

      return Right(
        ProtectionStatus(
          isVPNActive: isConnected,
          isKillSwitchActive: isConnected,
          dohEnabled: true,
          antiFingerprinting: true,
          threatDetectionActive: true,
          activeThreats: integrityResult.threats,
          lastChecked: DateTime.now(),
          bytesTransferred: 0,
          currentServerLocation: isConnected ? 'Conectado' : 'Desconectado',
        ),
      );
    } catch (e) {
      return Left(AppFailure('Erro ao obter status: $e'));
    }
  }

  @override
  Stream<ConnectionEvent> getConnectionEvents() {
    // TODO: Implementar stream de eventos de conexão capturados
    return Stream.empty();
  }

  @override
  Stream<ProtectionStatus> getStatusChanges() {
    // TODO: Implementar stream de mudanças de status
    return Stream.empty();
  }
}
