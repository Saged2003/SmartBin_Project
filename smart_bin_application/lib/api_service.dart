import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'api_constants.dart';
import 'navigator_service.dart';

class ApiService {
  late Dio _dio;
  static bool _isLoggingOut = false;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Token $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 404) {
          await _handleSessionExpired();
        }
        return handler.next(e);
      },
    ));
  }

  Future<void> _handleSessionExpired() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      try {
        await Hive.deleteBoxFromDisk('offline_data');
        var box = await Hive.openBox('offline_data');
        await box.clear();
      } catch (_) {}
      NavigatorService.forceLogout();
    } finally {
      _isLoggingOut = false;
    }
  }

  Future<void> validateSession() async {
    try {
      await _dio.get('/validate-session/');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post('/login/', data: {'username': username, 'password': password});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', response.data['token']);
      await prefs.setString('username', response.data['username']);
      await prefs.setBool('is_employee', response.data['is_employee']);
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Login failed');
    }
  }

  Future<Map<String, dynamic>> register(String username, String password, String email, bool isEmployee) async {
    try {
      final response = await _dio.post('/register/', data: {
        'username': username,
        'password': password,
        'email': email,
        'is_employee': isEmployee,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', response.data['token']);
      await prefs.setString('username', response.data['username']);
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Registration failed');
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      final response = await _dio.get('/profile/', queryParameters: {'username': username});
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Failed to load profile');
    }
  }

  Future<List<dynamic>> getBins(double lat, double lng) async {
    try {
      final response = await _dio.get('/bins/', queryParameters: {'lat': lat, 'lng': lng});
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Failed to load bins');
    }
  }

  Future<Map<String, dynamic>> getRewards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      final response = await _dio.get('/rewards/', queryParameters: {'username': username});
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Failed to load rewards');
    }
  }

  Future<Map<String, dynamic>> redeemReward(int rewardId, double originalPrice) async {
    try {
      final response = await _dio.post('/redeem-reward/', data: {
        'reward_id': rewardId,
        'original_price': originalPrice,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Failed to redeem reward');
    }
  }

  Future<Map<String, dynamic>> scanQr(String code) async {
    try {
      final response = await _dio.post('/user/scan-qr/', data: {'code': code});
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Failed to scan QR');
    }
  }

  Future<void> updateFcmToken(String fcmToken) async {
    try {
      await _dio.post('/update-fcm-token/', data: {'fcm_token': fcmToken});
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Failed to update FCM token');
    }
  }
}