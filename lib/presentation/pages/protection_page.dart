import 'package:flutter/material.dart';
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
