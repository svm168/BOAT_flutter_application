import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/campus_config.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/time_utils.dart';
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
  State<CampusMapWidget> createState() => CampusMapWidgetState();
}

class CampusMapWidgetState extends State<CampusMapWidget> {
  final MapController _mapController = MapController();
  final Dio _dio = Dio();

  LatLng? _deviceLocation;
  StreamSubscription<Position>? _positionSub;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;
  double? _routeDistanceM;
  double? _routeDurationS;
  String? _routeError;

  @override
  void initState() {
    super.initState();
    _startLiveLocation();
    if (widget.lastLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fetchShortestPath();
      });
    }
  }

  void _startLiveLocation() async {
    final hasPerm = await LocationService.checkAndRequestPermission();
    if (!hasPerm || !mounted) return;

    final initial = await LocationService.getCurrentLocation();
    if (initial != null && mounted) {
      setState(() {
        _deviceLocation = LatLng(initial.latitude, initial.longitude);
      });
    }

    _positionSub = LocationService.getPositionStream().listen((pos) {
      if (mounted) {
        setState(() {
          _deviceLocation = LatLng(pos.latitude, pos.longitude);
          if (_routePoints.isNotEmpty) {
            _routePoints[0] = _deviceLocation!;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  void recenter() {
    final target = widget.lastLocation != null
        ? LatLng(widget.lastLocation!.lat, widget.lastLocation!.lng)
        : LatLng(
            widget.center?.latitude ?? CampusConfig.defaultLat,
            widget.center?.longitude ?? CampusConfig.defaultLng,
          );
    _mapController.move(target, 16.5);
  }

  Future<void> fetchShortestPath() async {
    if (widget.lastLocation == null) return;
    setState(() {
      _isLoadingRoute = true;
      _routeError = null;
    });

    try {
      LatLng devLoc;
      if (_deviceLocation != null) {
        devLoc = _deviceLocation!;
      } else {
        final pos = await LocationService.getCurrentLocation();
        if (pos == null) {
          if (mounted) {
            setState(() {
              _isLoadingRoute = false;
              _routeError = 'GPS permission needed';
            });
          }
          return;
        }
        devLoc = LatLng(pos.latitude, pos.longitude);
      }

      final bikeLoc = LatLng(widget.lastLocation!.lat, widget.lastLocation!.lng);

      // OpenStreetMap OSRM routing API for shortest road path
      final url =
          'https://router.project-osrm.org/route/v1/driving/${devLoc.longitude},${devLoc.latitude};${bikeLoc.longitude},${bikeLoc.latitude}?overview=full&geometries=geojson';

      final res = await _dio.get(url);
      if (res.statusCode == 200 &&
          res.data['routes'] != null &&
          (res.data['routes'] as List).isNotEmpty) {
        final route = res.data['routes'][0];
        final coords = (route['geometry']['coordinates'] as List)
            .map((pt) => LatLng((pt[1] as num).toDouble(), (pt[0] as num).toDouble()))
            .toList();

        final dist = (route['distance'] as num?)?.toDouble() ?? 0.0;
        // Pedestrian walking speed ~5 km/h (1.39 m/s or 83.3 m/min)
        final walkingDurationS = dist > 0 ? (dist / 1.39) : 60.0;

        if (mounted) {
          setState(() {
            _deviceLocation = devLoc;
            _routePoints = coords;
            _routeDistanceM = dist;
            _routeDurationS = walkingDurationS;
            _isLoadingRoute = false;
          });

          if (coords.isNotEmpty) {
            final bounds = LatLngBounds.fromPoints([devLoc, bikeLoc, ...coords]);
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _deviceLocation = devLoc;
            _routePoints = [devLoc, bikeLoc];
            _isLoadingRoute = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
          _routeError = 'Route unavailable';
        });
      }
    }
  }

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
      fetchShortestPath();
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
              initialZoom: 16.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.boat.tracker.boat_mobile',
              ),
              // Shortest Road Route Polyline from Device to Bike
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.5,
                      color: AppColors.moss,
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              // Markers: Device location & Bicycle location
              MarkerLayer(
                markers: [
                  if (_deviceLocation != null)
                    Marker(
                      point: _deviceLocation!,
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      child: _buildDeviceMarker(),
                    ),
                  if (widget.lastLocation != null)
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

          // Route distance & walking time banner
          if (_routeDistanceM != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.leaf,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _routeDistanceM! < 1000
                            ? '${_routeDistanceM!.round()} m'
                            : '${(_routeDistanceM! / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.moss,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '· ~${(_routeDurationS != null ? (_routeDurationS! / 60).round().clamp(1, 999) : 1)} min on foot',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.ink.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _routePoints = [];
                            _routeDistanceM = null;
                            _routeDurationS = null;
                            _routeError = null;
                          });
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_routeError != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.clay.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.clay),
                      const SizedBox(width: 6),
                      Text(
                        _routeError!,
                        style: const TextStyle(fontSize: 11, color: AppColors.clay),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Map Action Buttons (Route & Recenter)
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'map_route_btn',
                  backgroundColor: AppColors.moss,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  tooltip: 'Shortest road path to bike',
                  onPressed: _isLoadingRoute ? null : fetchShortestPath,
                  child: _isLoadingRoute
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.directions_rounded, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'map_recenter_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.moss,
                  elevation: 2,
                  tooltip: 'Center on bicycle',
                  onPressed: recenter,
                  child: const Icon(Icons.my_location, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
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
              'Recorded: ${TimeUtils.formatIst(loc.recordedAt, pattern: 'MMM d, yyyy h:mm:ss a')}',
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
