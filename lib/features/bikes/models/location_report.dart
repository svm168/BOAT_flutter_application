class LocationReport {
  final int id;
  final int bikeId;
  final double lat;
  final double lng;
  final double? accuracyM;
  final String source;
  final String? reporterNote;
  final DateTime recordedAt;

  LocationReport({
    required this.id,
    required this.bikeId,
    required this.lat,
    required this.lng,
    this.accuracyM,
    required this.source,
    this.reporterNote,
    required this.recordedAt,
  });

  factory LocationReport.fromJson(Map<String, dynamic> json) {
    return LocationReport(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      bikeId: json['bike_id'] is int
          ? json['bike_id']
          : int.tryParse(json['bike_id']?.toString() ?? '0') ?? 0,
      lat: (json['lat'] is num) ? (json['lat'] as num).toDouble() : double.parse(json['lat'].toString()),
      lng: (json['lng'] is num) ? (json['lng'] as num).toDouble() : double.parse(json['lng'].toString()),
      accuracyM: json['accuracy_m'] != null
          ? (json['accuracy_m'] as num).toDouble()
          : (json['accuracyM'] != null ? (json['accuracyM'] as num).toDouble() : null),
      source: json['source'] ?? 'ble',
      reporterNote: json['reporter_note'] ?? json['note'],
      recordedAt: json['recorded_at'] != null
          ? DateTime.parse(json['recorded_at'])
          : (json['recordedAt'] != null ? DateTime.parse(json['recordedAt']) : DateTime.now()),
    );
  }
}
