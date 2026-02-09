import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes'),
        actions: [
          Consumer<AlertService>(
            builder: (context, alertService, _) {
              if (alertService.alerts.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.done_all),
                onPressed: () => alertService.acknowledgeAll(),
                tooltip: 'Tout marquer comme lu',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AlertService>().fetchAlerts(),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Consumer<AlertService>(
        builder: (context, alertService, _) {
          if (alertService.alerts.isEmpty) {
            return Center(
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
                    alertService.isEnabled
                        ? 'Surveillance active (toutes les 5s)'
                        : 'Surveillance désactivée',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => alertService.fetchAlerts(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: alertService.alerts.length,
              itemBuilder: (context, index) {
                final alert = alertService.alerts[index];
                return _AlertCard(
                  alert: alert,
                  onDismiss: () =>
                      alertService.acknowledgeOne(alert['id'] ?? 0),
                );
              },
            ),
          );
        },
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                style:
                    TextStyle(color: Theme.of(context).colorScheme.outline),
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
