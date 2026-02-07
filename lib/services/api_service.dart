import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job.dart';

class ApiService extends ChangeNotifier {
  static const String _serverUrlKey = 'server_url';
  static const String _defaultServerUrl = 'http://192.168.0.24:5000';
  
  String _serverUrl = _defaultServerUrl;
  bool _isLoading = false;
  String? _error;

  String get serverUrl => _serverUrl;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ApiService() {
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_serverUrlKey) ?? _defaultServerUrl;
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Récupère les détails d'un job par son ID (6 chiffres)
  Future<Job?> getJob(int jobId) async {
    _setLoading(true);
    _setError(null);
    
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/job/$jobId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Job.fromJson(data);
      } else if (response.statusCode == 404) {
        _setError('Job #$jobId introuvable');
        return null;
      } else {
        _setError('Erreur serveur: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Trouve un job par ID de palette (format XXX-...)
  Future<Job?> findJobByPalette(String paletteId) async {
    _setLoading(true);
    _setError(null);
    
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/palette/$paletteId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Job.fromJson(data);
      } else if (response.statusCode == 404) {
        _setError('Palette "$paletteId" introuvable');
        return null;
      } else {
        _setError('Erreur serveur: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Récupère la liste des jobs actuellement en cours
  Future<List<CurrentJob>> getCurrentJobs() async {
    _setLoading(true);
    _setError(null);
    
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/jobs/current'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final jobsJson = data['jobs'] as List<dynamic>? ?? [];
        return jobsJson.map((j) => CurrentJob.fromJson(j)).toList();
      } else {
        _setError('Erreur serveur: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Met à jour la quantité d'une palette
  Future<bool> updateQuantity(int jobId, String paletteId, int quantity) async {
    _setLoading(true);
    _setError(null);
    
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/api/quantity'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'job_id': jobId,
          'palette_id': paletteId,
          'quantity': quantity,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      } else {
        final data = json.decode(response.body);
        _setError(data['detail'] ?? 'Erreur de mise à jour');
        return false;
      }
    } catch (e) {
      _setError('Erreur de connexion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Test de connexion au serveur
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/jobs/current'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
