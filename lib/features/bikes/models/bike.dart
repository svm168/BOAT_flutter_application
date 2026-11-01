import '../../auth/models/user.dart';
import 'location_report.dart';

class MissingReport {
  final int id;
  final int bikeId;
  final String status;
  final DateTime reportedAt;
  final DateTime? resolvedAt;
  final String? notes;

  MissingReport({
    required this.id,
    required this.bikeId,
    required this.status,
    required this.reportedAt,
    this.resolvedAt,
    this.notes,
  });

  factory MissingReport.fromJson(Map<String, dynamic> json) {
    return MissingReport(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      bikeId: json['bike_id'] is int
          ? json['bike_id']
          : int.tryParse(json['bike_id']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'active',
      reportedAt: json['reported_at'] != null
          ? DateTime.parse(json['reported_at'])
          : DateTime.now(),
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at']) : null,
      notes: json['notes'],
    );
  }
}

class Bike {
  final int id;
  final int ownerId;
  final String publicId;
  final String name;
  final String? color;
  final String? model;
  final String tagId;
  final String status; // 'active' or 'missing'
  final String beaconUuid;
  final int beaconMajor;
  final int beaconMinor;
  final DateTime createdAt;
  final LocationReport? lastLocation;
  final List<LocationReport>? trail;
  final MissingReport? activeMissingReport;
  final User? owner;

  Bike({
    required this.id,
    required this.ownerId,
    required this.publicId,
    required this.name,
    this.color,
    this.model,
    required this.tagId,
    required this.status,
    required this.beaconUuid,
    required this.beaconMajor,
    required this.beaconMinor,
    required this.createdAt,
    this.lastLocation,
    this.trail,
    this.activeMissingReport,
    this.owner,
  });

  bool get isMissing => status.toLowerCase() == 'missing';

  factory Bike.fromJson(Map<String, dynamic> json, {
    LocationReport? lastLocation,
    List<LocationReport>? trail,
    MissingReport? activeMissingReport,
    User? owner,
  }) {
    return Bike(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      ownerId: json['owner_id'] is int
          ? json['owner_id']
          : int.tryParse(json['owner_id']?.toString() ?? '0') ?? 0,
      publicId: json['public_id'] ?? json['publicId'] ?? '',
      name: json['name'] ?? '',
      color: json['color'],
      model: json['model'],
      tagId: json['tag_id'] ?? json['tagId'] ?? '',
      status: json['status'] ?? 'active',
      beaconUuid: json['beacon_uuid'] ?? json['beaconUuid'] ?? '',
      beaconMajor: json['beacon_major'] is int
          ? json['beacon_major']
          : int.tryParse(json['beacon_major']?.toString() ?? '1') ?? 1,
      beaconMinor: json['beacon_minor'] is int
          ? json['beacon_minor']
          : int.tryParse(json['beacon_minor']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : (json['registeredAt'] != null ? DateTime.parse(json['registeredAt']) : DateTime.now()),
      lastLocation: lastLocation ?? (json['lastLocation'] != null ? LocationReport.fromJson(json['lastLocation']) : null),
      trail: trail,
      activeMissingReport: activeMissingReport,
      owner: owner ?? (json['owner'] != null ? User.fromJson(json['owner']) : null),
    );
  }
}
