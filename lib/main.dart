import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'presentation/pages/protection_page.dart';
import 'presentation/bloc/protection_bloc.dart';
import 'domain/usecases/protection_usecases.dart';
import 'data/repositories/protection_repository_impl.dart';
import 'domain/repositories/repositories.dart';
import 'services/vpn/vpn_service.dart';
import 'services/doh/doh_service.dart';
import 'security/device_integrity/device_integrity_service.dart';
import 'security/anti_fingerprinting/anti_fingerprinter_service.dart';
import 'services/logging/secure_logging_service.dart';
import 'services/platform/unified_vpn_service.dart';
import 'presentation/widgets/security_mode_gate.dart';

final getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Inicializar serviços de segurança
    await _setupSecurityServices();
  } catch (e, s) {
    debugPrint('Falha ao inicializar segurança: $e');
    debugPrint('$s');
  }

  try {
    // Setup de injeção de dependências
    _setupDependencies();
  } catch (e, s) {
    debugPrint('Falha ao configurar dependências: $e');
    debugPrint('$s');
  }

  runApp(const AppInvisivel());
}

/// Inicializa serviços de segurança
Future<void> _setupSecurityServices() async {
  // Em Web, parte da stack de segurança usa APIs nativas não disponíveis.
  if (kIsWeb) {
    debugPrint('Web detectado: pulando inicialização nativa de segurança.');
    return;
  }

  // Logging
  final logger = SecureLoggingService();
  await logger.initialize();
  await logger.info('Aplicação iniciada', 'Main');

  // Device Integrity
  final integrityService = DeviceIntegrityService();
  final integrityResult = await integrityService.checkDeviceIntegrity();

  if (!integrityResult.isSecure) {
    await logger.warning(
      'Ameaças de integridade detectadas: ${integrityResult.threatsSummary}',
      'SecurityCheck',
    );
  }

  // Iniciar monitoramento contínuo
  integrityService.startContinuousMonitoring(
    interval: const Duration(minutes: 5),
    onThreatDetected: (result) async {
      await logger.critical(
        'Ameaça detectada: ${result.threatsSummary}',
        'ThreatDetection',
      );
    },
  );
}

/// Setup de injeção de dependências
void _setupDependencies() {
  // Serviços
  if (!getIt.isRegistered<VPNService>()) {
    getIt.registerSingleton<VPNService>(VPNService());
  }
  if (!getIt.isRegistered<UnifiedVPNService>()) {
    getIt.registerSingleton<UnifiedVPNService>(UnifiedVPNService());
  }
  if (!getIt.isRegistered<DoHService>()) {
    getIt.registerSingleton<DoHService>(DoHService());
  }
  if (!getIt.isRegistered<DeviceIntegrityService>()) {
    getIt.registerSingleton<DeviceIntegrityService>(DeviceIntegrityService());
  }
  if (!getIt.isRegistered<AntiFingerprinterService>()) {
    getIt.registerSingleton<AntiFingerprinterService>(AntiFingerprinterService());
  }
  if (!getIt.isRegistered<SecureLoggingService>()) {
    getIt.registerSingleton<SecureLoggingService>(SecureLoggingService());
  }

  // Repositórios
  if (!getIt.isRegistered<ProtectionRepository>()) {
    getIt.registerSingleton<ProtectionRepository>(
      ProtectionRepositoryImpl(
        vpnService: getIt<UnifiedVPNService>(),
        dohService: getIt<DoHService>(),
        integrityService: getIt<DeviceIntegrityService>(),
        antiFingerprinterService: getIt<AntiFingerprinterService>(),
      ),
    );
  }

  // Use cases
  if (!getIt.isRegistered<StartProtectionUseCase>()) {
    getIt.registerSingleton<StartProtectionUseCase>(
      StartProtectionUseCase(getIt<ProtectionRepository>()),
    );
  }
  if (!getIt.isRegistered<StopProtectionUseCase>()) {
    getIt.registerSingleton<StopProtectionUseCase>(
      StopProtectionUseCase(getIt<ProtectionRepository>()),
    );
  }
  if (!getIt.isRegistered<GetProtectionStatusUseCase>()) {
    getIt.registerSingleton<GetProtectionStatusUseCase>(
      GetProtectionStatusUseCase(getIt<ProtectionRepository>()),
    );
  }

  // BLoCs
  if (!getIt.isRegistered<ProtectionBloc>()) {
    getIt.registerSingleton<ProtectionBloc>(
      ProtectionBloc(
        startProtectionUseCase: getIt<StartProtectionUseCase>(),
        stopProtectionUseCase: getIt<StopProtectionUseCase>(),
        getProtectionStatusUseCase: getIt<GetProtectionStatusUseCase>(),
      ),
    );
  }
}

class AppInvisivel extends StatelessWidget {
  const AppInvisivel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Invisível',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: BlocProvider(
        create: (context) => getIt<ProtectionBloc>(),
        child: const SecurityModeGate(
          child: ProtectionPage(),
        ),
      ),
    );
  }
}
