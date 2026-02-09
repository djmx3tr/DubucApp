import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    // Rafraîchir toutes les 30 secondes quand l'écran est ouvert
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadAlerts());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<String> _getAlertServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('alert_server_url') ?? 'http://192.168.0.24:5001';
  }

  Future<void> _loadAlerts() async {
    try {
      final url = await _getAlertServerUrl();
      final response = await http.get(
        Uri.parse('$url/api/alerts'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final alerts = (data['alerts'] as List<dynamic>? ?? [])
            .map((a) => Map<String, dynamic>.from(a))
            .toList();

        if (mounted) {
          setState(() {
            _alerts = alerts;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _acknowledgeAll() async {
    try {
      final url = await _getAlertServerUrl();
      await http.post(
        Uri.parse('$url/api/alerts/acknowledge'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ids': []}),
      ).timeout(const Duration(seconds: 5));
      
      _loadAlerts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les alertes marquées comme lues'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _acknowledgeOne(int alertId) async {
    try {
      final url = await _getAlertServerUrl();
      await http.post(
        Uri.parse('$url/api/alerts/acknowledge'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ids': [alertId]}),
      ).timeout(const Duration(seconds: 5));
      
      _loadAlerts();
    } catch (e) {
      // Silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes'),
        actions: [
          if (_alerts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _acknowledgeAll,
              tooltip: 'Tout marquer comme lu',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune alerte',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tout fonctionne normalement',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAlerts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _alerts.length,
                    itemBuilder: (context, index) {
                      final alert = _alerts[index];
                      return _AlertCard(
                        alert: alert,
                        onDismiss: () => _acknowledgeOne(alert['id'] ?? 0),
                      );
                    },
                  ),
                ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onDismiss;

  const _AlertCard({
    required this.alert,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final machine = alert['machine_id'] ?? 'Inconnu';
    final message = alert['message'] ?? '';
    final timestamp = alert['timestamp'] ?? '';
    final count = alert['consecutive_count'] ?? 0;

    return Dismissible(
      key: Key('alert_${alert['id']}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: Colors.red.shade50,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 28,
              ),
            ),
          ),
          title: Text(
            'Code-barres manquant',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red.shade800,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '$message ($count feuilles)',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                'Machine: $machine',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              Text(
                timestamp,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.check_circle_outline),
            color: Colors.green,
            onPressed: onDismiss,
            tooltip: 'Marquer comme lu',
          ),
        ),
      ),
    );
  }
}
