import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler';

/// Service de gestion des notifications locales
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  factory NotificationService() => _instance;

  NotificationService._internal();

  /// Initialise le service de notifications
  Future<void> initialize() async {
    // Configuration Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Demande la permission pour les notifications (Android 13+)
    await _requestPermission();
  }

  /// Demande la permission pour les notifications
  Future<void> _requestPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  /// Callback quand l'utilisateur tape sur une notification
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tappée: ${response.payload}');
    // Vous pouvez ajouter une navigation ici si nécessaire
  }

  /// Affiche une notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'notification_channel',
      'Notifications Dubuc',
      channelDescription: 'Notifications système et alertes de production',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: '$id',
    );
  }

  /// Affiche une notification avec ID automatique
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    await showNotification(id: id, title: title, body: body);
  }

  /// Annule toutes les notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
