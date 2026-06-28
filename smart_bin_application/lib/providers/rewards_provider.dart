import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../api_constants.dart';
import '../navigator_service.dart';

class RewardsProvider extends ChangeNotifier {
  int userPoints = 0;
  int milestonePoints = 0;
  int nextMilestone = 1000;
  int pointsLeft = 1000;
  bool premiumUnlocked = false;
  List<dynamic> rewards = [];
  bool isLoading = true;
  bool isOffline = false;
  String selectedCategory = 'all';

  void setCategory(String category) {
    selectedCategory = category;
    notifyListeners();
  }

  void reset() {
    userPoints = 0;
    milestonePoints = 0;
    nextMilestone = 1000;
    pointsLeft = 1000;
    premiumUnlocked = false;
    rewards = [];
    isLoading = false;
    isOffline = false;
    selectedCategory = 'all';
    notifyListeners();
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
    NavigatorService.forceLogout();
  }

  Future<void> fetchData() async {
    isLoading = true;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String username = prefs.getString('username') ?? "";
    String? token = prefs.getString('token');

    String? cachedRewards = prefs.getString('cached_rewards');
    if (cachedRewards != null) {
      var data = jsonDecode(cachedRewards);
      rewards = data['rewards'] ?? [];
      userPoints = data['user_points'] ?? prefs.getInt('points') ?? 0;
      milestonePoints = data['milestone_points'] ?? 0;
      nextMilestone = data['next_milestone'] ?? 1000;
      pointsLeft = data['points_left'] ?? 1000;
      premiumUnlocked = data['premium_unlocked'] ?? false;
    }

    bool connectionActive = await _checkActualConnectivity();
    if (!connectionActive) {
      isOffline = true;
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      var response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/rewards/?username=$username'),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Token $token",
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        _handleUnauthorized();
        return;
      }
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        prefs.setString('cached_rewards', response.body);
        rewards = data['rewards'] ?? [];
        userPoints = data['user_points'] ?? 0;
        milestonePoints = data['milestone_points'] ?? 0;
        nextMilestone = data['next_milestone'] ?? 1000;
        pointsLeft = data['points_left'] ?? 1000;
        premiumUnlocked = data['premium_unlocked'] ?? false;
        isOffline = false;
        await prefs.setInt('points', userPoints);
      }
    } catch (_) {
      isOffline = !(await _checkActualConnectivity());
    }
    isLoading = false;
    notifyListeners();
  }

  Future<String?> redeemReward(int rewardId, int cost) async {
    bool connectionActive = await _checkActualConnectivity();
    if (!connectionActive) {
      isOffline = true;
      notifyListeners();
      return null;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      var response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/redeem-reward/'),
        headers: {"Content-Type": "application/json", "Authorization": "Token $token"},
        body: jsonEncode({"reward_id": rewardId, "original_price": cost}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        _handleUnauthorized();
        return null;
      }
      if (response.statusCode == 200) {
        var respData = jsonDecode(response.body);
        userPoints = respData['new_points'] ?? userPoints;
        await prefs.setInt('points', userPoints);
        await fetchData();
        return respData['promo_code'];
      }
    } catch (_) {
      isOffline = !(await _checkActualConnectivity());
    }
    await fetchData();
    return null;
  }

  Future<List<dynamic>> fetchRedemptionHistory() async {
    bool connectionActive = await _checkActualConnectivity();
    if (!connectionActive) {
      return [];
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      var response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/redemption-history/'),
        headers: {"Content-Type": "application/json", "Authorization": "Token $token"},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        _handleUnauthorized();
        return [];
      }
      if (response.statusCode == 200) {
        var respData = jsonDecode(response.body);
        return respData['history'] ?? [];
      }
    } catch (_) {}
    return [];
  }
}