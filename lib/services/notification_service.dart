import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Constantes
const int _pollIntervalSeconds = 30;
const String _notificationChannelId = 'dubuc_alerts';
const String _foregroundChannelId = 'dubuc_foreground';

// Instance globale des notifications
final FlutterLocalNotificationsPlugin _notificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Initialise tout le système de notifications + service background
Future<void> initNotificationService() async {
  // 1. Notifications locales
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await _notificationsPlugin.initialize(initSettings);

  // 2. Service en arrière-plan
  final service = FlutterBackgroundService();

  await service.configure(
    iosConfiguration: IosConfiguration(),
    androidConfiguration: AndroidConfiguration(
      onStart: _onServiceStart,
      autoStart: true,
      isForegroundMode: true,
      autoStartOnBoot: true,
      notificationChannelId: _foregroundChannelId,
      initialNotificationTitle: 'Dubuc & CO',
      initialNotificationContent: 'Surveillance des alertes active',
      foregroundServiceNotificationId: 888,
    ),
  );

  await service.startService();
}

/// Point d'entrée du service background
@pragma('vm:entry-point')
Future<void> _onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialiser les notifications dans le service
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await _notificationsPlugin.initialize(initSettings);

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  // Boucle de vérification toutes les 30 secondes
  Timer.periodic(const Duration(seconds: _pollIntervalSeconds), (_) async {
    await _checkForAlerts(service);
  });

  // Première vérification immédiate
  await _checkForAlerts(service);
}

/// Vérifie les alertes depuis le serveur
Future<void> _checkForAlerts(ServiceInstance service) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('alerts_enabled') ?? true;
    if (!enabled) return;

    final alertServerUrl =
        prefs.getString('alert_server_url') ?? 'http://192.168.0.24:5001';
    final lastAlertId = prefs.getInt('last_alert_id') ?? 0;

    final response = await http
        .get(Uri.parse('$alertServerUrl/api/alerts'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final alerts = data['alerts'] as List<dynamic>? ?? [];
      int maxId = lastAlertId;

      for (final alert in alerts) {
        final alertId = alert['id'] as int? ?? 0;
        if (alertId > lastAlertId) {
          final machine = alert['machine_id'] ?? 'Inconnu';
          final message = alert['message'] ?? 'Alerte détection';
          final count = alert['consecutive_count'] ?? 0;

          // Notification push
          await _showAlertNotification(
            'Code-barres manquant [$machine]',
            '$message ($count feuilles consécutives)',
            alertId,
          );

          if (alertId > maxId) maxId = alertId;
        }
      }

      if (maxId > lastAlertId) {
        await prefs.setInt('last_alert_id', maxId);
      }

      // Mettre à jour la notification du foreground service
      if (service is AndroidServiceInstance) {
        final unreadCount = alerts.length;
        service.setForegroundNotificationInfo(
          title: 'Dubuc & CO',
          content: unreadCount > 0
              ? '$unreadCount alerte(s) non lue(s)'
              : 'Surveillance active - Aucune alerte',
        );
      }
    }
  } catch (e) {
    debugPrint('Erreur vérification alertes: $e');
  }
}

/// Affiche une notification d'alerte
Future<void> _showAlertNotification(String title, String body, int id) async {
  const androidDetails = AndroidNotificationDetails(
    _notificationChannelId,
    'Alertes Dubuc',
    channelDescription: 'Alertes de détection code-barres manquant',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
  );
  const details = NotificationDetails(android: androidDetails);
  await _notificationsPlugin.show(id, title, body, details);
}

/// Arrête le service
Future<void> stopAlertService() async {
  final service = FlutterBackgroundService();
  service.invoke('stopService');
}

/// Démarre le service
Future<void> startAlertService() async {
  final service = FlutterBackgroundService();
  await service.startService();
}
