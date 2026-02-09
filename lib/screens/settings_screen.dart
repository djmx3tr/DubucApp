import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _urlController.text = api.serverUrl;
    final alertService = context.read<AlertService>();
    _alertUrlController.text = alertService.alertServerUrl;
  }

  Future<void> _testConnection() async {
    setState(() { _isTesting = true; _connectionStatus = null; });
    final result = await context.read<ApiService>().testConnection();
    if (mounted) setState(() { _isTesting = false; _connectionStatus = result; });
  }

  Future<void> _saveUrl() async {
    await context.read<ApiService>().setServerUrl(_urlController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL enregistrée'), backgroundColor: Colors.green),
      );
      _testConnection();
    }
  }

  Future<void> _testAlertConnection() async {
    setState(() { _isTestingAlert = true; _alertConnectionStatus = null; });
    final result = await context.read<AlertService>().testConnection();
    if (mounted) setState(() { _isTestingAlert = false; _alertConnectionStatus = result; });
  }

  Future<void> _saveAlertUrl() async {
    await context.read<AlertService>().setAlertServerUrl(_alertUrlController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL alertes enregistrée'), backgroundColor: Colors.green),
      );
      _testAlertConnection();
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
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Serveur Info Job
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.dns_outlined, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Serveur Info Job', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'URL du serveur',
                      hintText: 'http://192.168.0.24:8000',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: _connectionStatus != null
                          ? Icon(_connectionStatus! ? Icons.check_circle : Icons.error,
                              color: _connectionStatus! ? Colors.green : Colors.red)
                          : null,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.wifi_find),
                      label: Text(_isTesting ? 'Test...' : 'Tester'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton.icon(onPressed: _saveUrl, icon: const Icon(Icons.save), label: const Text('Enregistrer'))),
                  ]),
                  _buildStatusBanner(_connectionStatus),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Serveur Alertes
          Consumer<AlertService>(
            builder: (context, alertService, _) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.notifications_outlined, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Alertes code-barres', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Switch(
                          value: alertService.isEnabled,
                          onChanged: (v) => alertService.setEnabled(v),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        'Vérifie toutes les 5 secondes. Alerte si 2+ feuilles consécutives sans code-barres.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _alertUrlController,
                        decoration: InputDecoration(
                          labelText: 'URL serveur détection',
                          hintText: 'http://192.168.0.24:5001',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.sensors),
                          enabled: alertService.isEnabled,
                          suffixIcon: _alertConnectionStatus != null
                              ? Icon(_alertConnectionStatus! ? Icons.check_circle : Icons.error,
                                  color: _alertConnectionStatus! ? Colors.green : Colors.red)
                              : null,
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: alertService.isEnabled && !_isTestingAlert ? _testAlertConnection : null,
                          icon: _isTestingAlert
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.wifi_find),
                          label: Text(_isTestingAlert ? 'Test...' : 'Tester'),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: FilledButton.icon(
                          onPressed: alertService.isEnabled ? _saveAlertUrl : null,
                          icon: const Icon(Icons.save), label: const Text('Enregistrer'),
                        )),
                      ]),
                      _buildStatusBanner(_alertConnectionStatus),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // À propos
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('À propos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 16),
                  _infoRow('Application', 'Dubuc & CO'),
                  _infoRow('Version', '1.2.0'),
                  const SizedBox(height: 12),
                  Text('Codes supportés:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  _infoRow('Job', '6 chiffres (ex: 154595)'),
                  _infoRow('Palette', '3 lettres + tiret (ex: DAN-12345)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
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
        ),
        child: Row(children: [
          Icon(status ? Icons.check_circle_outline : Icons.error_outline,
              color: status ? Colors.green : Colors.red, size: 20),
          const SizedBox(width: 8),
          Text(status ? 'Connexion réussie !' : 'Connexion échouée',
              style: TextStyle(color: status ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
