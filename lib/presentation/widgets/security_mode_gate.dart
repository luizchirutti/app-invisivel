import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/protection_bloc.dart';
import '../../services/notifications/security_alert_service.dart';
import '../../services/security/duress_security_service.dart';

class SecurityModeGate extends StatefulWidget {
  final Widget child;

  const SecurityModeGate({Key? key, required this.child}) : super(key: key);

  @override
  State<SecurityModeGate> createState() => _SecurityModeGateState();
}

class _SecurityModeGateState extends State<SecurityModeGate> with WidgetsBindingObserver {
  final DuressSecurityService _duressService = DuressSecurityService();
  final SecurityAlertService _alertService = SecurityAlertService();
  final TextEditingController _pinController = TextEditingController();

  bool _loading = true;
  bool _locked = false;
  bool _safetyModeActive = false;
  bool _submitting = false;
  String? _error;

  void _lockNow() {
    if (!mounted) return;
    setState(() {
      _locked = true;
      _error = null;
      _pinController.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrapGate();
  }

  Future<void> _bootstrapGate() async {
    await _duressService.ensureNativeSafetyFlagsSynced();
    await _refreshGateState(forceLock: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _lockNow();
        _enforceGateFromStorage(lockIfEnabled: true);
        break;
      case AppLifecycleState.resumed:
        _lockNow();
        _enforceGateFromStorage(lockIfEnabled: true);
        break;
    }
  }

  Future<void> _enforceGateFromStorage({required bool lockIfEnabled}) async {
    final modeEnabled = await _duressService.isSafetyModeEnabled();
    final unlockConfigured = await _duressService.isUnlockPinConfigured();
    final gateMustBeActive = modeEnabled && unlockConfigured;

    if (!mounted) return;
    setState(() {
      _safetyModeActive = gateMustBeActive;
      _loading = false;
      if (!gateMustBeActive) {
        _locked = false;
      } else if (lockIfEnabled) {
        _locked = true;
        _error = null;
      }
    });

    if (gateMustBeActive && lockIfEnabled) {
      _pinController.clear();
    }
  }

  Future<void> _refreshGateState({required bool forceLock}) async {
    await _enforceGateFromStorage(lockIfEnabled: forceLock);
  }

  Future<void> _submitPin() async {
    final enteredPin = _pinController.text.trim();
    if (enteredPin.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final isDuressPin = await _duressService.verifyDuressPin(enteredPin);
    if (isDuressPin) {
      await _executeDuressAction();
      return;
    }

    final isUnlockPin = await _duressService.verifyUnlockPin(enteredPin);
    if (!mounted) return;

    if (isUnlockPin) {
      setState(() {
        _locked = false;
        _submitting = false;
        _error = null;
      });
      _pinController.clear();
      return;
    }

    setState(() {
      _submitting = false;
      _error = 'PIN invalido. Tente novamente.';
    });
  }

  Future<void> _executeDuressAction() async {
    try {
      if (mounted) {
        context.read<ProtectionBloc>().add(const StopProtectionEvent());
      }
    } catch (_) {}

    await _alertService.upsertReminder(
      reasonKey: 'duress_triggered',
      title: 'Modo de coacao acionado',
      body: 'Reset de seguranca executado. Verifique a conta imediatamente.',
    );

    final factoryResetTriggered = await _duressService.performFactoryReset();
    if (factoryResetTriggered) {
      return;
    }

    await _duressService.executeLocalSecurityReset();
    if (!mounted) return;

    await _refreshGateState(forceLock: true);
    setState(() {
      _submitting = false;
      _error = 'Reset local executado. Ative admin do dispositivo para reset completo.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text(
                  'Verificando seguranca...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_safetyModeActive || !_locked) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(16),
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Modo Seguranca Ativo',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Digite seu PIN seguro para acessar o app.\nSe o PIN de coacao for digitado, o reset de seguranca sera acionado.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      enabled: !_submitting,
                      onSubmitted: (_) => _submitPin(),
                      decoration: InputDecoration(
                        labelText: 'PIN de desbloqueio',
                        border: const OutlineInputBorder(),
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitting ? null : _submitPin,
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.lock_open),
                        label: Text(_submitting ? 'Validando...' : 'Desbloquear'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
