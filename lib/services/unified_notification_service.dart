import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../models/notification_model.dart';
import 'database_service.dart';

/// Service unifié qui écoute le background service pour les alertes
class UnifiedNotificationService extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final FlutterBackgroundService _bgService = FlutterBackgroundService();

  List<NotificationModel> _allNotifications = [];
  bool _isWebSocketConnected = false;
  int _unreadCount = 0;

  List<NotificationModel> get allNotifications => _allNotifications;
  bool get isWebSocketConnected => _isWebSocketConnected;
  int get unreadCount => _unreadCount;

  UnifiedNotificationService() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _loadNotifications();
    _listenToBackgroundService();
    await _updateUnreadCount();
  }

  void _listenToBackgroundService() {
    _bgService.on('connectionStatus').listen((event) {
      if (event != null) {
        _isWebSocketConnected = event['connected'] as bool? ?? false;
        notifyListeners();
      }
    });

    _bgService.on('newNotification').listen((event) {
      if (event != null) {
        _loadNotifications();
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      _bgService.invoke('getStatus');
    });
  }

  Future<void> _loadNotifications() async {
    _allNotifications = await _dbService.getAllNotifications();
    await _updateUnreadCount();
    notifyListeners();
  }

  Future<void> _updateUnreadCount() async {
    _unreadCount = await _dbService.getUnreadCount();
    notifyListeners();
  }

  Future<void> markAsRead(int notificationId) async {
    await _dbService.markAsRead(notificationId);
    final index = _allNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _allNotifications[index] = _allNotifications[index].copyWith(isRead: true);
    }
    await _updateUnreadCount();
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    await _dbService.markAllAsRead();
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
    await _updateUnreadCount();
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadNotifications();
  }

  void reconnectWebSocket() {
    _bgService.invoke('getStatus');
  }

  void disconnectWebSocket() {
    // Ne rien faire — le background service gère la connexion
  }
}
