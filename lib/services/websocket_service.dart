import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../models/notification_model.dart';

/// Service de gestion de la connexion WebSocket
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  
  WebSocketChannel? _channel;
  final _messageController = StreamController<NotificationModel>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  
  bool _isConnected = false;
  bool _shouldReconnect = true; // Contrôle les reconnexions automatiques
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  
  // Configuration du serveur
  String serverHost = '192.168.0.24';
  int serverPort = 8082;
  
  factory WebSocketService({
    String host = '192.168.0.24',
    int port = 8082,
  }) {
    _instance.serverHost = host;
    _instance.serverPort = port;
    return _instance;
  }

  WebSocketService._internal();

  /// Stream des messages reçus
  Stream<NotificationModel> get messageStream => _messageController.stream;

  /// Stream de l'état de connexion
  Stream<bool> get connectionStream => _connectionController.stream;

  /// État de connexion actuel
  bool get isConnected => _isConnected;

  /// URL du serveur WebSocket
  String get serverUrl => 'ws://$serverHost:$serverPort';

  /// Se connecte au serveur WebSocket
  Future<void> connect() async {
    if (_isConnected) {
      print('Déjà connecté au serveur WebSocket');
      return;
    }

    _shouldReconnect = true; // Activer les reconnexions automatiques

    try {
      print('Connexion au serveur WebSocket: $serverUrl');
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));

      // Écoute les messages du serveur
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDisconnected,
        cancelOnError: false,
      );

      _isConnected = true;
      _connectionController.add(true);
      print('Connecté au serveur WebSocket');

      // Démarre le ping pour maintenir la connexion active
      _startPing();

    } catch (e) {
      print('Erreur de connexion WebSocket: $e');
      _isConnected = false;
      _connectionController.add(false);
      _scheduleReconnect();
    }
  }

  /// Traite un message reçu du serveur
  void _onMessage(dynamic message) {
    try {
      print('Message reçu: $message');
      final data = jsonDecode(message as String) as Map<String, dynamic>;

      // Ignore les messages système (pong, welcome, etc.)
      final type = data['type'] as String?;
      if (type == 'pong' || type == 'system') {
        return;
      }

      // Crée un modèle de notification
      final notification = NotificationModel.fromJson(data);
      _messageController.add(notification);

    } catch (e) {
      print('Erreur de traitement du message: $e');
    }
  }

  /// Gère les erreurs de connexion
  void _onError(Object error) {
    print('Erreur WebSocket: $error');
    _isConnected = false;
    _connectionController.add(false);
  }

  /// Gère la déconnexion
  void _onDisconnected() {
    print('Déconnecté du serveur WebSocket');
    _isConnected = false;
    _connectionController.add(false);
    _stopPing();
    _scheduleReconnect();
  }

  /// Programme une tentative de reconnexion
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (!_shouldReconnect) {
      print('Reconnexion désactivée - app en background');
      return;
    }
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && _shouldReconnect) {
        print('Tentative de reconnexion...');
        connect();
      }
    });
  }

  /// Démarre le ping périodique
  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        _sendPing();
      }
    });
  }

  /// Arrête le ping périodique
  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Envoie un ping au serveur
  void _sendPing() {
    try {
      final ping = jsonEncode({'type': 'ping'});
      _channel?.sink.add(ping);
    } catch (e) {
      print('Erreur lors de l\'envoi du ping: $e');
    }
  }

  /// Envoie un message au serveur
  void sendMessage(String message) {
    if (!_isConnected) {
      print('Impossible d\'envoyer le message: non connecté');
      return;
    }

    try {
      _channel?.sink.add(message);
    } catch (e) {
      print('Erreur lors de l\'envoi du message: $e');
    }
  }

  /// Se déconnecte du serveur
  Future<void> disconnect() async {
    print('Déconnexion du serveur WebSocket');
    _shouldReconnect = false; // Désactiver les reconnexions automatiques
    _reconnectTimer?.cancel();
    _stopPing();
    
    await _channel?.sink.close(status.goingAway);
    _channel = null;
    
    _isConnected = false;
    _connectionController.add(false);
  }

  /// Nettoie les ressources
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
