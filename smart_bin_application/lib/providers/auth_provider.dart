import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api_constants.dart';


class AuthProvider extends ChangeNotifier {
  bool isLoading = false;


  Future<bool> login(String email, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      String username = email.split('@')[0];
      var response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/login/'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('username', username);
        await prefs.setInt('points', data['points'] ?? 0);
        await prefs.setBool('is_employee', data['is_employee'] ?? false);
        await prefs.setBool('is_approved_employee', data['is_approved_employee'] ?? false);
        await prefs.setBool('is_root_admin', data['is_root_admin'] ?? false);
        isLoading = false;
        notifyListeners();
        return true;
      }
      if (response.statusCode == 429) {
        isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (_) {}
    isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> signUp(String email, String password, bool isEmployee) async {
    isLoading = true;
    notifyListeners();
    try {
      String username = email.split('@')[0];
      var response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/register/'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "email": email, "password": password, "is_employee": isEmployee}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 || response.statusCode == 201) {
        var data = jsonDecode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('username', username);
        await prefs.setInt('points', 0);
        await prefs.setDouble('weight', 0.0);
        await prefs.setInt('deposits', 0);
        await prefs.setBool('is_employee', isEmployee);
        await prefs.setBool('is_approved_employee', false);
        await prefs.setBool('is_root_admin', false);
        isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    try {
      await Hive.deleteBoxFromDisk('offline_data');
      var box = await Hive.openBox('offline_data');
      await box.clear();
    } catch (_) {}
    notifyListeners();
  }
}