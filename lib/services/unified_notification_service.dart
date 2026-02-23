import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/database_service.dart';
import '../services/websocket_service.dart';
import 'local_notification_service.dart';

/// Service unifié qui gère les alertes détection ET les notifications push
class UnifiedNotificationService extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final WebSocketService _wsService = WebSocketService();
  final NotificationService _localNotifService = NotificationService();
  
  List<NotificationModel> _allNotifications = [];
  List<Map<String, dynamic>> _detectionAlerts = [];
  bool _isWebSocketConnected = false;
  int _unreadCount = 0;
  
  // Stream subscriptions
  StreamSubscription<NotificationModel>? _wsSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  // Getters
  List<NotificationModel> get allNotifications => _allNotifications;
  List<Map<String, dynamic>> get detectionAlerts => _detectionAlerts;
  bool get isWebSocketConnected => _isWebSocketConnected;
  int get unreadCount => _unreadCount;

  UnifiedNotificationService() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialiser les notifications locales
    await _localNotifService.initialize();
    
    // Charger les notifications existantes
    await _loadNotifications();
    
    // Configurer WebSocket
    _setupWebSocket();
    
    // Compter les non lues
    await _updateUnreadCount();
  }

  void _setupWebSocket() {
    // Écouter les messages WebSocket
    _wsSubscription = _wsService.messageStream.listen((notification) {
      _handleWebSocketNotification(notification);
    });

    // Écouter l'état de connexion
    _connectionSubscription = _wsService.connectionStream.listen((connected) {
      _isWebSocketConnected = connected;
      notifyListeners();
    });

    // Se connecter automatiquement
    _wsService.connect();
  }

  void _handleWebSocketNotification(NotificationModel notification) {
    // Ajouter à la base de données
    _dbService.insertNotification(notification);
    
    // Ajouter à la liste
    _allNotifications.insert(0, notification);
    
    // Envoyer notification locale
    _localNotifService.showAutoNotification(
      title: notification.title,
      body: notification.body,
    );
    
    // Mettre à jour le compteur
    _updateUnreadCount();
    
    notifyListeners();
    
    debugPrint('Notification WebSocket reçue: ${notification.title}');
  }

  Future<void> addDetectionAlert(Map<String, dynamic> alert) async {
    // Convertir l'alerte de détection en NotificationModel
    final notification = NotificationModel(
      title: 'Code-barres manquant',
      body: '${alert['message'] ?? ''} (${alert['consecutive_count'] ?? 0} feuilles)',
      timestamp: DateTime.parse(alert['timestamp'] ?? DateTime.now().toIso8601String()),
      machineId: alert['machine_id']?.toString(),
      alertType: 'detection',
      severity: 'warning',
    );

    // Ajouter à la base de données
    await _dbService.insertNotification(notification);
    
    // Ajouter aux listes
    _allNotifications.insert(0, notification);
    _detectionAlerts.insert(0, alert);
    
    // Envoyer notification locale
    await _localNotifService.showAutoNotification(
      title: notification.title,
      body: notification.body,
    );

    await _updateUnreadCount();
    notifyListeners();
    
    debugPrint('Alerte détection ajoutée: ${notification.machineId}');
  }

  Future<void> _loadNotifications() async {
    _allNotifications = await _dbService.getAllNotifications();
    notifyListeners();
  }

  Future<void> _updateUnreadCount() async {
    _unreadCount = await _dbService.getUnreadCount();
    notifyListeners();
  }

  Future<void> markAsRead(int notificationId) async {
    await _dbService.markAsRead(notificationId);
    
    // Mettre à jour la liste locale
    final index = _allNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _allNotifications[index] = _allNotifications[index].copyWith(isRead: true);
    }
    
    await _updateUnreadCount();
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    await _dbService.markAllAsRead();
    
    // Mettre à jour la liste locale
    _allNotifications = _allNotifications.map((n) => n.copyWith(isRead: true)).toList();
    
    await _updateUnreadCount();
    notifyListeners();
  }

  Future<void> deleteNotification(int notificationId) async {
    await _dbService.deleteNotification(notificationId);
    
    _allNotifications.removeWhere((n) => n.id == notificationId);
    await _updateUnreadCount();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _dbService.deleteAllNotifications();
    _allNotifications.clear();
    _detectionAlerts.clear();
    await _updateUnreadCount();
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadNotifications();
    await _updateUnreadCount();
    notifyListeners();
  }

  void reconnectWebSocket() {
    _wsService.connect();
  }

  void disconnectWebSocket() {
    _wsService.disconnect();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _connectionSubscription?.cancel();
    _wsService.dispose();
    super.dispose();
  }
}
