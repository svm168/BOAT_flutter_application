import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/campus_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/beacon_scanner_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/storage_service.dart';

class MeshProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  bool _isMeshActive = false;
  bool _isLoading = false;
  String _serverUrl = ApiEndpoints.defaultBaseUrl;
  final String _beaconUuid = CampusConfig.defaultBeaconUuid;
  String? _statusMessage;

  List<BleScanResultModel> _recentScans = [];
  bool _filterBoatOnly = false;
  StreamSubscription<BleScanResultModel>? _scanSubscription;

  bool get isMeshActive => _isMeshActive;
  bool get isLoading => _isLoading;
  String get serverUrl => _serverUrl;
  String get beaconUuid => _beaconUuid;
  String? get statusMessage => _statusMessage;

  bool get filterBoatOnly => _filterBoatOnly;
  List<BleScanResultModel> get recentScans =>
      _filterBoatOnly ? _recentScans.where((s) => s.isBoat).toList() : _recentScans;
  List<BleScanResultModel> get allScans => _recentScans;
  int get boatCount => _recentScans.where((s) => s.isBoat).length;

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void setFilterBoatOnly(bool value) {
    _filterBoatOnly = value;
    notifyListeners();
  }

  Future<void> initMesh() async {
    _serverUrl = _storage.getBaseUrl();
    _isMeshActive = _storage.isMeshScannerActive();

    // Verify actual service state on Android
    if (_isAndroid) {
      final running = await BeaconScannerService.isScanning();
      _isMeshActive = running;
      await refreshScans();
      _startScanStreamListener();
    }
    notifyListeners();
  }

  void _startScanStreamListener() {
    _scanSubscription?.cancel();
    if (!_isAndroid) return;
    try {
      _scanSubscription = BeaconScannerService.scanStream.listen((item) {
        final index = _recentScans.indexWhere((s) => s.deviceAddress == item.deviceAddress);
        if (index >= 0) {
          _recentScans[index] = item;
        } else {
          _recentScans.insert(0, item);
          if (_recentScans.length > 60) _recentScans.removeLast();
        }
        notifyListeners();
      }, onError: (err) {
        debugPrint('BLE Scan Stream error: $err');
      });
    } catch (e) {
      debugPrint('Error subscribing to BLE scan stream: $e');
    }
  }

  Future<void> refreshScans() async {
    if (_isAndroid) {
      final scans = await BeaconScannerService.getRecentScans();
      _recentScans = scans;
      notifyListeners();
    }
  }

  Future<void> clearScans() async {
    if (_isAndroid) {
      await BeaconScannerService.clearScans();
      _recentScans.clear();
      notifyListeners();
    }
  }

  Future<bool> setServerUrl(String newUrl) async {
    String cleanUrl = newUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    _serverUrl = cleanUrl;
    await _storage.saveBaseUrl(_serverUrl);
    ApiClient().updateBaseUrl(_serverUrl);

    // If scanning was active, restart service with new URL
    if (_isMeshActive && _isAndroid) {
      await BeaconScannerService.stopScanning();
      final endpoint = _serverUrl.endsWith('/api/location')
          ? _serverUrl
          : '$_serverUrl/api/location';
      await BeaconScannerService.startScanning(
        serverUrl: endpoint,
        beaconUuid: _beaconUuid,
      );
    }
    notifyListeners();
    return true;
  }

  Future<void> toggleMeshScanner(bool enable) async {
    _isLoading = true;
    _statusMessage = null;
    notifyListeners();

    try {
      if (enable) {
        if (_isAndroid) {
          // Request necessary Android permissions
          final locationStatus = await Permission.location.request();
          final bluetoothScanStatus = await Permission.bluetoothScan.request();
          await Permission.bluetoothConnect.request();
          await Permission.notification.request();

          if (locationStatus.isDenied || bluetoothScanStatus.isDenied) {
            _statusMessage = 'Location and Bluetooth permissions are required for background mesh scanning.';
            _isLoading = false;
            notifyListeners();
            return;
          }

          final isBtOn = await BeaconScannerService.isBluetoothEnabled();
          if (!isBtOn) {
            final enabledBt = await BeaconScannerService.requestEnableBluetooth();
            if (!enabledBt) {
              _statusMessage = 'Bluetooth must be turned ON for mesh scanning.';
              _isLoading = false;
              notifyListeners();
              return;
            }
          }
        }

        final cleanUrl = _serverUrl.endsWith('/')
            ? _serverUrl.substring(0, _serverUrl.length - 1)
            : _serverUrl;
        final endpoint = cleanUrl.endsWith('/api/location')
            ? cleanUrl
            : '$cleanUrl/api/location';

        final started = await BeaconScannerService.startScanning(
          serverUrl: endpoint,
          beaconUuid: _beaconUuid,
        );

        _isMeshActive = started || !_isAndroid;
        await _storage.setMeshScannerActive(_isMeshActive);
        if (_isMeshActive) {
          _startScanStreamListener();
          _statusMessage = 'BOAT Mesh Scanner started. Passively detecting & uploading nearby BOAT bike beacons.';
        } else {
          _statusMessage = 'Could not start background scanner on this platform.';
        }
      } else {
        await BeaconScannerService.stopScanning();
        _scanSubscription?.cancel();
        _isMeshActive = false;
        await _storage.setMeshScannerActive(false);
        _statusMessage = 'BOAT Mesh Scanner stopped.';
      }
    } catch (e) {
      _statusMessage = 'Error toggling scanner: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manually tests uploading a location sighting for a scanned bike ID.
  Future<Map<String, dynamic>> uploadTestFix(String bikeId) async {
    try {
      final pos = await LocationService.getCurrentLocation();
      final lat = pos?.latitude ?? CampusConfig.defaultLat;
      final lng = pos?.longitude ?? CampusConfig.defaultLng;
      final acc = pos?.accuracy ?? 5.0;

      final res = await ApiClient().reportLocation(
        publicId: bikeId,
        tagId: bikeId,
        lat: lat,
        lng: lng,
        accuracyM: acc,
        source: 'ble',
        note: 'Manual test from Mesh Diagnostics for bike: $bikeId',
      );

      // Update in local recent scans
      final index = _recentScans.indexWhere((s) => s.bikeId == bikeId);
      if (index >= 0) {
        final current = _recentScans[index];
        _recentScans[index] = BleScanResultModel(
          deviceName: current.deviceName,
          deviceAddress: current.deviceAddress,
          rssi: current.rssi,
          rawHex: current.rawHex,
          bikeId: current.bikeId,
          isBoat: current.isBoat,
          timestamp: current.timestamp,
          uploadStatus: 'Uploaded (HTTP 200 OK)',
          lastUploadedAt: DateTime.now(),
        );
        notifyListeners();
      }

      return {'ok': true, 'response': res};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}
