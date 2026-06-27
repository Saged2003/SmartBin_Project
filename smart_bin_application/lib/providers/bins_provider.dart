import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../api_constants.dart';
import '../navigator_service.dart';
import '../location_service.dart';

class BinsProvider extends ChangeNotifier {
  List<dynamic> bins = [];
  bool isLoading = true;
  bool isOffline = false;
  String currentLocationName = "fetching_location".tr();
  double currentLat = 31.2653;
  double currentLng = 32.3019;

  void reset() {
    bins = [];
    isLoading = false;
    isOffline = false;
    currentLocationName = "fetching_location".tr();
    currentLat = 31.2653;
    currentLng = 32.3019;
    notifyListeners();
  }

  Future<void> loadCachedBins() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedBins = prefs.getString('cached_bins');
    if (cachedBins != null) {
      bins = jsonDecode(cachedBins);
      notifyListeners();
    }
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

  Future<void> getCurrentLocation(BuildContext context) async {
    isLoading = true;
    notifyListeners();

    bool connectionActive = await _checkActualConnectivity();
    if (!connectionActive) {
      isOffline = true;
      isLoading = false;
      await loadCachedBins();
      notifyListeners();
      return;
    }

    Position? position = await LocationService.determinePosition(context);
    if (position != null) {
      try {
        currentLat = position.latitude;
        currentLng = position.longitude;

        List<Placemark> placemarks = await placemarkFromCoordinates(currentLat, currentLng);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          currentLocationName = "${place.locality ?? 'unknown'.tr()}, ${place.subAdministrativeArea ?? ''}";
        }
      } catch (_) {
        currentLocationName = "current_location".tr();
      }
    } else {
      currentLocationName = "location_denied_disabled".tr();
    }

    await fetchBins(currentLat, currentLng);
  }

  void _sortBinsByProximity() {
    for (var b in bins) {
      if (b['lat'] != null && b['lng'] != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          currentLat,
          currentLng,
          (b['lat'] as num).toDouble(),
          (b['lng'] as num).toDouble(),
        );
        b['distance_km'] = distanceInMeters / 1000.0;
      } else {
        b['distance_km'] = double.infinity;
      }
    }
    bins.sort((a, b) => (a['distance_km'] as double).compareTo(b['distance_km'] as double));
  }

  Future<void> fetchBins(double lat, double lng) async {
    bool connectionActive = await _checkActualConnectivity();
    if (!connectionActive) {
      isOffline = true;
      isLoading = false;
      await loadCachedBins();
      _sortBinsByProximity();
      notifyListeners();
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      var response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/bins/?lat=$lat&lng=$lng'),
        headers: {
          if (token != null) "Authorization": "Token $token",
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        _handleUnauthorized();
        return;
      }
      if (response.statusCode == 200) {
        prefs.setString('cached_bins', response.body);
        bins = jsonDecode(response.body);
        isOffline = false;
        _sortBinsByProximity();
      }
    } catch (_) {
      isOffline = !(await _checkActualConnectivity());
      if (isOffline) {
        await loadCachedBins();
        _sortBinsByProximity();
      }
    }
    isLoading = false;
    notifyListeners();
  }

  void updateManualLocation(double lat, double lng) {
    currentLat = lat;
    currentLng = lng;
    currentLocationName = "custom_location".tr();
    fetchBins(currentLat, currentLng);
  }
}