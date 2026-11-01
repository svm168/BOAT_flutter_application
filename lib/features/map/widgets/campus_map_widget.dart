import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/campus_config.dart';
import '../../bikes/models/location_report.dart';

class CampusMapWidget extends StatefulWidget {
  final LatLng? center;
  final LocationReport? lastLocation;
  final List<LocationReport>? trail;
  final String bikeName;
  final bool isMissing;

  const CampusMapWidget({
    super.key,
    this.center,
    this.lastLocation,
    this.trail,
    required this.bikeName,
    this.isMissing = false,
  });

  @override
  State<CampusMapWidget> createState() => _CampusMapWidgetState();
}

class _CampusMapWidgetState extends State<CampusMapWidget> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant CampusMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastLocation != null &&
        (oldWidget.lastLocation == null ||
            widget.lastLocation!.lat != oldWidget.lastLocation!.lat ||
            widget.lastLocation!.lng != oldWidget.lastLocation!.lng)) {
      _mapController.move(
        LatLng(widget.lastLocation!.lat, widget.lastLocation!.lng),
        16.5,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultLatLng = LatLng(
      widget.center?.latitude ?? CampusConfig.defaultLat,
      widget.center?.longitude ?? CampusConfig.defaultLng,
    );

    final currentPoint = widget.lastLocation != null
        ? LatLng(widget.lastLocation!.lat, widget.lastLocation!.lng)
        : defaultLatLng;

    // Build polyline coordinates
    final List<LatLng> polylinePoints = [];
    if (widget.trail != null && widget.trail!.isNotEmpty) {
      for (final p in widget.trail!) {
        polylinePoints.add(LatLng(p.lat, p.lng));
      }
    }
    if (widget.lastLocation != null && !polylinePoints.contains(currentPoint)) {
      polylinePoints.add(currentPoint);
    }

    final pinColor = widget.isMissing
        ? AppColors.clay
        : (widget.lastLocation?.source == 'mock' ? const Color(0xFFD97706) : AppColors.moss);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentPoint,
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.boat.tracker.boat_mobile',
              ),
              if (polylinePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polylinePoints,
                      strokeWidth: 4.0,
                      color: AppColors.moss.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              // Trail waypoint markers
              if (widget.trail != null && widget.trail!.length > 1)
                MarkerLayer(
                  markers: widget.trail!.sublist(0, widget.trail!.length - 1).map((loc) {
                    return Marker(
                      point: LatLng(loc.lat, loc.lng),
                      width: 14,
                      height: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.leaf,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              // Primary Bike Marker
              if (widget.lastLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentPoint,
                      width: 44,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => _showLocationInfo(context),
                        child: _buildPin(pinColor),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Recenter FAB inside map
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'map_recenter_btn',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.moss,
              elevation: 2,
              onPressed: () {
                _mapController.move(currentPoint, 16.5);
              },
              child: const Icon(Icons.my_location, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPin(Color pinColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: pinColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: pinColor.withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: AppColors.sand, width: 2.5),
          ),
          child: const Center(
            child: Icon(
              Icons.directions_bike_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(10, 8),
          painter: _TrianglePainter(pinColor),
        ),
      ],
    );
  }

  void _showLocationInfo(BuildContext context) {
    final loc = widget.lastLocation;
    if (loc == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.bikeName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.mist,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    loc.source.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.moss,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Coordinates: ${loc.lat.toStringAsFixed(5)}, ${loc.lng.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 14, color: AppColors.inkLight),
            ),
            if (loc.accuracyM != null) ...[
              const SizedBox(height: 4),
              Text(
                'Accuracy: ±${loc.accuracyM!.toStringAsFixed(1)} m',
                style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
              ),
            ],
            if (loc.reporterNote != null && loc.reporterNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Note: ${loc.reporterNote}',
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Recorded: ${loc.recordedAt.toLocal().toString().split('.')[0]}',
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
