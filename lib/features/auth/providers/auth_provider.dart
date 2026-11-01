import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final StorageService _storage = StorageService();

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _initialized = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get initialized => _initialized;

  Future<void> initAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storage.getToken();
      if (token != null && token.isNotEmpty) {
        final res = await _api.getMe();
        if (res['user'] != null) {
          _currentUser = User.fromJson(res['user']);
        }
      }
    } catch (e) {
      // Token might be expired or invalid
      await _storage.clearToken();
      _currentUser = null;
    } finally {
      _isLoading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.login(email, password);
      if (res['token'] != null) {
        await _storage.saveToken(res['token']);
        if (res['user'] != null) {
          _currentUser = User.fromJson(res['user']);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid response from server.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
    String? hostel,
    String? room,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.register(
        email: email,
        password: password,
        displayName: displayName,
        phone: phone,
        hostel: hostel,
        room: room,
      );
      if (res['token'] != null) {
        await _storage.saveToken(res['token']);
        if (res['user'] != null) {
          _currentUser = User.fromJson(res['user']);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Registration succeeded, but token missing.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearToken();
    _currentUser = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
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
