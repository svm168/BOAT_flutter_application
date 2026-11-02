import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/beacon_scanner_service.dart';
import '../providers/mesh_provider.dart';

class MeshStatusScreen extends StatefulWidget {
  const MeshStatusScreen({super.key});

  @override
  State<MeshStatusScreen> createState() => _MeshStatusScreenState();
}

class _MeshStatusScreenState extends State<MeshStatusScreen> {
  final ScrollController _bleScrollController = ScrollController();
  String? _uploadingBikeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MeshProvider>().refreshScans();
    });
  }

  @override
  void dispose() {
    _bleScrollController.dispose();
    super.dispose();
  }

  void _uploadManualFix(String bikeId) async {
    setState(() {
      _uploadingBikeId = bikeId;
    });

    final mesh = context.read<MeshProvider>();
    final result = await mesh.uploadTestFix(bikeId);

    if (!mounted) return;
    setState(() {
      _uploadingBikeId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['ok'] == true
              ? 'GPS fix for bike $bikeId uploaded to database!'
              : 'Upload failed: ${result['error']}',
        ),
        backgroundColor: result['ok'] == true ? AppColors.moss : AppColors.clay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<MeshProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh Diagnostics'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            Text(
              'Community Mesh Relay',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 4),
            const Text(
              'Passive background scanner detecting nearby ESP32-C3 beacons on campus bikes.',
              style: TextStyle(color: AppColors.inkLight, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Active Toggle Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: mesh.isMeshActive ? AppColors.mist : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: mesh.isMeshActive ? AppColors.leaf.withValues(alpha: 0.4) : AppColors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            mesh.isMeshActive ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                            color: mesh.isMeshActive ? AppColors.moss : AppColors.inkMuted,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mesh.isMeshActive ? 'Scanner Running' : 'Scanner Stopped',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                mesh.isMeshActive ? 'Listening for BLE "BOAT" beacons' : 'Passive relay is off',
                                style: const TextStyle(fontSize: 12, color: AppColors.inkLight),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: mesh.isMeshActive,
                        activeThumbColor: AppColors.moss,
                        activeTrackColor: AppColors.leaf.withValues(alpha: 0.35),
                        onChanged: (val) => mesh.toggleMeshScanner(val),
                      ),
                    ],
                  ),
                  if (mesh.statusMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      mesh.statusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: mesh.isMeshActive ? AppColors.moss : AppColors.clay,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- NEARBY BLE SCANS SECTION ---
            _buildNearbyBleSection(mesh),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyBleSection(MeshProvider mesh) {
    final scans = mesh.recentScans;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.moss.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bluetooth_searching_rounded,
                        color: AppColors.moss,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nearby BLE Scans',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          mesh.isMeshActive ? 'Live packets in range' : 'Scanner is currently off',
                          style: const TextStyle(fontSize: 12, color: AppColors.inkLight),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  tooltip: 'Clear list',
                  onPressed: scans.isEmpty ? null : () => mesh.clearScans(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Filter Chips
            Row(
              children: [
                FilterChip(
                  label: Text('All (${mesh.allScans.length})'),
                  selected: !mesh.filterBoatOnly,
                  onSelected: (val) {
                    if (val) mesh.setFilterBoatOnly(false);
                  },
                  selectedColor: AppColors.leaf.withValues(alpha: 0.25),
                  checkmarkColor: AppColors.moss,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.pedal_bike_rounded, size: 16, color: AppColors.moss),
                  label: Text('BOAT Only (${mesh.boatCount})'),
                  selected: mesh.filterBoatOnly,
                  onSelected: (val) => mesh.setFilterBoatOnly(val),
                  selectedColor: AppColors.leaf.withValues(alpha: 0.25),
                  checkmarkColor: AppColors.moss,
                ),
              ],
            ),

            if (mesh.isMeshActive) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.leaf,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Scanning...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.moss,
                    ),
                  ),
                ],
              ),
            ],

            const Divider(height: 24),

            // Scanned Devices List / Empty State
            if (scans.isEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.sand.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                child: Column(
                  children: [
                    Icon(
                      mesh.isMeshActive
                          ? Icons.radar_rounded
                          : Icons.bluetooth_disabled_rounded,
                      size: 40,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      mesh.isMeshActive
                          ? 'Listening for BLE signals...'
                          : 'Scanner is inactive',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mesh.isMeshActive
                          ? 'Make sure your ESP32-C3 is broadcasting as "BOAT" and within 10-30 meters.'
                          : 'Turn ON the switch above to start scanning for nearby BLE bike beacons.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.inkLight),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                height: 380,
                child: Scrollbar(
                  controller: _bleScrollController,
                  thumbVisibility: true,
                  radius: const Radius.circular(8),
                  thickness: 4,
                  child: ListView.separated(
                    controller: _bleScrollController,
                    padding: const EdgeInsets.only(right: 8),
                    itemCount: scans.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final item = scans[index];
                      return _buildDeviceScanCard(item);
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceScanCard(BleScanResultModel item) {
    final isUploadingThis = _uploadingBikeId == item.bikeId;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.isBoat ? AppColors.mist : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isBoat ? AppColors.leaf : AppColors.border,
          width: item.isBoat ? 1.4 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Name, BOAT Badge, RSSI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    item.isBoat ? Icons.pedal_bike_rounded : Icons.bluetooth_rounded,
                    color: item.isBoat ? AppColors.moss : AppColors.inkLight,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.deviceName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (item.isBoat) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.moss,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'BIKE',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              // RSSI Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _rssiColor(item.rssi).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.network_wifi_rounded, size: 12, color: _rssiColor(item.rssi)),
                    const SizedBox(width: 4),
                    Text(
                      '${item.rssi} dBm',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _rssiColor(item.rssi),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (item.bikeId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text(
                    'Bike ID: ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.moss),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.leaf.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.bikeId,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: AppColors.moss,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Upload Status & Cooldown Timer
          Row(
            children: [
              Icon(
                _statusIcon(item.uploadStatus),
                size: 14,
                color: _statusColor(item.uploadStatus),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.isBoat ? item.uploadStatus : 'Non-BOAT (ignored)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(item.uploadStatus),
                  ),
                ),
              ),
            ],
          ),
          if (item.isBoat && item.bikeId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: isUploadingThis ? null : () => _uploadManualFix(item.bikeId),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.moss,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isUploadingThis
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Upload Fix Now',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -65) return AppColors.leaf;
    if (rssi >= -80) return Colors.amber.shade800;
    return AppColors.inkMuted;
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('uploaded') || lower.contains('200')) return AppColors.moss;
    if (lower.contains('cooldown')) return Colors.orange.shade800;
    if (lower.contains('acquiring') || lower.contains('uploading')) return Colors.blue.shade700;
    if (lower.contains('failed') || lower.contains('error') || lower.contains('rejected')) {
      return AppColors.clay;
    }
    return AppColors.inkLight;
  }

  IconData _statusIcon(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('uploaded') || lower.contains('200')) return Icons.check_circle_rounded;
    if (lower.contains('cooldown')) return Icons.timelapse_rounded;
    if (lower.contains('acquiring') || lower.contains('uploading')) return Icons.sync_rounded;
    if (lower.contains('failed') || lower.contains('error') || lower.contains('rejected')) {
      return Icons.error_outline_rounded;
    }
    return Icons.radio_button_checked_rounded;
  }
}
