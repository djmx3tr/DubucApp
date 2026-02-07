import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/job.dart';
import 'job_detail_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final code = barcode.rawValue!.trim();
    
    // Éviter de scanner le même code plusieurs fois de suite
    if (code == _lastScannedCode) return;
    
    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    final api = context.read<ApiService>();
    Job? job;
    String scanType = '';

    // Déterminer le type de code scanné
    if (RegExp(r'^\d{6}$').hasMatch(code)) {
      // Code de job (6 chiffres)
      scanType = 'Job';
      job = await api.getJob(int.parse(code));
    } else if (RegExp(r'^[A-Za-z]{3}-').hasMatch(code)) {
      // Code de palette (XXX-...)
      scanType = 'Palette';
      job = await api.findJobByPalette(code);
    } else {
      // Essayer comme ID de job générique
      final jobId = int.tryParse(code);
      if (jobId != null) {
        scanType = 'Job';
        job = await api.getJob(jobId);
      }
    }

    if (!mounted) return;

    if (job != null) {
      // Pause le scanner et naviguer vers les détails
      _controller?.stop();
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(job: job!),
        ),
      );
      
      // Reprendre le scanner au retour
      _controller?.start();
      _lastScannedCode = null;
    } else {
      // Afficher l'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(api.error ?? '$scanType "$code" introuvable'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller?.torchState ?? ValueNotifier(TorchState.off),
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                );
              },
            ),
            onPressed: () => _controller?.toggleTorch(),
            tooltip: 'Flash',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller?.switchCamera(),
            tooltip: 'Changer caméra',
          ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              children: [
                Text(
                  'Scannez un code-barres',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Job (6 chiffres) ou Palette (XXX-...)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          // Scanner
          Expanded(
            child: Stack(
              children: [
                if (_controller != null)
                  MobileScanner(
                    controller: _controller!,
                    onDetect: _onDetect,
                  ),
                
                // Overlay avec cadre de scan
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 280,
                      height: 140,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isProcessing 
                              ? Colors.green 
                              : Theme.of(context).colorScheme.primary,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _isProcessing
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.green,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),

                // Dernier code scanné
                if (_lastScannedCode != null)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Scanné: $_lastScannedCode',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
