import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';

class OfflineBleSyncService {
  final ApiService _apiService = ApiService();

  Future<void> syncDataFromDevice(BluetoothDevice device, String hardwareToken) async {
    try {
      await device.connect(license: '');
      final services = await device.discoverServices();
      
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.read) {
            final value = await characteristic.read();
            if (value.isNotEmpty) {
              final payloadString = utf8.decode(value);
              final payload = jsonDecode(payloadString);
              
              if (payload is Map && payload.containsKey('data') && payload.containsKey('signature')) {
                final dataList = payload['data'];
                final signature = payload['signature'];

                await _apiService.syncBleOffline(device.name, dataList, signature);
                
                if (characteristic.properties.write) {
                  await characteristic.write(utf8.encode('CLEAR'));
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('BLE Sync Error: $e');
    } finally {
      await device.disconnect();
    }
  }

  static void initializeBackgroundSync() {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    Workmanager().registerPeriodicTask(
      "1",
      "bleOfflineSyncTask",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final service = OfflineBleSyncService();
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      await Future.delayed(const Duration(seconds: 4));
      FlutterBluePlus.stopScan();

      final devices = FlutterBluePlus.connectedDevices;
      for (var device in devices) {
        await service.syncDataFromDevice(device, 'secret-token-123');
      }
    } catch (_) {}
    return Future.value(true);
  });
}
