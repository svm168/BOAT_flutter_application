import 'package:flutter/foundation.dart';

class ApiEndpoints {
  // Automatically choose localhost for Web and desktop, 10.0.2.2 for Android emulator
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://localhost:3000';
  }

  // Auth
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String me = '/api/auth/me';
  static const String logout = '/api/auth/logout';

  // Bikes
  static const String bikes = '/api/bikes';
  static String bikeDetail(dynamic id) => '/api/bikes/$id';

  // Location Sighting
  static const String location = '/api/location';

  // Public
  static String publicBike(String publicId) => '/api/public/bikes/$publicId';
}
