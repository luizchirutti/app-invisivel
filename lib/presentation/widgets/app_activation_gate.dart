import 'package:flutter/material.dart';

import '../../services/security/app_activation_service.dart';

class AppActivationGate extends StatefulWidget {
  final Widget child;
  final AppActivationService? activationService;

  const AppActivationGate({
    Key? key,
    required this.child,
    this.activationService,
  }) : super(key: key);

  @override
  State<AppActivationGate> createState() => _AppActivationGateState();
}

class _AppActivationGateState extends State<AppActivationGate> {
  late final AppActivationService _activationService;
  final TextEditingController _codeController = TextEditingController();

  bool _loading = true;
  bool _activated = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _activationService = widget.activationService ?? AppActivationService();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final activated = await _activationService.isActivated();
    if (!mounted) return;

    setState(() {
      _activated = activated;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _codeController.text.trim();
    if (value.isEmpty) {
      setState(() {
        _error = 'Informe o codigo de ativacao.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await _activationService.activate(value);
      if (!mounted) return;

      if (!result.isValid) {
        setState(() {
          _submitting = false;
          _error = result.error;
        });
        return;
      }

      setState(() {
        _activated = true;
        _submitting = false;
        _error = null;
      });
      _codeController.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Falha ao validar a ativacao. Revise a configuracao do app.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_activated || !_activationService.isActivationRequired) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_outlined, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Ativacao obrigatoria',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Esta instalacao precisa ser liberada antes do primeiro uso.',
                        style: TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _activationService.activationHint,
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _codeController,
                        enabled: !_submitting,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.characters,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Codigo de ativacao',
                          hintText: 'Ex.: INV-001 ou 123456',
                          border: const OutlineInputBorder(),
                          errorText: _error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: Text(_submitting ? 'Validando...' : 'Liberar app'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}