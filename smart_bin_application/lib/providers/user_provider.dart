import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../api_constants.dart';
import '../navigator_service.dart';
import '../location_service.dart';
import '../api_service.dart';

class UserProvider extends ChangeNotifier {
  UserProvider() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      isOffline = result == ConnectivityResult.none;
      notifyListeners();
    });
  }
  String userName = "User";
  String fullName = "";
  String email = "";
  String phone = "";
  String address = "";
  String? profilePicUrl;
  int currentBalance = 0;

  double totalWeight = 0.0;
  double co2Saved = 0.0;
  int deposits = 0;
  bool isEmployee = false;
  bool isApprovedEmployee = false;
  bool isRootAdmin = false;
  bool isOffline = false;
  bool isLoading = false;
  List<dynamic> recentActivities = [];
  int currentPage = 1;
  bool hasMoreActivities = true;

  WebSocket? _userSocket;
  final StreamController<Map<String, dynamic>> _userStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get userStream => _userStreamController.stream;

  @override
  void dispose() {
    _userSocket?.close();
    _userStreamController.close();
    super.dispose();
  }

  Future<void> _connectUserWebSocket() async {
    if (userName == "User" || userName.isEmpty) return;
    try {
      _userSocket?.close();
      _userSocket = await WebSocket.connect(ApiConstants.userWsUrl(userName)).timeout(const Duration(seconds: 5));
      _userSocket!.listen((message) {
        final data = jsonDecode(message);
        if (data['type'] == 'user_update') {
          final payload = data['message'];
          currentBalance = payload['points'] ?? currentBalance;
          co2Saved = (payload['co2_saved'] ?? co2Saved).toDouble();
          totalWeight = (payload['weight'] ?? totalWeight).toDouble();
          deposits = payload['deposits'] ?? deposits;
          
          _userStreamController.add({
            'points': currentBalance,
            'points_added': payload['points_added'] ?? 0,
            'co2_saved': co2Saved,
            'weight': totalWeight,
            'deposits': deposits
          });
          notifyListeners();
        }
      }, onDone: () {
        Future.delayed(const Duration(seconds: 5), _connectUserWebSocket);
      }, onError: (e) {
        Future.delayed(const Duration(seconds: 5), _connectUserWebSocket);
      });
    } catch (_) {
      Future.delayed(const Duration(seconds: 5), _connectUserWebSocket);
    }
  }

  void reset() {
    userName = "User";
    fullName = "";
    email = "";
    phone = "";
    address = "";
    profilePicUrl = null;
    currentBalance = 0;

    totalWeight = 0.0;
    co2Saved = 0.0;
    deposits = 0;
    isEmployee = false;
    isApprovedEmployee = false;
    isRootAdmin = false;
    recentActivities = [];
    currentPage = 1;
    hasMoreActivities = true;
    notifyListeners();
  }

  String? get fullProfilePicUrl {
    if (profilePicUrl == null || profilePicUrl!.isEmpty) return null;
    String url = profilePicUrl!;
    if (!url.startsWith('http')) {
      url = url.startsWith('/')
          ? '${ApiConstants.mediaUrl}$url'
          : '${ApiConstants.mediaUrl}/$url';
    }
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<bool> _checkActualConnectivity() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  void _handleUnauthorized() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    try {
      await Hive.deleteBoxFromDisk('offline_data');
      var box = await Hive.openBox('offline_data');
      await box.clear();
    } catch (_) {}
    _userSocket?.close();
    NavigatorService.forceLogout();
  }

  Future<void> loadLocalData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userName = prefs.getString('username') ?? "User";
    fullName = prefs.getString('full_name') ?? "";
    email = prefs.getString('email') ?? "";
    phone = prefs.getString('phone') ?? "";
    address = prefs.getString('address') ?? "";
    profilePicUrl = prefs.getString('profile_picture');
    currentBalance = prefs.getInt('points') ?? 0;

    totalWeight = prefs.getDouble('weight') ?? 0.0;
    co2Saved = prefs.getDouble('co2_saved') ?? 0.0;
    deposits = prefs.getInt('deposits') ?? 0;
    isEmployee = prefs.getBool('is_employee') ?? false;
    isApprovedEmployee = prefs.getBool('is_approved_employee') ?? false;
    isRootAdmin = prefs.getBool('is_root_admin') ?? false;

    var box = Hive.box('offline_data');
    String? cachedActivities = box.get('cached_recent_activities');
    if (cachedActivities != null) {
      recentActivities = jsonDecode(cachedActivities);
    }
    notifyListeners();
  }

  Future<void> fetchProfileData() async {
    bool connectionActive = await _checkActualConnectivity();
    if (!connectionActive) {
      isOffline = true;
      notifyListeners();
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? user = prefs.getString('username');
    String? token = prefs.getString('token');
    if (user == null || token == null) return;
    try {
      var response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/profile/?username=$user'),
        headers: {"Authorization": "Token $token"},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 401) {
        _handleUnauthorized();
        return;
      }
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        userName = user;
        currentBalance = data['points'] ?? 0;

        totalWeight = (data['weight'] ?? 0.0).toDouble();
        co2Saved = (data['co2_saved'] ?? 0.0).toDouble();
        deposits = data['deposits'] ?? 0;
        fullName = data['full_name'] ?? "";
        email = data['email'] ?? "";
        phone = data['phone'] ?? "";
        address = data['address'] ?? "";
        profilePicUrl = data['profile_picture'];
        isEmployee = data['is_employee'] ?? false;
        isApprovedEmployee = data['is_approved_employee'] ?? false;
        isRootAdmin = data['is_root_admin'] ?? false;
        isOffline = false;

        await prefs.setInt('points', currentBalance);

        await prefs.setDouble('weight', totalWeight);
        await prefs.setDouble('co2_saved', co2Saved);
        await prefs.setInt('deposits', deposits);
        await prefs.setString('full_name', fullName);
        await prefs.setString('email', email);
        await prefs.setString('phone', phone);
        await prefs.setString('address', address);
        await prefs.setBool('is_employee', isEmployee);
        await prefs.setBool('is_approved_employee', isApprovedEmployee);
        await prefs.setBool('is_root_admin', isRootAdmin);
        if (profilePicUrl != null) await prefs.setString('profile_picture', profilePicUrl!);
        
        _connectUserWebSocket();
      }
      isOffline = false;
    } catch (_) {
      isOffline = !(await _checkActualConnectivity());
    }
    notifyListeners();
  }

  Future<void> fetchActivities({bool loadMore = false, DateTime? startDate, DateTime? endDate}) async {
    if (loadMore && !hasMoreActivities) return;
    if (isLoading) return;
    isLoading = true;
    if (!loadMore) currentPage = 1;
    notifyListeners();

    bool connectionActive = await _checkActualConnectivity();
    if (!connectionActive) {
      isOffline = true;
      isLoading = false;
      notifyListeners();
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? user = prefs.getString('username');
    String? token = prefs.getString('token');
    if (user == null || token == null) {
      isLoading = false;
      notifyListeners();
      return;
    }
    try {
      String url = '${ApiConstants.baseUrl}/activities/?username=$user&page=$currentPage&limit=10';
      if (startDate != null) url += '&start_date=${startDate.toIso8601String()}';
      if (endDate != null) url += '&end_date=${endDate.toIso8601String()}';
      
      var response = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Token $token"},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 401) {
        _handleUnauthorized();
        return;
      }
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        List activitiesList = data is Map ? data['data'] : data;
        if (loadMore) {
          recentActivities.addAll(activitiesList);
        } else {
          recentActivities = activitiesList.toList();
        }
        hasMoreActivities = activitiesList.length == 10;
        if (hasMoreActivities) currentPage++;
        var box = Hive.box('offline_data');
        await box.put('cached_recent_activities', jsonEncode(recentActivities.take(10).toList()));
        isOffline = false;
      }
    } catch (_) {
      isOffline = !(await _checkActualConnectivity());
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> scanQR(String code) async {
    bool connectionActive = await _checkActualConnectivity();
    if (!connectionActive) {
      isOffline = true;
      notifyListeners();
      return false;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token == null) return false;
    try {
      var response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/user/scan-qr/'),
        headers: {"Content-Type": "application/json", "Authorization": "Token $token"},
        body: jsonEncode({"code": code}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 401) {
        _handleUnauthorized();
        return false;
      }
      if (response.statusCode == 200) return true;
    } catch (_) {
      return false;
    }
    return false;
  }

  Future<Map<String, dynamic>> updateProfile(String name, String email, String phone, String address, File? image) async {
    isLoading = true;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? username = prefs.getString('username');
    try {
      var uri = Uri.parse('${ApiConstants.baseUrl}/update-profile/');
      
      Map<String, String> modifiedFields = {};
      if (name != fullName) modifiedFields['full_name'] = name;
      if (email != this.email) modifiedFields['email'] = email;
      if (phone != this.phone) modifiedFields['phone'] = phone;
      if (address != this.address) modifiedFields['address'] = address;
      modifiedFields['username'] = username ?? '';

      int statusCode = 0;
      String respBody = "";

      if (image != null) {
        var request = http.MultipartRequest('PATCH', uri);
        request.headers.addAll({"Authorization": "Token $token"});
        modifiedFields.forEach((key, value) {
          request.fields[key] = value;
        });
        request.files.add(await http.MultipartFile.fromPath(
          'profile_picture',
          image.path,
          contentType: MediaType('image', 'jpeg'),
        ));
        var streamedResponse = await request.send().timeout(const Duration(seconds: 15));
        statusCode = streamedResponse.statusCode;
        respBody = await streamedResponse.stream.bytesToString();
      } else {
        var response = await http.patch(
          uri,
          headers: {"Authorization": "Token $token", "Content-Type": "application/json"},
          body: jsonEncode(modifiedFields),
        ).timeout(const Duration(seconds: 15));
        statusCode = response.statusCode;
        respBody = response.body;
      }

      if (statusCode == 401) {
        _handleUnauthorized();
        return {'success': false, 'error': 'unauthorized'};
      }
      if (statusCode == 200) {
        var data = jsonDecode(respBody);
        if (modifiedFields.containsKey('full_name')) {
          fullName = name;
          await prefs.setString('full_name', name);
        }
        if (modifiedFields.containsKey('email')) {
          this.email = email;
          await prefs.setString('email', email);
        }
        if (modifiedFields.containsKey('phone')) {
          this.phone = phone;
          await prefs.setString('phone', phone);
        }
        if (modifiedFields.containsKey('address')) {
          this.address = address;
          await prefs.setString('address', address);
        }
        if (data['profile_picture'] != null) {
          profilePicUrl = data['profile_picture'];
          await prefs.setString('profile_picture', profilePicUrl!);
        }
        notifyListeners();
        await fetchProfileData();
        return {'success': true};
      }
    } catch (_) {
      return {'success': false, 'error': 'network'};
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return {'success': false, 'error': 'failed'};
  }

  Future<Map<String, dynamic>> employeeUpdateLocation(String binId, double lat, double lng, {String? name}) async {
    isLoading = true;
    notifyListeners();
    try {
      var result = await ApiService().employeeUpdateLocation(binId, lat, lng, name: name);
      return {'success': true, 'data': result};
    } catch (e) {
      if (e.toString().contains('unauthorized')) {
        _handleUnauthorized();
        return {'success': false, 'error': 'unauthorized'};
      }
      return {'success': false, 'error': 'network'};
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Position?> useCurrentLocation(BuildContext context) async {
    isLoading = true;
    notifyListeners();
    try {
      return await LocationService.determinePosition(context);
    } catch (_) {
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

}