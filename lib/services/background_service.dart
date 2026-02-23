import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/notification_model.dart';
import 'database_service.dart';
import 'local_notification_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceNotificationId: 999,
      initialNotificationTitle: 'Dubuc & CO',
      initialNotificationContent: 'Connexion au serveur...',
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final notifService = NotificationService();
  await notifService.initialize();
  final dbService = DatabaseService();

  WebSocketChannel? channel;
  Timer? pingTimer;
  Timer? reconnectTimer;
  bool isConnected = false;

  const serverUrl = 'ws://192.168.0.24:8082';

  void updateNotification(String content) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Dubuc & CO',
        content: content,
      );
    }
  }

  void disconnect() {
    pingTimer?.cancel();
    pingTimer = null;
    try {
      channel?.sink.close();
    } catch (_) {}
    channel = null;
    isConnected = false;
  }

  Future<void> connect() async {
    if (isConnected) return;

    try {
      channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      isConnected = true;
      updateNotification('Connecté au serveur');
      service.invoke('connectionStatus', {'connected': true});

      pingTimer?.cancel();
      pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        try {
          channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      });

      channel!.stream.listen(
        (message) async {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            final type = data['type'] as String?;

            if (type == 'pong' || type == 'system') return;

            final notification = NotificationModel.fromJson(data);
            final id = await dbService.insertNotification(notification);

            await notifService.showNotification(
              id: id,
              title: notification.title,
              body: notification.body,
            );

            service.invoke('newNotification', {
              'title': notification.title,
              'body': notification.body,
              'machineId': notification.machineId,
              'alertType': notification.alertType,
              'severity': notification.severity,
            });
          } catch (e) {
            // ignore parse errors
          }
        },
        onError: (_) {
          disconnect();
          updateNotification('Déconnecté — reconnexion...');
          service.invoke('connectionStatus', {'connected': false});
        },
        onDone: () {
          disconnect();
          updateNotification('Déconnecté — reconnexion...');
          service.invoke('connectionStatus', {'connected': false});
        },
        cancelOnError: false,
      );
    } catch (e) {
      isConnected = false;
      updateNotification('Erreur — reconnexion...');
      service.invoke('connectionStatus', {'connected': false});
    }
  }

  reconnectTimer = Timer.periodic(const Duration(seconds: 5), (_) {
    if (!isConnected) {
      connect();
    }
  });

  await connect();

  service.on('getStatus').listen((_) {
    service.invoke('connectionStatus', {'connected': isConnected});
  });

  service.on('stop').listen((_) {
    disconnect();
    reconnectTimer?.cancel();
    service.stopSelf();
  });
}
