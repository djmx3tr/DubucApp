import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/job.dart';
import 'job_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CurrentJob> _currentJobs = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    
    final api = context.read<ApiService>();
    final jobs = await api.getCurrentJobs();
    
    if (mounted) {
      setState(() {
        _currentJobs = jobs;
        _isLoading = false;
      });
    }
  }

  Future<void> _searchJob() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final api = context.read<ApiService>();
    Job? job;

    // Déterminer si c'est un ID de job (6 chiffres) ou une palette (XXX-...)
    if (RegExp(r'^\d{6}$').hasMatch(query)) {
      // C'est un ID de job
      job = await api.getJob(int.parse(query));
    } else if (RegExp(r'^[A-Za-z]{3}-').hasMatch(query)) {
      // C'est un ID de palette
      job = await api.findJobByPalette(query);
    } else {
      // Essayer comme ID de job
      final jobId = int.tryParse(query);
      if (jobId != null) {
        job = await api.getJob(jobId);
      }
    }

    if (job != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(job: job!),
        ),
      );
    } else if (api.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(api.error!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dubuc & CO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJobs,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Job (154595) ou Palette (DAN-...)',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchJob(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _searchJob,
                  child: const Text('Chercher'),
                ),
              ],
            ),
          ),

          // Liste des jobs en cours
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _currentJobs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun job en cours',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _loadJobs,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Actualiser'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadJobs,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _currentJobs.length,
                          itemBuilder: (context, index) {
                            final job = _currentJobs[index];
                            return _JobCard(
                              job: job,
                              onTap: () async {
                                final api = context.read<ApiService>();
                                final jobId = int.tryParse(job.jobNumber);
                                if (jobId != null) {
                                  final fullJob = await api.getJob(jobId);
                                  if (fullJob != null && mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => JobDetailScreen(job: fullJob),
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final CurrentJob job;
  final VoidCallback onTap;

  const _JobCard({
    required this.job,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              Icons.work_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        title: Text(
          'Job #${job.jobNumber}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: job.line != null
            ? Text('Ligne ${ job.line}')
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
