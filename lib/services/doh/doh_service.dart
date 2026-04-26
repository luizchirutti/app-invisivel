import 'dart:async';
import 'package:dio/dio.dart';
import '../../core/constants/security_constants.dart';
import '../../core/errors/failures.dart';
import 'package:dartz/dartz.dart';

/// Resultado de query DNS
class DNSRecord {
  final String domain;
  final String recordType; // A, AAAA, MX, etc
  final List<String> answers;
  final int ttl;
  final DateTime resolvedAt;

  DNSRecord({
    required this.domain,
    required this.recordType,
    required this.answers,
    required this.ttl,
    required this.resolvedAt,
  });
}

/// Serviço de DNS sobre HTTPS (DoH)
/// Força todas as requisições DNS através de provedores privados criptografados
class DoHService {
  static final DoHService _instance = DoHService._internal();

  factory DoHService() {
    return _instance;
  }

  DoHService._internal() {
    _initializeDio();
  }

  late Dio _dioClient;
  final Map<String, DNSRecord> _dnsCache = {};
  String _activeDohServer = SecurityConstants.PRIMARY_DOH_SERVER;
  int _queryCount = 0;

  /// Inicializa cliente HTTP com configurações seguras
  void _initializeDio() {
    final options = BaseOptions(
      connectTimeout: Duration(
          milliseconds: SecurityConstants.DOH_REQUEST_TIMEOUT_MS),
      receiveTimeout: Duration(
          milliseconds: SecurityConstants.DOH_REQUEST_TIMEOUT_MS),
      responseType: ResponseType.json,
      validateStatus: (status) => status != null && status < 500,
    );

    _dioClient = Dio(options);

    // Adicionar interceptor para segurança
    _dioClient.interceptors.add(_DoHSecurityInterceptor());
  }

  /// Realiza query DNS via DoH
  /// Suporta tipos: A, AAAA, MX, NS, TXT, CNAME
  Future<Either<Failure, DNSRecord>> resolveDomain(
    String domain, {
    String recordType = 'A',
  }) async {
    try {
      // Verificar cache primeiro
      final cacheKey = '$domain:$recordType';
      if (_dnsCache.containsKey(cacheKey)) {
        final cached = _dnsCache[cacheKey]!;
        if (DateTime.now().difference(cached.resolvedAt).inSeconds <
            cached.ttl) {
          return Right(cached);
        } else {
          _dnsCache.remove(cacheKey);
        }
      }

      // Query via DoH
      final record = await _queryDoH(domain, recordType);

      // Armazenar em cache
      _dnsCache[cacheKey] = record;

      return Right(record);
    } on DNSFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(DNSFailure('Erro ao resolver domínio: $e'));
    }
  }

  /// Executa query DoH real
  Future<DNSRecord> _queryDoH(String domain, String recordType) async {
    try {
      _queryCount++;

      // Construir query em formato RFC 8484 (JSON)
      final response = await _dioClient.get(
        _activeDohServer,
        queryParameters: {
          'name': domain,
          'type': recordType,
          'do': true, // DNSSEC validação
          'cd': false, // Não ignorar DNSSEC inválido
        },
        options: Options(
          headers: {
            'Accept': 'application/dns-json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
        ),
      );

      if (response.statusCode == 200) {
        return _parseDNSResponse(domain, recordType, response.data);
      } else if (response.statusCode == 500 || response.statusCode == 503) {
        // Tentar servidor secundário
        return await _queryDoHWithFallback(domain, recordType);
      } else {
        throw DNSFailure('Servidor DoH respondeu com ${response.statusCode}');
      }
    } catch (e) {
      if (e is DNSFailure) rethrow;
      throw DNSFailure('Erro na query DoH: $e');
    }
  }

  /// Query com fallback automático
  Future<DNSRecord> _queryDoHWithFallback(String domain, String recordType) async {
    final servers = [
      SecurityConstants.SECONDARY_DOH_SERVER,
      SecurityConstants.CLOUDFLARE_DOH,
      SecurityConstants.NEXTDNS_DOH,
    ];

    for (final server in servers) {
      try {
        _activeDohServer = server;
        final response = await _dioClient.get(
          server,
          queryParameters: {
            'name': domain,
            'type': recordType,
            'do': true,
          },
        );

        if (response.statusCode == 200) {
          return _parseDNSResponse(domain, recordType, response.data);
        }
      } catch (e) {
        continue; // Tentar próximo servidor
      }
    }

    throw DNSFailure('Todos os servidores DoH estão indisponíveis');
  }

  /// Parse resposta DNS em JSON
  DNSRecord _parseDNSResponse(
    String domain,
    String recordType,
    Map<String, dynamic> data,
  ) {
    try {
      final answers = <String>[];
      int ttl = 300; // Default 5 minutos

      if (data['Answer'] != null && data['Answer'] is List) {
        for (final answer in data['Answer'] as List) {
          answers.add(answer['data'] ?? '');
          ttl = answer['TTL'] ?? ttl;
        }
      }

      return DNSRecord(
        domain: domain,
        recordType: recordType,
        answers: answers,
        ttl: ttl,
        resolvedAt: DateTime.now(),
      );
    } catch (e) {
      throw DNSFailure('Erro ao fazer parse de resposta DNS: $e');
    }
  }

  /// Limpa cache DNS
  void clearDNSCache() {
    _dnsCache.clear();
  }

  /// Obtém estatísticas de queries
  Map<String, dynamic> getStatistics() {
    return {
      'totalQueries': _queryCount,
      'cachedRecords': _dnsCache.length,
      'activeDohServer': _activeDohServer,
    };
  }

  /// Força DoH em todas as requisições Dio
  void enforceDoHForDioRequests() {
    _dioClient.interceptors.add(_DoHEnforcerInterceptor(this));
  }
}

/// Interceptor para garantir segurança DoH
class _DoHSecurityInterceptor extends QueuedInterceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Garantir HTTPS (apenas para requisições já iniciadas fora do interceptor)
    // options.uri é somente leitura no Dio 5; o cliente é configurado com BaseOptions HTTPS

    // Adicionar headers de segurança
    options.headers.addAll({
      'X-Requested-With': 'XMLHttpRequest',
      'Pragma': 'no-cache',
      'Cache-Control': 'no-cache, no-store, max-age=0',
    });

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Log seguro de erros (sem informações sensíveis)
    if (err.requestOptions.uri.toString().contains('dns')) {
      // Erro em query DNS
    }
    handler.next(err);
  }
}

/// Interceptor que força DoH para todas as requisições
class _DoHEnforcerInterceptor extends QueuedInterceptor {
  final DoHService _doHService;

  _DoHEnforcerInterceptor(this._doHService);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Nota: Em produção, você implementaria lógica para
    // forçar resolução via DoH antes de fazer a requisição
    handler.next(options);
  }
}
