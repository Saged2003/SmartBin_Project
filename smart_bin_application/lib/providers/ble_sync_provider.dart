import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_constants.dart';

class BleSyncProvider extends ChangeNotifier {
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  bool isScanning = false;
  bool isSyncing = false;

  Future<void> syncOfflineData() async {
    if (isScanning || isSyncing) return;

    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult != ConnectivityResult.none) {
      await _pushHiveDataToDjango();
    }

    if (connectivityResult == ConnectivityResult.none) {
      _scanAndPullBleData();
    }
  }

  Future<void> _pushHiveDataToDjango() async {
    isSyncing = true;
    notifyListeners();

    var box = Hive.box('offline_data');
    List<dynamic> pendingData = box.get('pending_sync', defaultValue: []);

    if (pendingData.isEmpty) {
      isSyncing = false;
      notifyListeners();
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    List<dynamic> failedData = [];

    for (var payload in pendingData) {
      try {
        String endpoint = '/esp/end-session/';
        if (payload is Map && payload.containsKey('capacity')) {
          endpoint = '/esp/update-capacity/';
        }
        var response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
          headers: {
            "Content-Type": "application/json",
            if (token != null) "Authorization": "Token $token",
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          failedData.add(payload);
        }
      } catch (e) {
        failedData.add(payload);
      }
    }

    await box.put('pending_sync', failedData);
    isSyncing = false;
    notifyListeners();
  }

  void _scanAndPullBleData() async {
    isScanning = true;
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5), withServices: [Guid(serviceUuid)]);

      FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          if (r.device.remoteId.str.isNotEmpty) {
            await FlutterBluePlus.stopScan();
            await _connectAndPull(r.device);
            break;
          }
        }
      });
    } catch (e) {
      isScanning = false;
      notifyListeners();
      return;
    }

    isScanning = false;
    notifyListeners();
  }

  Future<void> _connectAndPull(BluetoothDevice device) async {
    try {
      await device.connect(license: License.nonprofit);
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          for (BluetoothCharacteristic c in service.characteristics) {
            if (c.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
              List<int> value = await c.read();
              String data = utf8.decode(value);

              if (data != "[]" && data.isNotEmpty) {
                try {
                  List<dynamic> parsedData = jsonDecode(data);
                  String binId = device.advName;
                  if (binId.isEmpty) {
                    binId = device.platformName;
                  }
                  for (var item in parsedData) {
                    if (item is Map) {
                      item['bin_id'] = binId;
                    }
                  }
                  var box = Hive.box('offline_data');
                  List<dynamic> pendingData = box.get('pending_sync', defaultValue: []);
                  pendingData.addAll(parsedData);
                  await box.put('pending_sync', pendingData);

                  await c.write(utf8.encode("CLEAR"));
                } catch (e) {
                  return;
                }
              }
            }
          }
        }
      }
    } finally {
      await device.disconnect();
    }
  }
}
