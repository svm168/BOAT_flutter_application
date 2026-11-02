import 'package:flutter/services.dart';

class BleScanResultModel {
  final String deviceName;
  final String deviceAddress;
  final int rssi;
  final String rawHex;
  final String bikeId;
  final bool isBoat;
  final DateTime timestamp;
  final String uploadStatus;
  final DateTime? lastUploadedAt;

  BleScanResultModel({
    required this.deviceName,
    required this.deviceAddress,
    required this.rssi,
    required this.rawHex,
    required this.bikeId,
    required this.isBoat,
    required this.timestamp,
    required this.uploadStatus,
    this.lastUploadedAt,
  });

  factory BleScanResultModel.fromMap(Map<dynamic, dynamic> map) {
    final ts = map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final lastUp = map['lastUploadedAt'] as int? ?? 0;
    return BleScanResultModel(
      deviceName: (map['deviceName'] as String?)?.isNotEmpty == true
          ? map['deviceName'] as String
          : 'Unknown Device',
      deviceAddress: map['deviceAddress'] as String? ?? '00:00:00:00:00:00',
      rssi: map['rssi'] as int? ?? 0,
      rawHex: map['rawHex'] as String? ?? '',
      bikeId: map['bikeId'] as String? ?? '',
      isBoat: map['isBoat'] as bool? ?? false,
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
      uploadStatus: map['uploadStatus'] as String? ?? 'Detected',
      lastUploadedAt: lastUp > 0 ? DateTime.fromMillisecondsSinceEpoch(lastUp) : null,
    );
  }
}

class BeaconScannerService {
  static const MethodChannel _channel = MethodChannel('com.boat.tracker/beacon_scanner');
  static const EventChannel _eventChannel = EventChannel('com.boat.tracker/ble_scan_events');

  static Stream<BleScanResultModel>? _scanStream;

  /// Real-time stream of nearby BLE scan sightings from the Android background scanner.
  static Stream<BleScanResultModel> get scanStream {
    _scanStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => BleScanResultModel.fromMap(event as Map<dynamic, dynamic>));
    return _scanStream!;
  }

  /// Starts the sticky native Android Foreground Beacon/BLE Scanner.
  static Future<bool> startScanning({
    required String serverUrl,
    required String beaconUuid,
  }) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('startScanning', {
        'serverUrl': serverUrl,
        'beaconUuid': beaconUuid,
      });
      return success ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Stops the native background service.
  static Future<bool> stopScanning() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('stopScanning');
      return success ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if service is actively running.
  static Future<bool> isScanning() async {
    try {
      final bool? running = await _channel.invokeMethod<bool>('isScanning');
      return running ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Gets recently scanned BLE devices from native in-memory cache.
  static Future<List<BleScanResultModel>> getRecentScans() async {
    try {
      final List<dynamic>? list = await _channel.invokeMethod<List<dynamic>>('getRecentScans');
      if (list == null) return [];
      return list.map((e) => BleScanResultModel.fromMap(e as Map<dynamic, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Clears recently scanned BLE devices in native memory.
  static Future<bool> clearScans() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('clearScans');
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks whether Bluetooth is enabled on device.
  static Future<bool> isBluetoothEnabled() async {
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('isBluetoothEnabled');
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests the user to turn on Bluetooth via the system dialog.
  static Future<bool> requestEnableBluetooth() async {
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('requestEnableBluetooth');
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }
}
