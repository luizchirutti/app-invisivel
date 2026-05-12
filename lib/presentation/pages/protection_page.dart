import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../bloc/protection_bloc.dart';
import '../widgets/protection_widgets.dart';
import '../../domain/entities/entities.dart';
import '../../security/device_integrity/device_integrity_service.dart';
import '../../services/notifications/security_alert_service.dart';
import '../../services/security/duress_security_service.dart';

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
  final SecurityAlertService _alertService = SecurityAlertService();
  final DuressSecurityService _duressSecurityService = DuressSecurityService();
  final TextEditingController _unlockController = TextEditingController();
  static const MethodChannel _vpnChannel = MethodChannel('com.infinityprox/vpn');
  static const MethodChannel _securityChannel = MethodChannel('com.infinityprox/security');

  bool _isScanning = false;
  bool _runScanBeforeActivation = true;
  bool _phoneTapShieldEnabled = true;
  bool _autoBlockOnCriticalRisk = true;
  bool _isDuressPinConfigured = false;
  bool _isUnlockPinConfigured = false;
  bool _isSafetyModeEnabled = false;
  bool _isDeviceAdminActive = false;
  bool _notificationPermissionGranted = true;
  bool _fullScreenIntentPermissionGranted = true;
  bool _accessibilityServiceEnabled = true;
  SecurityScanResult? _lastScan;
  List<String> _customBlocklistPackages = [
    'com.flexispy.android',
    'com.mspy.android',
    'com.cerberus',
  ];
  List<String> _customAllowlistPackages = [];

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

  Widget _buildSessionCertificate(ProtectionStatus status) {
    final scan = _lastScan;
    final coverage = _coverageScore(status);
    final isCertified =
        status.isFullyProtected &&
        coverage == 100 &&
        scan != null &&
        !scan.hasCriticalRisk;

    final certificateId =
        'SEC-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    return Card(
      elevation: 4,
      color: isCertified ? Colors.green[50] : Colors.orange[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isCertified ? Colors.green : Colors.orange),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCertified ? Icons.verified_user : Icons.gpp_maybe,
                  color: isCertified ? Colors.green[800] : Colors.orange[800],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCertified
                        ? 'Certificado de Sessao Segura: 100% protegido'
                        : 'Certificado de Sessao: cobertura parcial',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isCertified
                  ? 'Seu dispositivo e sessao passaram na varredura e todas as camadas criticas estao ativas.'
                  : 'Execute varredura e ative protecao total para elevar o certificado a 100% seguro.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'ID do certificado: $certificateId',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Emitido em: ${DateTime.now().toLocal()}',
              style: const TextStyle(fontSize: 11),
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

  bool _isIosVpnPermissionError(String message) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }

    final lower = message.toLowerCase();
    return lower.contains('vpn_load_error') ||
        lower.contains('permission denied') ||
        lower.contains('vpn_save_error') ||
        lower.contains('neconfigurationerror');
  }

  Future<SecurityScanResult> _runSecurityScan({bool silent = false}) async {
    setState(() {
      _isScanning = true;
    });

    try {
      final integrity = await _integrityService.checkDeviceIntegrity();
      final findings = <String>[...integrity.threats];

      bool hasPhoneTapRisk = false;
      bool hasUnsafeApps =
          integrity.isRooted || integrity.isJailbroken || integrity.hasMockLocation;
      bool hasMalware = integrity.isRooted || integrity.isJailbroken;
      bool hasTracking = integrity.hasUnauthorizedProxies;
      bool hasActiveMonitoring =
          integrity.hasUnauthorizedProxies || integrity.hasMockLocation;

      List<String> suspiciousApps = [];

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final nativeScan = await _securityChannel.invokeMapMethod<String, dynamic>(
            'runAdvancedSecurityScan',
            {
              'customBlocklist': _customBlocklistPackages,
              'customAllowlist': _customAllowlistPackages,
            },
          );

          if (nativeScan != null) {
            hasUnsafeApps = (nativeScan['hasUnsafeApps'] as bool?) ?? hasUnsafeApps;
            hasMalware = (nativeScan['hasMalware'] as bool?) ?? hasMalware;
            hasTracking = (nativeScan['hasTracking'] as bool?) ?? hasTracking;
            hasActiveMonitoring =
                (nativeScan['hasActiveMonitoring'] as bool?) ?? hasActiveMonitoring;
            hasPhoneTapRisk = (nativeScan['hasPhoneTapRisk'] as bool?) ?? hasPhoneTapRisk;

            suspiciousApps = ((nativeScan['suspiciousApps'] as List?) ?? const [])
                .map((item) => item.toString())
                .toList();
            final nativeFindings = ((nativeScan['findings'] as List?) ?? const [])
                .map((item) => item.toString())
                .toList();

            findings.addAll(nativeFindings);
            if (suspiciousApps.isNotEmpty) {
              findings.add('Apps suspeitos: ${suspiciousApps.join(', ')}');
            }
          }
        } catch (_) {
          findings.add('Varredura nativa avancada nao disponivel neste dispositivo.');
        }
      }

      if (suspiciousApps.isNotEmpty && _customAllowlistPackages.isNotEmpty) {
        suspiciousApps = suspiciousApps
            .where(
              (pkg) => !_customAllowlistPackages.any(
                (allowed) => pkg.toLowerCase() == allowed.toLowerCase(),
              ),
            )
            .toList();
      }

      if (suspiciousApps.isNotEmpty && _customBlocklistPackages.isNotEmpty) {
        final customHits = suspiciousApps.where(
          (pkg) => _customBlocklistPackages.any(
            (blocked) => pkg.toLowerCase() == blocked.toLowerCase(),
          ),
        );
        if (customHits.isNotEmpty) {
          findings.add(
            'Lista negra personalizada acionada: ${customHits.join(', ')}',
          );
        }
      }

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

        if (result.hasCriticalRisk) {
          await _alertService.upsertReminder(
            reasonKey: 'suspicious_activity',
            title: 'Atividade suspeita detectada',
            body: result.findings.isNotEmpty
                ? result.findings.first
                : 'Foram detectados riscos no dispositivo.',
          );
        } else {
          _alertService.clearReminder('suspicious_activity');
        }

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

  Future<void> _activateEmergencyBlock() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _vpnChannel.invokeMapMethod<String, dynamic>('triggerEmergencyBlock');
      }
      _addLogEntry('🚨 Bloqueio automatico ativado por risco critico detectado.');
    } catch (_) {
      _addLogEntry('⚠️ Falha ao acionar bloqueio nativo de emergencia.');
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

  Future<void> _editPackageList({
    required String title,
    required bool isBlocklist,
  }) async {
    final currentList = isBlocklist
        ? _customBlocklistPackages
        : _customAllowlistPackages;
    final controller = TextEditingController(text: currentList.join(', '));

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'com.app.exemplo, com.outro.pacote',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final values = controller.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toSet()
                    .toList();
                Navigator.of(context).pop(values);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        if (isBlocklist) {
          _customBlocklistPackages = result;
        } else {
          _customAllowlistPackages = result;
        }
      });
      _addLogEntry(
        isBlocklist
            ? '⚙️ Lista negra atualizada (${result.length} itens).'
            : '⚙️ Lista branca atualizada (${result.length} itens).',
      );
    }
  }

  Widget _buildPackageListChips(List<String> values, Color color) {
    if (values.isEmpty) {
      return const Text(
        'Nenhum item configurado',
        style: TextStyle(fontSize: 11),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: values
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(item, style: const TextStyle(fontSize: 10)),
            ),
          )
          .toList(),
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
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Bloqueio automatico quando risco for critico',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Se detectar risco critico, bloqueia automaticamente e impede ativacao.',
                style: TextStyle(fontSize: 11),
              ),
              value: _autoBlockOnCriticalRisk,
              onChanged: (value) {
                setState(() {
                  _autoBlockOnCriticalRisk = value;
                });
              },
            ),
            const SizedBox(height: 6),
            const Text(
              'Deteccao personalizada de apps suspeitos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editPackageList(
                      title: 'Editar lista negra (apps suspeitos)',
                      isBlocklist: true,
                    ),
                    icon: const Icon(Icons.block),
                    label: const Text('Editar lista negra'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editPackageList(
                      title: 'Editar lista branca (apps permitidos)',
                      isBlocklist: false,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Editar lista branca'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Lista negra ativa:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            _buildPackageListChips(_customBlocklistPackages, Colors.red.shade100),
            const SizedBox(height: 8),
            const Text(
              'Lista branca ativa:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            _buildPackageListChips(_customAllowlistPackages, Colors.green.shade100),
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

  Future<void> _loadDuressPinStatus() async {
    final duressConfigured = await _duressSecurityService.isDuressPinConfigured();
    final unlockConfigured = await _duressSecurityService.isUnlockPinConfigured();
    final safetyModeEnabled = await _duressSecurityService.isSafetyModeEnabled();
    final adminActive = await _duressSecurityService.isDeviceAdminActive();
    final fullScreenPermission = await _duressSecurityService.isFullScreenIntentPermissionGranted();
    final accessibilityEnabled = await _duressSecurityService.isAccessibilityServiceEnabled();
    final notificationPermission = kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        await Permission.notification.isGranted;
    if (!mounted) return;
    setState(() {
      _isDuressPinConfigured = duressConfigured;
      _isUnlockPinConfigured = unlockConfigured;
      _isSafetyModeEnabled = safetyModeEnabled && duressConfigured && unlockConfigured;
      _isDeviceAdminActive = adminActive;
      _notificationPermissionGranted = notificationPermission;
      _fullScreenIntentPermissionGranted = fullScreenPermission;
      _accessibilityServiceEnabled = accessibilityEnabled;
    });
  }

  Future<bool> _ensureCriticalSafetyPermissions({required bool interactive}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    var notificationGranted = await Permission.notification.isGranted;
    if (!notificationGranted && interactive) {
      final status = await Permission.notification.request();
      notificationGranted = status.isGranted;
      if (!notificationGranted) {
        await openAppSettings();
      }
    }

    var fullScreenGranted = await _duressSecurityService.isFullScreenIntentPermissionGranted();
    if (!fullScreenGranted && interactive) {
      await _duressSecurityService.openFullScreenIntentSettings();
      fullScreenGranted = await _duressSecurityService.isFullScreenIntentPermissionGranted();
    }

    var accessibilityGranted = await _duressSecurityService.isAccessibilityServiceEnabled();
    if (!accessibilityGranted && interactive) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permissão de Acessibilidade'),
            content: const Text(
              'Para bloquear outros apps até o PIN ser digitado, ative o serviço '
              '"Modo Segurança" em Configurações → Acessibilidade.\n\n'
              'Ele NÃO lê conteúdo de tela nem envia dados. Apenas detecta troca de app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Agora não'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _duressSecurityService.openAccessibilitySettings();
                },
                child: const Text('Abrir Configurações'),
              ),
            ],
          ),
        );
      }
      accessibilityGranted = await _duressSecurityService.isAccessibilityServiceEnabled();
    }

    if (!mounted) {
      return notificationGranted && fullScreenGranted;
    }

    setState(() {
      _notificationPermissionGranted = notificationGranted;
      _fullScreenIntentPermissionGranted = fullScreenGranted;
      _accessibilityServiceEnabled = accessibilityGranted;
    });

    return notificationGranted && fullScreenGranted;
  }

  Future<void> _configureUnlockPin() async {
    final pin = await _showPinDialog(
      title: 'Configurar PIN seguro',
      pinLabel: 'PIN seguro (4-8 digitos)',
      confirmLabel: 'Confirmar PIN seguro',
    );

    if (pin == null) return;

    final matchesDuress = await _duressSecurityService.verifyDuressPin(pin);
    if (matchesDuress) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN seguro nao pode ser igual ao PIN de coacao.')),
      );
      return;
    }

    try {
      await _duressSecurityService.saveUnlockPin(pin);
      await _loadDuressPinStatus();
      _addLogEntry('🔐 PIN seguro configurado com sucesso.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN seguro salvo com sucesso.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao salvar PIN seguro. Tente novamente.')),
      );
    }
  }

  Future<void> _toggleSafetyMode(bool enabled) async {
    if (enabled && (!_isDuressPinConfigured || !_isUnlockPinConfigured)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure o PIN seguro e o PIN de coacao antes de ativar o modo seguranca.'),
        ),
      );
      return;
    }

    if (enabled) {
      final permissionsReady = await _ensureCriticalSafetyPermissions(interactive: true);
      if (!permissionsReady) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permissoes criticas ausentes. Libere notificacoes e Full Screen Intent para forcar retorno imediato.',
            ),
          ),
        );
        return;
      }
    }

    await _duressSecurityService.setSafetyModeEnabled(enabled);
    await _loadDuressPinStatus();
    _addLogEntry(enabled
        ? '🛡️ Modo seguranca ativado. O app exigira PIN ao abrir/retomar.'
        : 'ℹ️ Modo seguranca desativado.');
  }

  Future<void> _configureDuressPin() async {
    final pin = await _showPinDialog(
      title: 'Configurar senha de coacao',
      pinLabel: 'PIN de coacao (4-8 digitos)',
      confirmLabel: 'Confirmar PIN de coacao',
    );

    if (pin == null) return;

    final matchesUnlock = await _duressSecurityService.verifyUnlockPin(pin);
    if (matchesUnlock) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN de coacao nao pode ser igual ao PIN seguro.')),
      );
      return;
    }

    try {
      await _duressSecurityService.saveDuressPin(pin);
      await _loadDuressPinStatus();
      _addLogEntry('🛡️ Senha de coacao configurada com sucesso.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN de coacao salvo com sucesso.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao salvar PIN de coacao. Tente novamente.')),
      );
    }
  }

  Future<String?> _showPinDialog({
    required String title,
    required String pinLabel,
    required String confirmLabel,
  }) async {
    String pinValue = '';
    String confirmValue = '';
    String? validationError;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 8,
                    obscureText: true,
                    onChanged: (value) {
                      pinValue = value.trim();
                    },
                    decoration: InputDecoration(
                      labelText: pinLabel,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 8,
                    obscureText: true,
                    onChanged: (value) {
                      confirmValue = value.trim();
                    },
                    decoration: InputDecoration(
                      labelText: confirmLabel,
                      counterText: '',
                      errorText: validationError,
                    ),
                    onSubmitted: (_) {
                      final validLength = pinValue.length >= 4 && pinValue.length <= 8;
                      final validDigits = RegExp(r'^\d+$').hasMatch(pinValue);

                      if (!validLength || !validDigits || pinValue != confirmValue) {
                        setDialogState(() {
                          validationError =
                              'PIN invalido. Use 4-8 digitos e confirme corretamente.';
                        });
                        return;
                      }

                      Navigator.of(dialogContext).pop(pinValue);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final validLength = pinValue.length >= 4 && pinValue.length <= 8;
                    final validDigits = RegExp(r'^\d+$').hasMatch(pinValue);

                    if (!validLength || !validDigits || pinValue != confirmValue) {
                      setDialogState(() {
                        validationError =
                            'PIN invalido. Use 4-8 digitos e confirme corretamente.';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(pinValue);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _disableDuressPin() async {
    await _duressSecurityService.setSafetyModeEnabled(false);
    await _duressSecurityService.disableDuressPin();
    await _loadDuressPinStatus();
    _addLogEntry('ℹ️ Senha de coacao desativada e modo seguranca desligado.');
  }

  Future<void> _handleUnlockAttempt() async {
    final entered = _unlockController.text.trim();
    if (entered.isEmpty) return;

    final isDuress = await _duressSecurityService.verifyDuressPin(entered);
    _unlockController.clear();

    if (!isDuress) {
      _addLogEntry('🔐 Tentativa de desbloqueio registrada.');
      return;
    }

    // PIN de coação confirmado — parar proteção e disparar alerta
    if (mounted) {
      context.read<ProtectionBloc>().add(const StopProtectionEvent());
    }
    await _alertService.upsertReminder(
      reasonKey: 'duress_triggered',
      title: 'Modo de coacao acionado',
      body: 'Reset de seguranca executado. Verifique a conta imediatamente.',
    );

    // Tentar reset de fábrica via Device Admin
    final factoryResetTriggered = await _duressSecurityService.performFactoryReset();

    if (factoryResetTriggered) {
      // wipeData() será chamado em 500ms pelo nativo — app vai encerrar
      return;
    }

    // Fallback: reset local (apaga dados do app)
    await _duressSecurityService.executeLocalSecurityReset();

    if (!mounted) return;
    _addLogEntry('🚨 Senha de coacao acionada: reset local executado (Device Admin inativo).');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Operacao de seguranca executada. Ative o admin do dispositivo para reset completo.'),
      ),
    );
    await _loadDuressPinStatus();
  }

  Widget _buildDuressPanel() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modo seguranca (2 senhas)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Quando ativo, o app cria uma segunda tela de bloqueio ao abrir/retomar. Use PIN seguro para acesso normal e PIN de coacao para reset de seguranca.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),

            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (_notificationPermissionGranted && _fullScreenIntentPermissionGranted)
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_notificationPermissionGranted && _fullScreenIntentPermissionGranted)
                        ? Colors.green[300]!
                        : Colors.red[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (_notificationPermissionGranted && _fullScreenIntentPermissionGranted)
                          ? 'Permissoes de resposta imediata: OK'
                          : 'Permissoes criticas pendentes para resposta imediata',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (_notificationPermissionGranted && _fullScreenIntentPermissionGranted)
                            ? Colors.green[900]
                            : Colors.red[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Notificacoes: ${_notificationPermissionGranted ? 'liberado' : 'bloqueado'} | Full Screen Intent: ${_fullScreenIntentPermissionGranted ? 'liberado' : 'bloqueado'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: (_notificationPermissionGranted && _fullScreenIntentPermissionGranted)
                            ? Colors.green[800]
                            : Colors.red[800],
                      ),
                    ),
                  ],
                ),
              ),
              if (!_fullScreenIntentPermissionGranted) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _duressSecurityService.openFullScreenIntentSettings();
                      await _loadDuressPinStatus();
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Liberar Full Screen Intent'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],

            // Card de permissão de acessibilidade (bloqueio de outros apps)
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[  
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _accessibilityServiceEnabled ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _accessibilityServiceEnabled ? Colors.green[300]! : Colors.orange[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _accessibilityServiceEnabled
                          ? '🔒 Bloqueio de outros apps: ATIVO'
                          : '⚠️ Bloqueio de outros apps: INATIVO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _accessibilityServiceEnabled ? Colors.green[900] : Colors.orange[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _accessibilityServiceEnabled
                          ? 'O serviço de acessibilidade está ativo. Nenhum outro app abrirá com desbloqueio pendente.'
                          : 'Sem o serviço de acessibilidade, outros apps podem abrir. Ative para bloqueio total.',
                      style: TextStyle(
                        fontSize: 11,
                        color: _accessibilityServiceEnabled ? Colors.green[800] : Colors.orange[800],
                      ),
                    ),
                  ],
                ),
              ),
              if (!_accessibilityServiceEnabled) ...[  
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Bloqueio total de outros apps'),
                          content: const Text(
                            'Ao ativar, o serviço "Modo Segurança" em Acessibilidade detecta '
                            'quando outro app ou Configurações entra em foco e imediatamente '
                            'retorna para a tela de PIN.\n\n'
                            'Ele NÃO lê conteúdo de tela e NÃO envia dados.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await _duressSecurityService.openAccessibilitySettings();
                                await _loadDuressPinStatus();
                              },
                              child: const Text('Abrir Acessibilidade'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.accessibility_new),
                    label: const Text('Ativar bloqueio total de outros apps'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],

            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ativar modo seguranca'),
              subtitle: Text(
                _isSafetyModeEnabled
                    ? 'Ligado: o app exige PIN ao abrir e voltar do segundo plano.'
                    : 'Desligado: o app nao exige PIN de bloqueio proprio.',
                style: const TextStyle(fontSize: 12),
              ),
              value: _isSafetyModeEnabled,
              onChanged: _toggleSafetyMode,
            ),

            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _configureUnlockPin,
                    icon: const Icon(Icons.lock),
                    label: Text(
                      _isUnlockPinConfigured
                          ? 'Atualizar PIN seguro'
                          : 'Configurar PIN seguro',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
              // Status do Device Admin (somente Android)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isDeviceAdminActive ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isDeviceAdminActive ? Colors.green[300]! : Colors.orange[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isDeviceAdminActive ? Icons.verified_user : Icons.warning_amber,
                      color: _isDeviceAdminActive ? Colors.green[700] : Colors.orange[700],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isDeviceAdminActive
                            ? 'Administrador do dispositivo: ATIVO — reset de fabrica habilitado'
                            : 'Administrador do dispositivo: INATIVO — ative para reset de fabrica',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isDeviceAdminActive ? Colors.green[800] : Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (!_isDeviceAdminActive) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _duressSecurityService.requestDeviceAdmin();
                      await _loadDuressPinStatus();
                    },
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Ativar admin do dispositivo'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
                  ),
                ),
              ],
            ] else ...[
              // iOS não possui Device Admin; mostrar limitação explicitamente.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No iOS, o sistema não oferece "Admin do dispositivo" nem permite abrir este app automaticamente ao desbloquear.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _configureDuressPin,
                    icon: const Icon(Icons.password),
                    label: Text(
                      _isDuressPinConfigured
                          ? 'Atualizar PIN de coacao'
                          : 'Configurar PIN de coacao',
                    ),
                  ),
                ),
              ],
            ),
            if (_isDuressPinConfigured) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _disableDuressPin,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Desativar PIN de coacao'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _unlockController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Digite o PIN de coacao aqui',
                  border: OutlineInputBorder(),
                  helperText: 'Ao confirmar, o app tenta reset de fabrica (Android admin) e usa reset local como fallback.',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleUnlockAttempt,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Validar e executar reset'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red[700]),
                ),
              ),
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
    Future.microtask(() async {
      await _duressSecurityService.ensureNativeSafetyFlagsSynced();
      await _ensureCriticalSafetyPermissions(interactive: false);
      await _loadDuressPinStatus();
    });
  }

  @override
  void dispose() {
    _unlockController.dispose();
    super.dispose();
  }

  Future<void> _toggleProtection() async {
    final state = context.read<ProtectionBloc>().state;

    if (state is ProtectionActive) {
      context.read<ProtectionBloc>().add(const StopProtectionEvent());
    } else {
      if (_runScanBeforeActivation) {
        final scanResult = await _runSecurityScan(silent: true);

        if (_autoBlockOnCriticalRisk && scanResult.hasCriticalRisk) {
          await _activateEmergencyBlock();
          _addLogEntry('🛑 Ativacao bloqueada automaticamente por risco critico.');
          return;
        }

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
              _alertService.clearReminder('app_disabled');
              _alertService.clearReminder('protection_failure');
            } else if (state is ProtectionInactive) {
              _addLogEntry('🔓 VPN Desconectada - ${DateTime.now().toIso8601String()}');
              _alertService.upsertReminder(
                reasonKey: 'app_disabled',
                title: 'Protecao desativada',
                body: 'A protecao foi desativada. Reative para manter sua seguranca.',
              );
            } else if (state is ProtectionError) {
              if (_isIosVpnPermissionError(state.message)) {
                _addLogEntry('⚠️ VPN indisponivel neste iPhone. Escudo parcial ativo.');
                _alertService.upsertReminder(
                  reasonKey: 'protection_partial',
                  title: 'Escudo parcial ativo',
                  body: 'Permissao de VPN indisponivel no iOS. Protecoes locais continuam ativas.',
                );
              } else {
                _addLogEntry('❌ Erro: ${state.message}');
                _alertService.upsertReminder(
                  reasonKey: 'protection_failure',
                  title: 'Falha de seguranca detectada',
                  body: state.message,
                );
              }
            }
          },
          child: CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                toolbarHeight: 124,
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

                    // Senha de coacao
                    _buildDuressPanel(),
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
                          if (_isIosVpnPermissionError(state.message)) {
                            return Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: const [
                                    Icon(
                                      Icons.shield_outlined,
                                      color: Colors.orange,
                                      size: 48,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Escudo parcial ativo neste iPhone',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'A permissao de VPN do iOS nao esta disponivel. O app continua com as demais camadas de seguranca ativas.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

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

                    // Certificado visual de sessao segura
                    BlocBuilder<ProtectionBloc, ProtectionState>(
                      builder: (context, state) {
                        final status = _statusFromState(state);
                        return _buildSessionCertificate(status);
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
