import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../bloc/protection_bloc.dart';
import '../widgets/protection_widgets.dart';
import '../../domain/entities/entities.dart';
import '../../security/device_integrity/device_integrity_service.dart';

class SecurityScanResult {
  final bool hasUnsafeApps;
  final bool hasMalware;
  final bool hasTracking;
  final bool hasActiveMonitoring;
  final bool hasPhoneTapRisk;
  final bool phoneTapBlockingEnabled;
  final List<String> findings;
  final DateTime scannedAt;

  SecurityScanResult({
    required this.hasUnsafeApps,
    required this.hasMalware,
    required this.hasTracking,
    required this.hasActiveMonitoring,
    required this.hasPhoneTapRisk,
    required this.phoneTapBlockingEnabled,
    required this.findings,
    required this.scannedAt,
  });

  bool get hasCriticalRisk =>
      hasUnsafeApps ||
      hasMalware ||
      hasTracking ||
      hasActiveMonitoring ||
      hasPhoneTapRisk;

  int get safetyScore {
    final signals = [
      !hasUnsafeApps,
      !hasMalware,
      !hasTracking,
      !hasActiveMonitoring,
      !hasPhoneTapRisk,
    ];
    final safeCount = signals.where((s) => s).length;
    return ((safeCount / signals.length) * 100).round();
  }
}

/// Página principal de proteção
class ProtectionPage extends StatefulWidget {
  const ProtectionPage({Key? key}) : super(key: key);

  @override
  State<ProtectionPage> createState() => _ProtectionPageState();
}

class _ProtectionPageState extends State<ProtectionPage> {
  final List<String> _logEntries = [];
  final DeviceIntegrityService _integrityService = DeviceIntegrityService();

  bool _isScanning = false;
  bool _runScanBeforeActivation = true;
  bool _phoneTapShieldEnabled = true;
  SecurityScanResult? _lastScan;

  int _coverageScore(ProtectionStatus status) {
    final checks = [
      status.isVPNActive,
      status.isKillSwitchActive,
      status.dohEnabled,
      status.antiFingerprinting,
      status.threatDetectionActive,
    ];

    final activeCount = checks.where((item) => item).length;
    return ((activeCount / checks.length) * 100).round();
  }

  String _confidenceMessage(ProtectionStatus status) {
    final score = _coverageScore(status);
    if (score >= 90 && status.activeThreats.isEmpty) {
      return 'Excelente: sua sessao esta com cobertura de protecao muito alta.';
    }
    if (score >= 60) {
      return 'Boa: suas camadas principais estao ligadas e monitoradas.';
    }
    return 'Atencao: ative a protecao para elevar sua cobertura de seguranca.';
  }

  Widget _buildProtectionAgainstItem({
    required String risk,
    required bool protected,
    required String details,
  }) {
    final color = protected ? Colors.green : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: protected ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: protected ? Colors.green[200]! : Colors.orange[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            protected ? Icons.shield : Icons.info_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  risk,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(details, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionConfidencePanel(ProtectionStatus status) {
    final score = _coverageScore(status);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seu nivel de protecao agora',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      minHeight: 10,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        score >= 80
                            ? Colors.green
                            : score >= 50
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$score%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_confidenceMessage(status), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 14),
            const Text(
              'Voce esta protegido contra',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildProtectionAgainstItem(
              risk: 'Vazamento de DNS',
              protected: status.dohEnabled,
              details: status.dohEnabled
                  ? 'DoH ligado para reduzir exposicao das consultas de dominio.'
                  : 'Ative DoH para criptografar consultas DNS.',
            ),
            _buildProtectionAgainstItem(
              risk: 'Exposicao de identidade digital',
              protected: status.antiFingerprinting,
              details: status.antiFingerprinting
                  ? 'Headers e metadados sao mascarados para reduzir rastreio.'
                  : 'Ative anti-fingerprinting para reduzir correlacao de sessao.',
            ),
            _buildProtectionAgainstItem(
              risk: 'Queda de tunel com vazamento de trafego',
              protected: status.isKillSwitchActive,
              details: status.isKillSwitchActive
                  ? 'Kill Switch habilitado para bloquear trafego em caso de queda.'
                  : 'Ative Kill Switch para evitar vazamento em desconexao.',
            ),
            _buildProtectionAgainstItem(
              risk: 'Risco de ambiente comprometido',
              protected: status.threatDetectionActive,
              details: status.threatDetectionActive
                  ? 'Monitoramento de integridade ativo com analise de ameaças.'
                  : 'Ative deteccao continua para alertas de integridade.',
            ),
          ],
        ),
      ),
    );
  }

  ProtectionStatus _statusFromState(ProtectionState state) {
    if (state is ProtectionActive) {
      return state.status;
    }

    return ProtectionStatus(
      isVPNActive: false,
      isKillSwitchActive: false,
      dohEnabled: false,
      antiFingerprinting: false,
      threatDetectionActive: false,
      activeThreats: const [],
      lastChecked: DateTime.now(),
      bytesTransferred: 0,
      currentServerLocation: 'Desconectado',
    );
  }

  Future<SecurityScanResult> _runSecurityScan({bool silent = false}) async {
    setState(() {
      _isScanning = true;
    });

    try {
      final integrity = await _integrityService.checkDeviceIntegrity();
      final findings = <String>[...integrity.threats];

      bool hasPhoneTapRisk = false;
      if (!kIsWeb) {
        try {
          final micStatus = await Permission.microphone.status;
          final phoneStatus = await Permission.phone.status;
          hasPhoneTapRisk = micStatus.isGranted || phoneStatus.isGranted;
          if (hasPhoneTapRisk) {
            findings.add(
              'Risco de escuta telefonica: permissoes sensiveis de audio/telefone ativas.',
            );
          }
        } catch (_) {
          findings.add('Nao foi possivel validar permissao de audio/telefone.');
        }
      }

      final hasUnsafeApps =
          integrity.isRooted || integrity.isJailbroken || integrity.hasMockLocation;
      final hasMalware = integrity.isRooted || integrity.isJailbroken;
      final hasTracking = integrity.hasUnauthorizedProxies;
      final hasActiveMonitoring =
          integrity.hasUnauthorizedProxies || integrity.hasMockLocation;

      final isProtectionActive =
          context.read<ProtectionBloc>().state is ProtectionActive;

      final result = SecurityScanResult(
        hasUnsafeApps: hasUnsafeApps,
        hasMalware: hasMalware,
        hasTracking: hasTracking,
        hasActiveMonitoring: hasActiveMonitoring,
        hasPhoneTapRisk: hasPhoneTapRisk,
        phoneTapBlockingEnabled: _phoneTapShieldEnabled && isProtectionActive,
        findings: findings,
        scannedAt: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _lastScan = result;
        });

        if (!silent) {
          _addLogEntry(
            result.hasCriticalRisk
                ? '⚠️ Varredura detectou riscos - score ${result.safetyScore}%'
                : '✅ Varredura concluida - dispositivo seguro (${result.safetyScore}%)',
          );
        }
      }

      return result;
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<bool> _confirmActivationWithRisk(SecurityScanResult result) async {
    if (!result.hasCriticalRisk) {
      return true;
    }

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Riscos detectados na varredura'),
          content: Text(
            'Foram encontrados sinais de risco no dispositivo.\n'
            'Score atual: ${result.safetyScore}%\n\n'
            'Deseja ativar a protecao total mesmo assim?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ativar mesmo assim'),
            ),
          ],
        );
      },
    );

    return shouldProceed ?? false;
  }

  Widget _buildScanResultRow(String label, bool issueFound) {
    final ok = !issueFound;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            ok ? Icons.verified : Icons.warning_amber_rounded,
            color: ok ? Colors.green : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            ok ? 'OK' : 'RISCO',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ok ? Colors.green : Colors.orange,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityScanPanel() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Varredura Inteligente do Dispositivo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Execute a varredura para validar risco antes da ativacao total da protecao.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : () => _runSecurityScan(),
                    icon: _isScanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.security),
                    label: Text(_isScanning ? 'Varrendo...' : 'Fazer varredura agora'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Executar varredura antes da ativacao total',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              value: _runScanBeforeActivation,
              onChanged: (value) {
                setState(() {
                  _runScanBeforeActivation = value;
                });
              },
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Bloqueio reforcado contra escuta telefonica',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Aciona bloqueio agressivo quando a protecao total esta ativa.',
                style: TextStyle(fontSize: 11),
              ),
              value: _phoneTapShieldEnabled,
              onChanged: (value) {
                setState(() {
                  _phoneTapShieldEnabled = value;
                });
              },
            ),
            if (_lastScan != null) ...[
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Resultado da ultima varredura',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '${_lastScan!.safetyScore}% seguro',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _lastScan!.safetyScore >= 80 ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildScanResultRow(
                'Verificar apps nao seguros',
                _lastScan!.hasUnsafeApps,
              ),
              _buildScanResultRow(
                'Verificar sinais de malware',
                _lastScan!.hasMalware,
              ),
              _buildScanResultRow(
                'Verificar rastreio e interceptacao',
                _lastScan!.hasTracking,
              ),
              _buildScanResultRow(
                'Verificar monitoramento ativo suspeito',
                _lastScan!.hasActiveMonitoring,
              ),
              _buildScanResultRow(
                'Verificar risco de escuta telefonica',
                _lastScan!.hasPhoneTapRisk,
              ),
              _buildScanResultRow(
                'Bloqueio anti-escuta em modo reforcado',
                !_lastScan!.phoneTapBlockingEnabled,
              ),
              if (_lastScan!.findings.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Text(
                    _lastScan!.findings.join('\n'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureDetail({
    required String title,
    required bool active,
    required String whatItProtects,
    required String webBehavior,
  }) {
    final color = active ? Colors.green : Colors.grey[600]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? Colors.green[200]! : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                active ? Icons.verified_user : Icons.remove_circle_outline,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Text(
                active ? 'ATIVO' : 'INATIVO',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Protege: $whatItProtects',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'No painel Web: $webBehavior',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWebProtectionDetails(ProtectionStatus status, bool hasErrorState) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Painel Web: O que esta protegido agora',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Esta secao mostra todas as funcoes disponiveis no navegador e o nivel real de cobertura de cada uma.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 14),
            _buildFeatureDetail(
              title: 'Tunel VPN e status de conexao',
              active: status.isVPNActive,
              whatItProtects: 'Sigilo de rota e encapsulamento do trafego do app.',
              webBehavior: 'No Web, o painel valida o fluxo de ligar/desligar e status. O tunel de sistema operacional nao e aplicado no navegador.',
            ),
            _buildFeatureDetail(
              title: 'Kill Switch',
              active: status.isKillSwitchActive,
              whatItProtects: 'Evita vazamento de trafego quando a VPN cai.',
              webBehavior: 'No Web, representa o estado de protecao no app. Bloqueio global de rede (iptables/Network Extension) e recurso nativo de Android/iOS.',
            ),
            _buildFeatureDetail(
              title: 'DNS sobre HTTPS (DoH)',
              active: status.dohEnabled,
              whatItProtects: 'Privacidade das consultas DNS e menor exposicao a interceptacao.',
              webBehavior: 'Ativo no fluxo de requisicoes HTTP do app (Dio), com servidores e fallback configurados.',
            ),
            _buildFeatureDetail(
              title: 'Anti-Fingerprinting',
              active: status.antiFingerprinting,
              whatItProtects: 'Reduz rastreio por User-Agent, idioma, headers e metadados de cliente.',
              webBehavior: 'Aplicado no cabecalho das requisicoes do app e rotacao de valores para reduzir correlacao.',
            ),
            _buildFeatureDetail(
              title: 'Deteccao de ameacas e integridade',
              active: status.threatDetectionActive,
              whatItProtects: 'Alerta sobre risco de root/jailbreak, ambiente inseguro e sinais de comprometimento.',
              webBehavior: hasErrorState
                  ? 'Erro no estado atual. Verifique o card de erro acima para diagnostico.'
                  : 'No navegador, verificacoes nativas profundas ficam limitadas; o painel continua exibindo status e resumo de riscos.',
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                status.activeThreats.isEmpty
                    ? 'Resumo atual: nenhuma ameaca ativa detectada no estado atual.'
                    : 'Resumo atual de ameacas: ${status.threatsSummary}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Cobertura atual da versao Web',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              '• Protege o fluxo interno do app com politicas de privacidade e status de seguranca\n'
              '• Exibe monitoramento, risco e eventos para validacao funcional\n'
              '• Nao substitui as protecoes nativas de rede em nivel de sistema (Android/iOS)',
              style: TextStyle(fontSize: 12),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[300]!),
                ),
                child: const Text(
                  'Ambiente Web detectado: este painel foi desenhado para demonstrar e validar as funcionalidades de seguranca sem depender de VPN nativa no dispositivo.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Carregar status inicial
    context.read<ProtectionBloc>().add(const GetStatusEvent());
  }

  Future<void> _toggleProtection() async {
    final state = context.read<ProtectionBloc>().state;

    if (state is ProtectionActive) {
      context.read<ProtectionBloc>().add(const StopProtectionEvent());
    } else {
      if (_runScanBeforeActivation) {
        final scanResult = await _runSecurityScan(silent: true);
        final canProceed = await _confirmActivationWithRisk(scanResult);
        if (!canProceed) {
          _addLogEntry('🛑 Ativacao cancelada apos varredura de risco.');
          return;
        }
      }

      final defaultConfig = AppConfiguration();
      context.read<ProtectionBloc>().add(StartProtectionEvent(defaultConfig));

      if (_phoneTapShieldEnabled) {
        _addLogEntry('🛡️ Escudo anti-escuta telefonica ativado com protecao total.');
      }
    }
  }

  void _addLogEntry(String entry) {
    setState(() {
      _logEntries.insert(0, entry);
      if (_logEntries.length > 50) {
        _logEntries.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocListener<ProtectionBloc, ProtectionState>(
          listener: (context, state) {
            if (state is ProtectionActive) {
              _addLogEntry('✅ VPN Conectada - ${DateTime.now().toIso8601String()}');
            } else if (state is ProtectionInactive) {
              _addLogEntry('🔓 VPN Desconectada - ${DateTime.now().toIso8601String()}');
            } else if (state is ProtectionError) {
              _addLogEntry('❌ Erro: ${state.message}');
            }
          },
          child: CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                toolbarHeight: 80,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue[900]!,
                          Colors.blue[700]!,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.privacy_tip_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'App Invisível',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Conteúdo
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Painel de varredura antes da ativacao total
                    _buildSecurityScanPanel(),
                    const SizedBox(height: 20),

                    // Botão Central de Proteção
                    Center(
                      child: BlocBuilder<ProtectionBloc, ProtectionState>(
                        builder: (context, state) {
                          final isActive = state is ProtectionActive;
                          final isLoading = state is ProtectionLoading;

                          return ProtectionToggleButton(
                            isActive: isActive,
                            isLoading: isLoading,
                            onToggle: _toggleProtection,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Card de Status
                    BlocBuilder<ProtectionBloc, ProtectionState>(
                      builder: (context, state) {
                        if (state is ProtectionActive) {
                          final status = state.status;
                          return ProtectionStatusCard(
                            isVPNActive: status.isVPNActive,
                            isKillSwitchActive: status.isKillSwitchActive,
                            dohEnabled: status.dohEnabled,
                            antiFingerprinting: status.antiFingerprinting,
                            riskLevel: status.riskLevel,
                            threatsSummary: status.threatsSummary,
                          );
                        } else if (state is ProtectionInactive) {
                          return ProtectionStatusCard(
                            isVPNActive: false,
                            isKillSwitchActive: false,
                            dohEnabled: false,
                            antiFingerprinting: false,
                            riskLevel: 0,
                            threatsSummary: 'Proteção desativada',
                          );
                        } else if (state is ProtectionError) {
                          return Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    state.message,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Bloco de confianca e protecoes detalhadas
                    BlocBuilder<ProtectionBloc, ProtectionState>(
                      builder: (context, state) {
                        final status = _statusFromState(state);
                        return _buildProtectionConfidencePanel(status);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Detalhamento completo da versao Web
                    BlocBuilder<ProtectionBloc, ProtectionState>(
                      builder: (context, state) {
                        final status = _statusFromState(state);
                        return _buildWebProtectionDetails(
                          status,
                          state is ProtectionError,
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Log de Conexões
                    ConnectionLogWidget(logEntries: _logEntries),
                    const SizedBox(height: 24),

                    // Info Footer
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ℹ️ Informações',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Kill Switch bloqueia tráfego se VPN cair\n'
                            '• DNS sobre HTTPS (DoH) garante privacidade\n'
                            '• Anti-Fingerprinting mascara sua identidade\n'
                            '• Detecção contínua de ameaças',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
