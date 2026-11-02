import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../scanner/providers/mesh_provider.dart';
import '../providers/bike_provider.dart';
import '../widgets/status_badge.dart';
import 'bike_detail_screen.dart';
import 'register_bike_screen.dart';

class BikeListScreen extends StatefulWidget {
  const BikeListScreen({super.key});

  @override
  State<BikeListScreen> createState() => _BikeListScreenState();
}

class _BikeListScreenState extends State<BikeListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BikeProvider>().fetchBikes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bikeProvider = context.watch<BikeProvider>();
    final auth = context.watch<AuthProvider>();
    final mesh = context.watch<MeshProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('BOAT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.clay),
            tooltip: 'Sign Out',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Sign out?'),
                  content: const Text('You will need to sign in again to view your bicycles.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.clay),
                      onPressed: () {
                        Navigator.pop(ctx);
                        auth.logout();
                      },
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.moss,
        foregroundColor: AppColors.sand,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Register Bike', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterBikeScreen()),
          );
        },
      ),
      body: RefreshIndicator(
        color: AppColors.moss,
        onRefresh: () async {
          await bikeProvider.fetchBikes();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          children: [
            // User greeting & Header
            Text(
              'Your bicycles',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'NFC Plate, RFID/BLE Tag, and live campus mesh.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.ink.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 20),

            // Passive Mesh Scanner Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: mesh.isMeshActive ? AppColors.mist : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: mesh.isMeshActive ? AppColors.leaf.withValues(alpha: 0.3) : AppColors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: mesh.isMeshActive
                          ? AppColors.leaf.withValues(alpha: 0.18)
                          : AppColors.sand,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      mesh.isMeshActive ? Icons.radar_rounded : Icons.radar_outlined,
                      color: mesh.isMeshActive ? AppColors.moss : AppColors.inkMuted,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Community Mesh Scanner',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: mesh.isMeshActive ? AppColors.moss : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mesh.isMeshActive
                              ? 'Relaying nearby bike beacons in background'
                              : 'Passive BLE beacon relay is off',
                          style: TextStyle(
                            fontSize: 12,
                            color: mesh.isMeshActive ? AppColors.leaf : AppColors.inkLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: mesh.isMeshActive,
                    activeThumbColor: AppColors.moss,
                    activeTrackColor: AppColors.leaf.withValues(alpha: 0.35),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: AppColors.sand,
                    onChanged: (val) {
                      mesh.toggleMeshScanner(val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bikes List / Loading / Empty
            if (bikeProvider.isLoading && bikeProvider.bikes.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: AppColors.moss),
                ),
              )
            else if (bikeProvider.bikes.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.pedal_bike_rounded,
                      size: 54,
                      color: AppColors.moss.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No bicycles yet',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Register your bicycle, write its public ID to an NFC plate, and track its position across campus.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.inkLight, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterBikeScreen()),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Register a bicycle'),
                    ),
                  ],
                ),
              )
            else
              ...bikeProvider.bikes.map((bike) {
                final details = [bike.color, bike.model].where((s) => s != null && s.isNotEmpty).join(' · ');

                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BikeDetailScreen(bikeId: bike.id),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                            fontSize: 20,
                                          ),
                                    ),
                                    if (details.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        details,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.ink.withValues(alpha: 0.65),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Tag ID: ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.ink.withValues(alpha: 0.6),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.sand,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            bike.tagId.isNotEmpty ? bike.tagId : 'Unset',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.moss,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(status: bike.status),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.sand.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 16,
                                  color: bike.isMissing ? AppColors.clay : AppColors.leaf,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    bike.lastLocation != null
                                        ? 'Last seen: ${DateFormat('MMM d, h:mm a').format(bike.lastLocation!.recordedAt)} (${bike.lastLocation!.source.toUpperCase()})'
                                        : 'No sightings yet',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.ink.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: AppColors.inkMuted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
