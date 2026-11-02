import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_endpoints.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  static const String _keyToken = 'jwt_token';
  static const String _keyBaseUrl = 'base_url';
  static const String _keyMeshScannerActive = 'mesh_scanner_active';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token management
  Future<void> saveToken(String token) async {
    try {
      await _secureStorage.write(key: _keyToken, value: token);
    } catch (_) {}
    await _prefs?.setString(_keyToken, token);
  }

  Future<String?> getToken() async {
    try {
      final secure = await _secureStorage.read(key: _keyToken);
      if (secure != null && secure.isNotEmpty) return secure;
    } catch (_) {}
    return _prefs?.getString(_keyToken);
  }

  Future<void> clearToken() async {
    try {
      await _secureStorage.delete(key: _keyToken);
    } catch (_) {}
    await _prefs?.remove(_keyToken);
  }

  // Base URL configuration
  Future<void> saveBaseUrl(String url) async {
    await _prefs?.setString(_keyBaseUrl, url);
  }

  String getBaseUrl() {
    return ApiEndpoints.defaultBaseUrl;
  }

  // Mesh scanner persistence
  Future<void> setMeshScannerActive(bool active) async {
    await _prefs?.setBool(_keyMeshScannerActive, active);
  }

  bool isMeshScannerActive() {
    return _prefs?.getBool(_keyMeshScannerActive) ?? false;
  }
}
