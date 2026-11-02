import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/nfc_service.dart';
import '../../../core/services/storage_service.dart';
import '../../map/widgets/campus_map_widget.dart';
import '../../scanner/providers/mesh_provider.dart';
import '../models/bike.dart';
import '../providers/bike_provider.dart';
import '../widgets/status_badge.dart';

class BikeDetailScreen extends StatefulWidget {
  final dynamic bikeId;

  const BikeDetailScreen({super.key, required this.bikeId});

  @override
  State<BikeDetailScreen> createState() => _BikeDetailScreenState();
}

class _BikeDetailScreenState extends State<BikeDetailScreen> {
  final GlobalKey<CampusMapWidgetState> _mapKey = GlobalKey<CampusMapWidgetState>();
  final TextEditingController _missingNotesController = TextEditingController();
  bool _isReportingGps = false;
  String? _nfcWriteStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BikeProvider>().fetchBikeDetail(widget.bikeId);
    });
  }

  @override
  void dispose() {
    _missingNotesController.dispose();
    super.dispose();
  }

  void _showReportMissingDialog(Bike bike) {
    _missingNotesController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.clay),
            const SizedBox(width: 8),
            Text('Report ${bike.name} Missing', style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alert the campus mesh network. When anyone running the BOAT app walks near your bike, its location will be immediately updated.',
              style: TextStyle(fontSize: 13, color: AppColors.inkLight),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _missingNotesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. Left near Library cycle stand at 5 PM, lock cut',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.clay),
            onPressed: () async {
              Navigator.pop(ctx);
              final bikeProvider = context.read<BikeProvider>();
              final success = await bikeProvider.updateBikeStatus(
                bike.id,
                'missing',
                notes: _missingNotesController.text,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Bicycle reported as missing.'
                          : (bikeProvider.errorMessage ?? 'Failed to update status'),
                    ),
                    backgroundColor: success ? AppColors.clay : Colors.black87,
                  ),
                );
              }
            },
            child: const Text('Confirm Missing'),
          ),
        ],
      ),
    );
  }

  void _markAsFound(Bike bike) async {
    final bikeProvider = context.read<BikeProvider>();
    final success = await bikeProvider.updateBikeStatus(bike.id, 'active');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Bicycle marked as found and active!' : (bikeProvider.errorMessage ?? 'Failed'),
          ),
          backgroundColor: AppColors.moss,
        ),
      );
    }
  }

  void _reportCurrentGps(Bike bike) async {
    setState(() => _isReportingGps = true);
    final pos = await LocationService.getCurrentLocation();

    if (!mounted) return;

    if (pos == null) {
      setState(() => _isReportingGps = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not acquire GPS position. Check permissions.'),
          backgroundColor: AppColors.clay,
        ),
      );
      return;
    }

    final bikeProvider = context.read<BikeProvider>();
    final success = await bikeProvider.reportLocation(
      publicId: bike.publicId,
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyM: pos.accuracy,
      source: 'ble',
      note: 'Owner manual check-in via BLE proximity',
    );

    if (mounted) {
      setState(() => _isReportingGps = false);
      if (success) {
        _mapKey.currentState?.recenter();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'GPS location fix updated successfully!'
                : (bikeProvider.errorMessage ?? 'Report failed'),
          ),
          backgroundColor: success ? AppColors.moss : AppColors.clay,
        ),
      );
    }
  }

  void _startNfcWrite(Bike bike) async {
    final baseUrl = StorageService().getBaseUrl();
    final bikeUrl = '$baseUrl/bike/${bike.publicId}';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.mist,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.nfc_rounded, color: AppColors.moss, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  'Program NFC Tag',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _nfcWriteStatus ??
                      'Hold your phone near an NFC tag (e.g. NTAG215 plate) to write the bicycle landing URL:\n$bikeUrl',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.inkLight),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    setModalState(() {
                      _nfcWriteStatus = 'Ready: Hold near NFC tag now...';
                    });
                    await NfcService.writeBikeUrl(
                      bikeUrl: bikeUrl,
                      onStatus: (msg) {
                        setModalState(() {
                          _nfcWriteStatus = msg;
                        });
                      },
                    );
                  },
                  child: const Text('Start Writing Tag'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    NfcService.stopScan();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bikeProvider = context.watch<BikeProvider>();
    final mesh = context.watch<MeshProvider>();
    final bike = bikeProvider.selectedBike;

    if (bikeProvider.isLoading && bike == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator(color: AppColors.moss)),
      );
    }

    if (bike == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bicycle Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Could not load bicycle details.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => bikeProvider.fetchBikeDetail(widget.bikeId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Proximity check: Is this bike actively detected in the BLE mesh scans?
    final bool isBikeInProximity = mesh.allScans.any((scan) {
      final isMatch = scan.isBoat &&
          (scan.bikeId.toLowerCase() == bike.publicId.toLowerCase() ||
              scan.bikeId.toLowerCase() == bike.tagId.toLowerCase() ||
              (bike.tagId.isNotEmpty && scan.deviceAddress.toLowerCase() == bike.tagId.toLowerCase()));
      final isRecent = DateTime.now().difference(scan.timestamp).inSeconds < 60;
      return isMatch && isRecent;
    });

    final details = [bike.color, bike.model].where((s) => s != null && s.isNotEmpty).join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: Text(bike.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh & Center',
            onPressed: () async {
              await bikeProvider.fetchBikeDetail(bike.id);
              _mapKey.currentState?.recenter();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.moss,
        onRefresh: () async {
          await bikeProvider.fetchBikeDetail(bike.id);
          _mapKey.currentState?.recenter();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          children: [
            // Header Info & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bike.name,
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details.isNotEmpty ? details : 'Campus bicycle',
                        style: const TextStyle(fontSize: 14, color: AppColors.inkLight),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: bike.status, fontSize: 13),
              ],
            ),
            const SizedBox(height: 16),

            // Status Toggle Action
            if (bike.isMissing)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.clay.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.clay.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: AppColors.clay, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Bicycle is Marked Missing',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.clay,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    if (bike.activeMissingReport?.notes != null &&
                        bike.activeMissingReport!.notes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Note: ${bike.activeMissingReport!.notes}',
                        style: const TextStyle(fontSize: 13, color: AppColors.ink),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.moss,
                        foregroundColor: AppColors.sand,
                      ),
                      onPressed: () => _markAsFound(bike),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Mark as Found (Active)'),
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.clay,
                  side: const BorderSide(color: AppColors.clay, width: 1.5),
                ),
                onPressed: () => _showReportMissingDialog(bike),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Report Bicycle as Missing'),
              ),

            const SizedBox(height: 20),

            // Live Map
            Container(
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CampusMapWidget(
                key: _mapKey,
                bikeName: bike.name,
                isMissing: bike.isMissing,
                lastLocation: bike.lastLocation,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBikeInProximity ? AppColors.moss : Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: (isBikeInProximity && !_isReportingGps) ? () => _reportCurrentGps(bike) : null,
                    icon: _isReportingGps
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isBikeInProximity ? Icons.my_location_rounded : Icons.location_disabled_rounded,
                            size: 18,
                          ),
                    label: Text(
                      isBikeInProximity ? 'Fix GPS Here' : 'Fix GPS (Out of Range)',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _startNfcWrite(bike),
                    icon: const Icon(Icons.nfc_rounded, size: 18),
                    label: const Text('Write NFC Plate', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            if (!isBikeInProximity) ...[
              const SizedBox(height: 6),
              const Text(
                'Bike BLE beacon must be actively scanned nearby to fix GPS.',
                style: TextStyle(fontSize: 11, color: AppColors.inkLight),
              ),
            ],

            const SizedBox(height: 24),

            // Hardware Identifiers Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bicycle & Plate Identifiers',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow('Bicycle Tag', bike.tagId.isNotEmpty ? bike.tagId : 'Unassigned', isMono: true),
                    _buildInfoRow('iBeacon UUID', bike.beaconUuid, isMono: true),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sightings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${((bike.trail?.take(5).length) ?? 0)} recent sightings',
                          style: const TextStyle(fontSize: 12, color: AppColors.inkLight),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (bike.trail == null || bike.trail!.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          'No sightings recorded yet.',
                          style: TextStyle(color: AppColors.inkLight, fontSize: 13),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: bike.trail!.take(5).length,
                        separatorBuilder: (ctx, i) => const Divider(height: 16),
                        itemBuilder: (ctx, idx) {
                          final loc = bike.trail![idx];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.moss,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${loc.lat.toStringAsFixed(5)}, ${loc.lng.toStringAsFixed(5)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (loc.reporterNote != null && loc.reporterNote!.isNotEmpty)
                                      Text(
                                        loc.reporterNote!,
                                        style: const TextStyle(fontSize: 12, color: AppColors.inkLight),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.mist,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      loc.source.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.moss,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('MMM d, h:mm a').format(loc.recordedAt),
                                    style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isMono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontFamily: isMono ? 'monospace' : null,
              fontWeight: isMono ? FontWeight.w600 : FontWeight.w500,
              color: isMono ? AppColors.moss : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
