import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import '../services/storage_service.dart';
import 'auth_interceptor.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;
  final StorageService _storageService = StorageService();

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: _storageService.getBaseUrl(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(AuthInterceptor());
  }

  void updateBaseUrl(String newUrl) {
    dio.options.baseUrl = newUrl;
  }

  // --- Health API ---
  Future<Map<String, dynamic>> checkHealth() async {
    final res = await dio.get('/api/health');
    return res.data as Map<String, dynamic>;
  }

  // --- Auth APIs ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await dio.post(ApiEndpoints.login, data: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
    String? hostel,
    String? room,
  }) async {
    final res = await dio.post(ApiEndpoints.register, data: {
      'email': email.trim().toLowerCase(),
      'password': password,
      'displayName': displayName.trim(),
      if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
      if (hostel != null && hostel.isNotEmpty) 'hostel': hostel.trim(),
      if (room != null && room.isNotEmpty) 'room': room.trim(),
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await dio.get(ApiEndpoints.me);
    return res.data as Map<String, dynamic>;
  }

  // --- Bikes APIs ---
  Future<List<dynamic>> getBikes() async {
    final res = await dio.get(ApiEndpoints.bikes);
    return res.data['bikes'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getBikeDetail(dynamic id) async {
    final res = await dio.get(ApiEndpoints.bikeDetail(id));
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> registerBike({
    required String name,
    String? color,
    String? model,
  }) async {
    final res = await dio.post(ApiEndpoints.bikes, data: {
      'name': name.trim(),
      if (color != null && color.isNotEmpty) 'color': color.trim(),
      if (model != null && model.isNotEmpty) 'model': model.trim(),
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateBikeStatus(
    dynamic id,
    String status, {
    String? notes,
  }) async {
    final res = await dio.patch(ApiEndpoints.bikeDetail(id), data: {
      'status': status,
      if (notes != null && notes.isNotEmpty) 'notes': notes.trim(),
    });
    return res.data as Map<String, dynamic>;
  }

  // --- Location Report APIs ---
  Future<Map<String, dynamic>> reportLocation({
    String? publicId,
    String? tagId,
    String? beaconUuid,
    int? beaconMajor,
    int? beaconMinor,
    required double lat,
    required double lng,
    double? accuracyM,
    String source = 'manual',
    String? note,
  }) async {
    final Map<String, dynamic> body = {
      'lat': lat,
      'lng': lng,
      'source': source,
      'accuracyM': ?accuracyM,
      if (note != null && note.isNotEmpty) 'note': note,
      if (publicId != null && publicId.isNotEmpty) 'publicId': publicId,
      if (tagId != null && tagId.isNotEmpty) 'tagId': tagId,
      if (beaconUuid != null) ...{
        'beaconUuid': beaconUuid,
        'beaconMajor': beaconMajor ?? 1,
        'beaconMinor': ?beaconMinor,
      },
    };

    final res = await dio.post(ApiEndpoints.location, data: body);
    return res.data as Map<String, dynamic>;
  }

  // --- Public APIs ---
  Future<Map<String, dynamic>> getPublicBike(String publicId) async {
    final res = await dio.get(ApiEndpoints.publicBike(publicId));
    return res.data as Map<String, dynamic>;
  }
}
