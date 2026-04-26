import 'package:flutter/material.dart';

/// Widget de botão central de ativação (Kill Switch)
class ProtectionToggleButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onToggle;
  final bool isLoading;

  const ProtectionToggleButton({
    Key? key,
    required this.isActive,
    required this.onToggle,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<ProtectionToggleButton> createState() => _ProtectionToggleButtonState();
}

class _ProtectionToggleButtonState extends State<ProtectionToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticInOut),
    );

    if (widget.isActive) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(ProtectionToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            if (widget.isActive)
              BoxShadow(
                color: Colors.green.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 10,
              ),
            if (!widget.isActive)
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 5,
              ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: widget.isLoading ? null : widget.onToggle,
          backgroundColor: widget.isActive ? Colors.green : Colors.grey[300],
          splashColor: Colors.greenAccent,
          child: widget.isLoading
              ? SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isActive ? Colors.white : Colors.green,
                    ),
                  ),
                )
              : Icon(
                  widget.isActive ? Icons.shield_rounded : Icons.shield,
                  color: widget.isActive ? Colors.white : Colors.grey[600],
                  size: 40,
                ),
        ),
      ),
    );
  }
}

/// Card de status da proteção
class ProtectionStatusCard extends StatelessWidget {
  final bool isVPNActive;
  final bool isKillSwitchActive;
  final bool dohEnabled;
  final bool antiFingerprinting;
  final int riskLevel;
  final String threatsSummary;

  const ProtectionStatusCard({
    Key? key,
    required this.isVPNActive,
    required this.isKillSwitchActive,
    required this.dohEnabled,
    required this.antiFingerprinting,
    required this.riskLevel,
    required this.threatsSummary,
  }) : super(key: key);

  Color _getRiskColor() {
    if (riskLevel == 0) return Colors.green;
    if (riskLevel < 50) return Colors.yellow;
    if (riskLevel < 75) return Colors.orange;
    return Colors.red;
  }

  String _getRiskLabel() {
    if (riskLevel == 0) return '✅ Seguro';
    if (riskLevel < 50) return '⚠️ Aviso';
    if (riskLevel < 75) return '⚠️ Risco';
    return '🚨 Crítico';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Status de Proteção',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getRiskColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getRiskColor()),
                  ),
                  child: Text(
                    _getRiskLabel(),
                    style: TextStyle(
                      color: _getRiskColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Indicadores
            _buildIndicator('VPN', isVPNActive),
            const SizedBox(height: 8),
            _buildIndicator('Kill Switch', isKillSwitchActive),
            const SizedBox(height: 8),
            _buildIndicator('DNS Seguro (DoH)', dohEnabled),
            const SizedBox(height: 8),
            _buildIndicator('Anti-Fingerprinting', antiFingerprinting),

            if (threatsSummary.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Ameaças Detectadas:',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                threatsSummary,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(String label, bool isActive) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.green : Colors.grey[400],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.green : Colors.grey[600],
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// Widget de log de conexões
class ConnectionLogWidget extends StatelessWidget {
  final List<String> logEntries;

  const ConnectionLogWidget({
    Key? key,
    required this.logEntries,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Log de Conexões em Tempo Real',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
            ),
            child: logEntries.isEmpty
                ? const Center(
                    child: Text(
                      'Aguardando conexões...',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    itemCount: logEntries.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.grey[800],
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final entry = logEntries[logEntries.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          entry,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
