import 'package:flutter/foundation.dart';
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
    final saved = _prefs?.getString(_keyBaseUrl);
    if (saved != null && saved.isNotEmpty) {
      // In web browser (Chrome), 10.0.2.2 is unroutable. Auto-migrate to localhost:3000
      if (kIsWeb && saved.contains('10.0.2.2')) {
        return 'http://localhost:3000';
      }
      // On Android emulator, localhost is unroutable to host PC. Auto-migrate to 10.0.2.2:3000
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && saved.contains('localhost:3000')) {
        return 'http://10.0.2.2:3000';
      }
      return saved;
    }
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
