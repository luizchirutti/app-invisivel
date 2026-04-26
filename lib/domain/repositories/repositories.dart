import 'package:dartz/dartz.dart';
import '../entities/entities.dart';
import '../../core/errors/failures.dart';

/// Contrato de repositório para proteção
abstract class ProtectionRepository {
  /// Inicia proteção (VPN + Kill Switch)
  Future<Either<Failure, ProtectionStatus>> startProtection(
    AppConfiguration config,
  );

  /// Para proteção
  Future<Either<Failure, void>> stopProtection();

  /// Obtém status atual
  Future<Either<Failure, ProtectionStatus>> getStatus();

  /// Stream de eventos de conexão
  Stream<ConnectionEvent> getConnectionEvents();

  /// Stream de mudanças de status
  Stream<ProtectionStatus> getStatusChanges();
}

/// Contrato de repositório para configuração
abstract class ConfigurationRepository {
  /// Carrega configuração salva
  Future<Either<Failure, AppConfiguration>> loadConfiguration();

  /// Salva configuração
  Future<Either<Failure, void>> saveConfiguration(AppConfiguration config);

  /// Reseta para padrões
  Future<Either<Failure, void>> resetToDefaults();
}

/// Contrato de repositório para logs
abstract class LogRepository {
  /// Obtém logs em memória
  Either<Failure, List<String>> getRecentLogs(int limit);

  /// Exporta logs seguros
  Future<Either<Failure, String>> exportLogs();

  /// Limpa logs
  Future<Either<Failure, void>> clearLogs();
}
