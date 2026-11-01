import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/nfc_service.dart';
import 'public_bike_screen.dart';

class NfcScannerScreen extends StatefulWidget {
  const NfcScannerScreen({super.key});

  @override
  State<NfcScannerScreen> createState() => _NfcScannerScreenState();
}

class _NfcScannerScreenState extends State<NfcScannerScreen> {
  final TextEditingController _manualIdController = TextEditingController();
  bool _isScanning = false;
  String _scanStatus = 'Tap "Start Scan" and bring device close to an NFC plate';

  @override
  void initState() {
    super.initState();
    _startNfcListening();
  }

  @override
  void dispose() {
    NfcService.stopScan();
    _manualIdController.dispose();
    super.dispose();
  }

  void _startNfcListening() async {
    setState(() {
      _isScanning = true;
      _scanStatus = 'Listening for NFC plate... Hold phone near the bike tag';
    });

    await NfcService.startScan(
      onTagScanned: (publicId, raw) {
        if (!mounted) return;
        setState(() {
          _isScanning = false;
          _scanStatus = 'Found plate: $publicId';
        });

        if (publicId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PublicBikeScreen(publicId: publicId),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scanned tag, but no bicycle ID found: $raw'),
              backgroundColor: AppColors.clay,
            ),
          );
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isScanning = false;
          _scanStatus = err;
        });
      },
    );
  }

  void _lookupManualId() {
    final text = _manualIdController.text.trim();
    if (text.isEmpty) return;

    // Check if user entered full URL like https://.../bike/ab3k9mpq
    final regex = RegExp(r'/bike/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(text);
    final publicId = match != null ? match.group(1)! : text;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicBikeScreen(publicId: publicId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Tag Reader'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Scan Bicycle Plate',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap an NTAG215 campus sticker or enter the bike identifier to see the owner profile and report a sighting.',
                style: TextStyle(color: AppColors.inkLight, fontSize: 14),
              ),
              const SizedBox(height: 36),

              // Scanning Animation / Radar Graphic
              Center(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: _isScanning ? AppColors.mist : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isScanning ? AppColors.leaf : AppColors.border,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isScanning
                            ? AppColors.moss.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: 24,
                        spreadRadius: _isScanning ? 8 : 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.nfc_rounded,
                      size: 72,
                      color: _isScanning ? AppColors.moss : AppColors.inkMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _scanStatus,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _isScanning ? AppColors.moss : AppColors.inkLight,
                ),
              ),
              const SizedBox(height: 20),
              if (!_isScanning)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _startNfcListening,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Restart NFC Scan'),
                  ),
                ),

              const SizedBox(height: 40),

              // Manual Entry Option
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Manual Plate Lookup',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the 8-character code or full NFC URL from the bicycle plate.',
                      style: TextStyle(fontSize: 12, color: AppColors.inkLight),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _manualIdController,
                      decoration: const InputDecoration(
                        labelText: 'Public ID or Tag Code',
                        hintText: 'e.g. ab3k9mpq',
                        prefixIcon: Icon(Icons.tag_rounded, color: AppColors.leaf),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _lookupManualId,
                      child: const Text('Lookup Bicycle'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
