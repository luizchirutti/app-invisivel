/// Classe base para tratamento de falhas/erros
abstract class Failure {
  final String message;
  final StackTrace? stackTrace;

  Failure(this.message, [this.stackTrace]);

  @override
  String toString() => message;
}

/// Erro genérico de rede
class NetworkFailure extends Failure {
  NetworkFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Erro de conexão VPN
class VPNConnectionFailure extends Failure {
  VPNConnectionFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Erro de Kill Switch ativado
class KillSwitchTriggeredFailure extends Failure {
  KillSwitchTriggeredFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Erro de DNS
class DNSFailure extends Failure {
  DNSFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Erro de segurança/criptografia
class SecurityFailure extends Failure {
  SecurityFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Erro de integridade do dispositivo
class IntegrityFailure extends Failure {
  IntegrityFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Erro de cache
class CacheFailure extends Failure {
  CacheFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Erro genérico de aplicação
class AppFailure extends Failure {
  AppFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}
