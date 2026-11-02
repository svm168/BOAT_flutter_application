import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../models/bike.dart';
import '../models/location_report.dart';

class BikeProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<Bike> _bikes = [];
  Bike? _selectedBike;
  bool _isLoading = false;
  String? _errorMessage;

  List<Bike> get bikes => _bikes;
  Bike? get selectedBike => _selectedBike;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchBikes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getBikes();
      _bikes = data.map((json) => Bike.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      _errorMessage = _parseError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBikeDetail(dynamic id, {bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final res = await _api.getBikeDetail(id);
      final bikeData = res['bike'] as Map<String, dynamic>;
      final lastLocData = res['lastLocation'] as Map<String, dynamic>?;
      final trailData = res['trail'] as List<dynamic>?;
      final missingReportData = res['activeMissingReport'] as Map<String, dynamic>?;

      final lastLocation = lastLocData != null ? LocationReport.fromJson(lastLocData) : null;
      final trail = trailData?.map((l) => LocationReport.fromJson(l as Map<String, dynamic>)).toList();
      final activeMissing = missingReportData != null ? MissingReport.fromJson(missingReportData) : null;

      _selectedBike = Bike.fromJson(
        bikeData,
        lastLocation: lastLocation,
        trail: trail,
        activeMissingReport: activeMissing,
      );
    } catch (e) {
      if (!silent) {
        _errorMessage = _parseError(e);
      }
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<bool> registerBike({
    required String name,
    String? color,
    String? model,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.registerBike(name: name, color: color, model: model);
      await fetchBikes();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBikeStatus(
    dynamic id,
    String status, {
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.updateBikeStatus(id, status, notes: notes);
      // Refresh details
      await fetchBikeDetail(id);
      await fetchBikes();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> reportLocation({
    required String publicId,
    required double lat,
    required double lng,
    double? accuracyM,
    String source = 'manual',
    String? note,
  }) async {
    try {
      await _api.reportLocation(
        publicId: publicId,
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        source: source,
        note: note,
      );
      if (_selectedBike != null && _selectedBike!.publicId == publicId) {
        await fetchBikeDetail(_selectedBike!.id);
      }
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  String _parseError(dynamic e) {
    if (e is Exception) {
      try {
        final dynamic dioErr = e;
        if (dioErr.response?.data != null && dioErr.response?.data['error'] != null) {
          return dioErr.response.data['error'].toString();
        }
        if (dioErr.message != null) {
          return dioErr.message.toString();
        }
      } catch (_) {}
    }
    return e.toString();
  }
}
