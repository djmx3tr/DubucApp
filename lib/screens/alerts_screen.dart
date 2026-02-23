import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/unified_notification_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes & Notifications'),
        actions: [
          Consumer<UnifiedNotificationService>(
            builder: (context, unifiedService, _) {
              if (unifiedService.allNotifications.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.done_all),
                onPressed: () => unifiedService.markAllAsRead(),
                tooltip: 'Tout marquer comme lu',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<UnifiedNotificationService>().refresh(),
            tooltip: 'Actualiser',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Détection', icon: Icon(Icons.warning_amber)),
            Tab(text: 'Système', icon: Icon(Icons.notifications)),
            Tab(text: 'Tout', icon: Icon(Icons.list)),
          ],
        ),
      ),
      body: Consumer<UnifiedNotificationService>(
        builder: (context, unifiedService, _) {
          if (unifiedService.allNotifications.isEmpty) {
            return _buildEmptyState(context, unifiedService);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildDetectionAlerts(unifiedService),
              _buildSystemNotifications(unifiedService),
              _buildAllNotifications(unifiedService),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, UnifiedNotificationService unifiedService) {
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
            'WebSocket: ${unifiedService.isWebSocketConnected ? "Connecté" : "Déconnecté"}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          if (!unifiedService.isWebSocketConnected)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton(
                onPressed: () => unifiedService.reconnectWebSocket(),
                child: const Text('Reconnecter'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetectionAlerts(UnifiedNotificationService unifiedService) {
    final detectionNotifications = unifiedService.allNotifications
        .where((n) => n.alertType == 'detection')
        .toList();

    if (detectionNotifications.isEmpty) {
      return const Center(child: Text('Aucune alerte de détection'));
    }

    return RefreshIndicator(
      onRefresh: () => unifiedService.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: detectionNotifications.length,
        itemBuilder: (context, index) {
          final notification = detectionNotifications[index];
          return _UnifiedNotificationCard(
            notification: notification,
            onDismiss: () => unifiedService.markAsRead(notification.id!),
            onDelete: () => unifiedService.deleteNotification(notification.id!),
          );
        },
      ),
    );
  }

  Widget _buildSystemNotifications(UnifiedNotificationService unifiedService) {
    final systemNotifications = unifiedService.allNotifications
        .where((n) => n.alertType != 'detection')
        .toList();

    if (systemNotifications.isEmpty) {
      return const Center(child: Text('Aucune notification système'));
    }

    return RefreshIndicator(
      onRefresh: () => unifiedService.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: systemNotifications.length,
        itemBuilder: (context, index) {
          final notification = systemNotifications[index];
          return _UnifiedNotificationCard(
            notification: notification,
            onDismiss: () => unifiedService.markAsRead(notification.id!),
            onDelete: () => unifiedService.deleteNotification(notification.id!),
          );
        },
      ),
    );
  }

  Widget _buildAllNotifications(UnifiedNotificationService unifiedService) {
    return RefreshIndicator(
      onRefresh: () => unifiedService.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: unifiedService.allNotifications.length,
        itemBuilder: (context, index) {
          final notification = unifiedService.allNotifications[index];
          return _UnifiedNotificationCard(
            notification: notification,
            onDismiss: () => unifiedService.markAsRead(notification.id!),
            onDelete: () => unifiedService.deleteNotification(notification.id!),
          );
        },
      ),
    );
  }
}

class _UnifiedNotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onDismiss;
  final VoidCallback onDelete;

  const _UnifiedNotificationCard({
    required this.notification,
    required this.onDismiss,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDetection = notification.alertType == 'detection';
    final isRead = notification.isRead;
    
    Color cardColor = isRead ? Colors.grey.shade50 : Colors.white;
    Color iconColor = isDetection ? Colors.red.shade700 : Colors.blue.shade700;
    IconData iconData = isDetection ? Icons.warning_amber_rounded : Icons.info_outline;

    return Dismissible(
      key: Key('notification_${notification.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: cardColor,
        elevation: isRead ? 1 : 3,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                iconData,
                color: iconColor,
                size: 28,
              ),
            ),
          ),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              color: isRead ? Colors.grey.shade700 : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.body,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isRead ? Colors.grey.shade600 : null,
                ),
              ),
              if (notification.machineId != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Machine: ${notification.machineId}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                _formatTimestamp(notification.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
          trailing: isRead 
            ? null 
            : IconButton(
                icon: const Icon(Icons.check_circle_outline),
                color: Colors.green,
                onPressed: onDismiss,
                tooltip: 'Marquer comme lu',
              ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'À l\'instant';
    } else if (diff.inHours < 1) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inDays < 1) {
      return 'Il y a ${diff.inHours}h';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
