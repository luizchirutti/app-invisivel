import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/security_constants.dart';
import '../../security/encryption/crypto_manager.dart';
import 'package:uuid/uuid.dart';

/// Tipos de log
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Entrada de log
class LogEntry {
  final String id;
  final LogLevel level;
  final String message;
  final String? tag;
  final String? stackTrace;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  LogEntry({
    String? id,
    required this.level,
    required this.message,
    this.tag,
    this.stackTrace,
    DateTime? timestamp,
    this.metadata,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  /// Converte para mapa para serialização
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'level': level.name,
      'message': message,
      'tag': tag,
      'stackTrace': stackTrace,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Formata para exibição
  String toFormattedString() {
    final levelEmoji = _getLevelEmoji();
    return '[$levelEmoji ${timestamp.toIso8601String()}] ${tag != null ? '[$tag] ' : ''}$message';
  }

  String _getLevelEmoji() {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.critical:
        return '🚨';
    }
  }
}

/// Serviço de logging seguro e criptografado
class SecureLoggingService {
  static final SecureLoggingService _instance =
      SecureLoggingService._internal();

  factory SecureLoggingService() {
    return _instance;
  }

  SecureLoggingService._internal();

  final List<LogEntry> _memoryBuffer = [];
  late Directory _logsDirectory;
  late File _currentLogFile;
  late Uint8List _encryptionKey;
  bool _initialized = false;

  /// Inicializa o serviço
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Criar diretório de logs seguro
      final appDir = await getApplicationDocumentsDirectory();
      _logsDirectory = Directory('${appDir.path}/.security_logs');

      if (!await _logsDirectory.exists()) {
        await _logsDirectory.create(recursive: true);
      }

      // Gerar/carregar chave de criptografia para logs
      _encryptionKey = await _loadOrGenerateLogKey();

      // Criar arquivo de log atual
      _currentLogFile = await _createNewLogFile();

      _initialized = true;
      _logInternal(
        LogLevel.info,
        'Serviço de logging inicializado',
        'SecureLogging',
      );
    } catch (e) {
      // Fallback para stderr se falhar
      stderr.writeln('Erro ao inicializar logging: $e');
    }
  }

  /// Carrega ou gera chave de encriptação
  Future<Uint8List> _loadOrGenerateLogKey() async {
    // TODO: Implementar com secure storage
    // Por enquanto, gerar chave derivada de hash fixo
    return CryptoManager.generateAESKey();
  }

  /// Cria novo arquivo de log
  Future<File> _createNewLogFile() async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${_logsDirectory.path}/log_$timestamp.enc');
    await file.create();
    return file;
  }

  /// Verifica se é necessário rotacionar logs
  Future<void> _checkLogRotation() async {
    try {
      if (!await _currentLogFile.exists()) {
        _currentLogFile = await _createNewLogFile();
        return;
      }

      final fileSize = await _currentLogFile.length();

      if (fileSize >= SecurityConstants.MAX_LOG_FILE_SIZE) {
        // Rotacionar log
        _currentLogFile = await _createNewLogFile();
        await _cleanupOldLogs();
      }
    } catch (e) {
      stderr.writeln('Erro ao verificar rotação de logs: $e');
    }
  }

  /// Remove logs antigos (mantém apenas os N mais recentes)
  Future<void> _cleanupOldLogs() async {
    try {
      final files = _logsDirectory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.enc'))
          .toList();

      if (files.length > SecurityConstants.MAX_LOG_FILES) {
        files.sort((a, b) => a.statSync().modified.compareTo(
            b.statSync().modified));

        // Remover os arquivos mais antigos
        for (int i = 0; i < files.length - SecurityConstants.MAX_LOG_FILES; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      stderr.writeln('Erro ao limpar logs antigos: $e');
    }
  }

  /// Log genérico
  Future<void> log(
    LogLevel level,
    String message, {
    String? tag,
    String? stackTrace,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_initialized) await initialize();

    final entry = LogEntry(
      level: level,
      message: message,
      tag: tag ?? 'App',
      stackTrace: stackTrace,
      metadata: metadata,
    );

    // Armazenar em memória
    _memoryBuffer.add(entry);
    if (_memoryBuffer.length > 1000) {
      _memoryBuffer.removeAt(0); // Manter limite de memória
    }

    // Log em arquivo criptografado
    await _logToEncryptedFile(entry);

    // Log em console (debug)
    stderr.writeln(entry.toFormattedString());
  }

  /// Log DEBUG
  Future<void> debug(String message, [String? tag]) async {
    await log(LogLevel.debug, message, tag: tag ?? 'DEBUG');
  }

  /// Log INFO
  Future<void> info(String message, [String? tag]) async {
    await log(LogLevel.info, message, tag: tag ?? 'INFO');
  }

  /// Log WARNING
  Future<void> warning(String message, [String? tag]) async {
    await log(LogLevel.warning, message, tag: tag ?? 'WARNING');
  }

  /// Log ERROR
  Future<void> error(String message, [String? tag]) async {
    await log(LogLevel.error, message, tag: tag ?? 'ERROR');
  }

  /// Log CRITICAL
  Future<void> critical(String message, [String? tag]) async {
    await log(LogLevel.critical, message, tag: tag ?? 'CRITICAL');
  }

  /// Log interna (para o serviço de logging)
  void _logInternal(LogLevel level, String message, String tag) {
    final entry = LogEntry(
      level: level,
      message: message,
      tag: tag,
    );
    stderr.writeln(entry.toFormattedString());
  }

  /// Escreve log em arquivo criptografado
  Future<void> _logToEncryptedFile(LogEntry entry) async {
    try {
      await _checkLogRotation();

      final jsonString = jsonEncode(entry.toMap());
      final encrypted = CryptoManager.encryptAES256GCM(
        jsonString,
        _encryptionKey,
      );

      // Adicionar linha ao arquivo
      await _currentLogFile.writeAsString(
        '$encrypted\n',
        mode: FileMode.append,
      );
    } catch (e) {
      stderr.writeln('Erro ao escrever log criptografado: $e');
    }
  }

  /// Obtém logs em memória (últimas N entradas)
  List<LogEntry> getMemoryLogs({int limit = 100}) {
    return _memoryBuffer.skip((_memoryBuffer.length - limit).clamp(0, _memoryBuffer.length))
        .toList();
  }

  /// Lê e decripta arquivo de log
  Future<List<LogEntry>> readLogFile(File logFile) async {
    try {
      final contents = await logFile.readAsString();
      final lines = contents.split('\n').where((l) => l.isNotEmpty).toList();

      final entries = <LogEntry>[];
      for (final line in lines) {
        try {
          final decrypted = CryptoManager.decryptAES256GCM(line, _encryptionKey);
          final json = jsonDecode(decrypted) as Map<String, dynamic>;

          entries.add(
            LogEntry(
              id: json['id'],
              level: LogLevel.values.firstWhere(
                (e) => e.name == json['level'],
                orElse: () => LogLevel.info,
              ),
              message: json['message'],
              tag: json['tag'],
              stackTrace: json['stackTrace'],
              timestamp: DateTime.parse(json['timestamp']),
              metadata: json['metadata'],
            ),
          );
        } catch (e) {
          // Pular linhas inválidas
          continue;
        }
      }

      return entries;
    } catch (e) {
      throw Exception('Erro ao ler arquivo de log: $e');
    }
  }

  /// Obtém todos os logs salvos
  Future<List<LogEntry>> getAllLogs() async {
    try {
      final files = _logsDirectory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.enc'))
          .toList();

      files.sort((a, b) =>
          a.statSync().modified.compareTo(b.statSync().modified));

      final allEntries = <LogEntry>[];
      for (final file in files) {
        allEntries.addAll(await readLogFile(file));
      }

      return allEntries;
    } catch (e) {
      return [];
    }
  }

  /// Exporta logs em formato seguro
  Future<String> exportLogsSecure() async {
    try {
      final logs = await getAllLogs();
      final jsonString = jsonEncode(
        logs.map((e) => e.toMap()).toList(),
      );

      // Encriptar todo o export
      final encrypted = CryptoManager.encryptAES256GCM(
        jsonString,
        _encryptionKey,
      );

      return encrypted;
    } catch (e) {
      throw Exception('Erro ao exportar logs: $e');
    }
  }

  /// Limpa todos os logs
  Future<void> clearLogs() async {
    try {
      _memoryBuffer.clear();

      final files = _logsDirectory.listSync().whereType<File>();
      for (final file in files) {
        await file.delete();
      }

      _currentLogFile = await _createNewLogFile();
    } catch (e) {
      stderr.writeln('Erro ao limpar logs: $e');
    }
  }
}


