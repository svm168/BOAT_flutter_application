import 'package:dio/dio.dart';
import '../services/storage_service.dart';

class AuthInterceptor extends Interceptor {
  final StorageService _storageService = StorageService();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    options.baseUrl = _storageService.getBaseUrl();
    final token = await _storageService.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired or invalid
      _storageService.clearToken();
    }
    return handler.next(err);
  }
}
