class ApiEndpoints {
  static const String defaultBaseUrl = 'https://boat-eight-lemon.vercel.app';

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
