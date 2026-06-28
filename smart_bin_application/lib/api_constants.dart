class ApiConstants {
  static const String baseUrl = 'http://10.182.241.14:8000/api';
  static const String mediaUrl = 'http://10.182.241.14:8000';
  static String get wsUrl {
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$wsScheme://${uri.host}:${uri.port}/ws/map/';
  }
}