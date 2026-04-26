import 'package:dartz/dartz.dart';
import '../entities/entities.dart';
import '../repositories/repositories.dart';
import '../../core/errors/failures.dart';

/// Caso de uso: Iniciar proteção
class StartProtectionUseCase {
  final ProtectionRepository repository;

  StartProtectionUseCase(this.repository);

  Future<Either<Failure, ProtectionStatus>> call(AppConfiguration config) {
    return repository.startProtection(config);
  }
}

/// Caso de uso: Parar proteção
class StopProtectionUseCase {
  final ProtectionRepository repository;

  StopProtectionUseCase(this.repository);

  Future<Either<Failure, void>> call() {
    return repository.stopProtection();
  }
}

/// Caso de uso: Obter status de proteção
class GetProtectionStatusUseCase {
  final ProtectionRepository repository;

  GetProtectionStatusUseCase(this.repository);

  Future<Either<Failure, ProtectionStatus>> call() {
    return repository.getStatus();
  }
}

/// Caso de uso: Carregar configuração
class LoadConfigurationUseCase {
  final ConfigurationRepository repository;

  LoadConfigurationUseCase(this.repository);

  Future<Either<Failure, AppConfiguration>> call() {
    return repository.loadConfiguration();
  }
}

/// Caso de uso: Salvar configuração
class SaveConfigurationUseCase {
  final ConfigurationRepository repository;

  SaveConfigurationUseCase(this.repository);

  Future<Either<Failure, void>> call(AppConfiguration config) {
    return repository.saveConfiguration(config);
  }
}

/// Caso de uso: Obter logs recentes
class GetRecentLogsUseCase {
  final LogRepository repository;

  GetRecentLogsUseCase(this.repository);

  Either<Failure, List<String>> call(int limit) {
    return repository.getRecentLogs(limit);
  }
}

/// Caso de uso: Exportar logs
class ExportLogsUseCase {
  final LogRepository repository;

  ExportLogsUseCase(this.repository);

  Future<Either<Failure, String>> call() {
    return repository.exportLogs();
  }
}
