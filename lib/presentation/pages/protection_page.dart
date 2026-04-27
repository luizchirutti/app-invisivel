import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/protection_bloc.dart';
import '../widgets/protection_widgets.dart';
import '../../domain/entities/entities.dart';

/// Página principal de proteção
class ProtectionPage extends StatefulWidget {
  const ProtectionPage({Key? key}) : super(key: key);

  @override
  State<ProtectionPage> createState() => _ProtectionPageState();
}

class _ProtectionPageState extends State<ProtectionPage> {
  final List<String> _logEntries = [];

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

  void _toggleProtection() {
    final state = context.read<ProtectionBloc>().state;

    if (state is ProtectionActive) {
      context.read<ProtectionBloc>().add(const StopProtectionEvent());
    } else {
      final defaultConfig = AppConfiguration();
      context.read<ProtectionBloc>().add(StartProtectionEvent(defaultConfig));
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
