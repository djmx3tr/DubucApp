import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service d'alertes - polling actif quand l'app est ouverte
class AlertService extends ChangeNotifier {
  static const int _pollIntervalSeconds = 5;
  static const String _alertUrlKey = 'alert_server_url';
  static const String _defaultAlertUrl = 'http://192.168.0.24:5001';

  Timer? _timer;
  List<Map<String, dynamic>> _alerts = [];
  int _unreadCount = 0;
  bool _isEnabled = true;
  String _alertServerUrl = _defaultAlertUrl;

  List<Map<String, dynamic>> get alerts => _alerts;
  int get unreadCount => _unreadCount;
  bool get isEnabled => _isEnabled;
  String get alertServerUrl => _alertServerUrl;

  AlertService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _alertServerUrl = prefs.getString(_alertUrlKey) ?? _defaultAlertUrl;
    _isEnabled = prefs.getBool('alerts_enabled') ?? true;
    if (_isEnabled) {
      startPolling();
    }
    notifyListeners();
  }

  Future<void> setAlertServerUrl(String url) async {
    _alertServerUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alertUrlKey, url);
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alerts_enabled', enabled);
    if (enabled) {
      startPolling();
    } else {
      stopPolling();
    }
    notifyListeners();
  }

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: _pollIntervalSeconds),
      (_) => fetchAlerts(),
    );
    // Première vérification immédiate
    fetchAlerts();
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> fetchAlerts() async {
    if (!_isEnabled) return;

    try {
      final response = await http
          .get(Uri.parse('$_alertServerUrl/api/alerts'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _alerts = (data['alerts'] as List<dynamic>? ?? [])
            .map((a) => Map<String, dynamic>.from(a))
            .toList();
        _unreadCount = _alerts.length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erreur polling alertes: $e');
    }
  }

  Future<void> acknowledgeAll() async {
    try {
      await http.post(
        Uri.parse('$_alertServerUrl/api/alerts/acknowledge'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ids': []}),
      ).timeout(const Duration(seconds: 5));
      await fetchAlerts();
    } catch (e) {
      debugPrint('Erreur acquittement: $e');
    }
  }

  Future<void> acknowledgeOne(int alertId) async {
    try {
      await http.post(
        Uri.parse('$_alertServerUrl/api/alerts/acknowledge'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ids': [alertId]}),
      ).timeout(const Duration(seconds: 5));
      await fetchAlerts();
    } catch (e) {
      debugPrint('Erreur acquittement: $e');
    }
  }

  Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$_alertServerUrl/api/alerts/count'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
