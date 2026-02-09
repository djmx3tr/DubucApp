import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _alertUrlController = TextEditingController();
  bool _isTesting = false;
  bool? _connectionStatus;
  bool _isTestingAlert = false;
  bool? _alertConnectionStatus;
  bool _alertsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final api = context.read<ApiService>();
    _urlController.text = api.serverUrl;

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _alertUrlController.text =
          prefs.getString('alert_server_url') ?? 'http://192.168.0.24:5001';
      _alertsEnabled = prefs.getBool('alerts_enabled') ?? true;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _connectionStatus = null;
    });

    final api = context.read<ApiService>();
    final result = await api.testConnection();

    if (mounted) {
      setState(() {
        _isTesting = false;
        _connectionStatus = result;
      });
    }
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final api = context.read<ApiService>();
    await api.setServerUrl(url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL du serveur enregistrée'),
          backgroundColor: Colors.green,
        ),
      );
      _testConnection();
    }
  }

  Future<void> _testAlertConnection() async {
    setState(() {
      _isTestingAlert = true;
      _alertConnectionStatus = null;
    });

    try {
      final response = await http
          .get(Uri.parse('${_alertUrlController.text.trim()}/api/alerts/count'))
          .timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _isTestingAlert = false;
          _alertConnectionStatus = response.statusCode == 200;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTestingAlert = false;
          _alertConnectionStatus = false;
        });
      }
    }
  }

  Future<void> _saveAlertSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alert_server_url', _alertUrlController.text.trim());
    await prefs.setBool('alerts_enabled', _alertsEnabled);

    if (_alertsEnabled) {
      await startAlertService();
    } else {
      await stopAlertService();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paramètres alertes enregistrés'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _alertUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section Serveur Info Job
          _buildServerCard(context),

          const SizedBox(height: 16),

          // Section Alertes
          _buildAlertsCard(context),

          const SizedBox(height: 16),

          // Section À propos
          _buildAboutCard(context),

          const SizedBox(height: 16),

          // Section Aide
          _buildHelpCard(context),
        ],
      ),
    );
  }

  Widget _buildServerCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Serveur Info Job',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL du serveur',
                hintText: 'http://192.168.0.24:8000',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _connectionStatus != null
                    ? Icon(
                        _connectionStatus! ? Icons.check_circle : Icons.error,
                        color: _connectionStatus! ? Colors.green : Colors.red,
                      )
                    : null,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_find),
                    label: Text(_isTesting ? 'Test...' : 'Tester'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveUrl,
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
            _buildStatusBanner(_connectionStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Alertes code-barres',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Switch(
                  value: _alertsEnabled,
                  onChanged: (value) {
                    setState(() => _alertsEnabled = value);
                    _saveAlertSettings();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Notification push toutes les 30 secondes si code-barres manquant (2 feuilles consécutives)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _alertUrlController,
              decoration: InputDecoration(
                labelText: 'URL serveur détection',
                hintText: 'http://192.168.0.24:5001',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.sensors),
                enabled: _alertsEnabled,
                suffixIcon: _alertConnectionStatus != null
                    ? Icon(
                        _alertConnectionStatus! ? Icons.check_circle : Icons.error,
                        color: _alertConnectionStatus! ? Colors.green : Colors.red,
                      )
                    : null,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _alertsEnabled && !_isTestingAlert ? _testAlertConnection : null,
                    icon: _isTestingAlert
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_find),
                    label: Text(_isTestingAlert ? 'Test...' : 'Tester'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _alertsEnabled ? _saveAlertSettings : null,
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
            _buildStatusBanner(_alertConnectionStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(bool? status) {
    if (status == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: status ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: status ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              status ? Icons.check_circle_outline : Icons.error_outline,
              color: status ? Colors.green : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              status ? 'Connexion réussie !' : 'Connexion échouée',
              style: TextStyle(
                color: status ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('À propos',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _AboutRow(label: 'Application', value: 'Dubuc & CO'),
            _AboutRow(label: 'Version', value: '1.1.0'),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Aide',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Codes-barres supportés:',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            const _HelpItem(icon: Icons.work_outline, title: 'Code Job', description: '6 chiffres (ex: 154595)'),
            const _HelpItem(icon: Icons.inventory_2_outlined, title: 'Code Palette', description: '3 lettres + tiret (ex: DAN-12345)'),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _HelpItem({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                Text(description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
