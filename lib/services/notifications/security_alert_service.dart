import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class _AlertPayload {
  final String title;
  final String body;

  const _AlertPayload({
    required this.title,
    required this.body,
  });
}

/// Serviço central para alertas de segurança com lembrete recorrente.
class SecurityAlertService {
  SecurityAlertService._internal();

  static final SecurityAlertService _instance = SecurityAlertService._internal();

  factory SecurityAlertService() => _instance;

  static const Duration _reminderInterval = Duration(minutes: 10);
  static const int _notificationId = 9001;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Map<String, _AlertPayload> _activeReminders = {};

  Timer? _reminderTimer;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notifications.initialize(initSettings);

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> upsertReminder({
    required String reasonKey,
    required String title,
    required String body,
    bool sendImmediately = true,
  }) async {
    await initialize();

    _activeReminders[reasonKey] = _AlertPayload(title: title, body: body);

    if (sendImmediately) {
      await _showNotification(title: title, body: body);
    }

    _ensureReminderLoop();
  }

  void clearReminder(String reasonKey) {
    _activeReminders.remove(reasonKey);

    if (_activeReminders.isEmpty) {
      _reminderTimer?.cancel();
      _reminderTimer = null;
      _notifications.cancel(_notificationId);
    }
  }

  Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'security_alerts',
      'Alertas de seguranca',
      channelDescription: 'Alertas de riscos e falhas de protecao',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(_notificationId, title, body, details);
  }

  void _ensureReminderLoop() {
    _reminderTimer ??= Timer.periodic(_reminderInterval, (_) async {
      if (_activeReminders.isEmpty) {
        _reminderTimer?.cancel();
        _reminderTimer = null;
        return;
      }

      final alerts = _activeReminders.values.toList(growable: false);
      final reminderTitle = alerts.length == 1
          ? alerts.first.title
          : 'Alerta de seguranca ativo';
      final reminderBody = alerts.length == 1
          ? '${alerts.first.body} (Lembrete de 10 min)'
          : 'Existem ${alerts.length} alertas ativos. Verifique o app agora.';

      try {
        await _showNotification(title: reminderTitle, body: reminderBody);
      } catch (e) {
        debugPrint('Falha ao enviar lembrete de seguranca: $e');
      }
    });
  }
}