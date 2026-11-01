import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/location_service.dart';
import '../../bikes/models/bike.dart';
import '../../bikes/widgets/status_badge.dart';
import '../../map/widgets/campus_map_widget.dart';

class PublicBikeScreen extends StatefulWidget {
  final String publicId;

  const PublicBikeScreen({super.key, required this.publicId});

  @override
  State<PublicBikeScreen> createState() => _PublicBikeScreenState();
}

class _PublicBikeScreenState extends State<PublicBikeScreen> {
  final ApiClient _api = ApiClient();
  Bike? _bike;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isReportingFix = false;

  @override
  void initState() {
    super.initState();
    _fetchPublicBike();
  }

  Future<void> _fetchPublicBike() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.getPublicBike(widget.publicId);
      if (res['bike'] != null) {
        setState(() {
          _bike = Bike.fromJson(res['bike'] as Map<String, dynamic>);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Bicycle not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load public bicycle details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _reportLocationFix() async {
    setState(() => _isReportingFix = true);
    final pos = await LocationService.getCurrentLocation();

    if (!mounted) return;

    if (pos == null) {
      setState(() => _isReportingFix = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get GPS fix. Please ensure location permissions are granted.'),
          backgroundColor: AppColors.clay,
        ),
      );
      return;
    }

    try {
      await _api.reportLocation(
        publicId: widget.publicId,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy,
        source: 'manual',
        note: 'Finder tap report from BOAT mobile app',
      );

      await _fetchPublicBike();

      if (mounted) {
        setState(() => _isReportingFix = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Location fix reported to bike owner.'),
            backgroundColor: AppColors.moss,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReportingFix = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reporting fix: $e'),
            backgroundColor: AppColors.clay,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bicycle Plate'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.moss))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 64, color: AppColors.clay),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchPublicBike,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.moss,
                  onRefresh: _fetchPublicBike,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    children: [
                      // Ownership Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'CAMPUS BICYCLE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: AppColors.leaf,
                                    ),
                                  ),
                                  StatusBadge(status: _bike!.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _bike!.name,
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [_bike!.color, _bike!.model]
                                    .where((s) => s != null && s.isNotEmpty)
                                    .join(' · '),
                                style: const TextStyle(fontSize: 14, color: AppColors.inkLight),
                              ),
                              const Divider(height: 28),
                              _buildDetailItem('Owner', _bike!.owner?.displayName ?? 'Unknown'),
                              if (_bike!.owner?.phone != null && _bike!.owner!.phone!.isNotEmpty)
                                _buildDetailItem('Phone', _bike!.owner!.phone!),
                              _buildDetailItem(
                                'Address on Campus',
                                [_bike!.owner?.hostel, _bike!.owner?.room]
                                    .where((s) => s != null && s.isNotEmpty)
                                    .join(', ')
                                    .isNotEmpty
                                    ? [_bike!.owner?.hostel, _bike!.owner?.room]
                                        .where((s) => s != null && s.isNotEmpty)
                                        .join(', ')
                                    : 'Not listed',
                              ),
                              if (_bike!.owner?.email != null)
                                _buildDetailItem('Owner Email', _bike!.owner!.email),
                              if (_bike!.tagId.isNotEmpty)
                                _buildDetailItem('Tag ID', _bike!.tagId, isMono: true),
                              const SizedBox(height: 20),
                              // 1-Tap Location Fix Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.moss,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onPressed: _isReportingFix ? null : _reportLocationFix,
                                  icon: _isReportingFix
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.sand,
                                          ),
                                        )
                                      : const Icon(Icons.share_location_rounded),
                                  label: const Text(
                                    'Report 1-Tap Location Fix',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Map Section
                      Container(
                        height: 240,
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
                          bikeName: _bike!.name,
                          isMissing: _bike!.isMissing,
                          lastLocation: _bike!.lastLocation,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isMono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontFamily: isMono ? 'monospace' : null,
              fontWeight: isMono ? FontWeight.bold : FontWeight.w500,
              color: isMono ? AppColors.moss : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
