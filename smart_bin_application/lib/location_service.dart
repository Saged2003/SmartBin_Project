import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:easy_localization/easy_localization.dart';

class LocationService {
  static Future<Position?> determinePosition(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        await _showDialog(
          context,
          'location_disabled'.tr(),
          'enable_location_services'.tr(),
          () async {
            Navigator.of(context).pop();
            await Geolocator.openLocationSettings();
          },
        );
      }
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('location_permissions_denied'.tr())),
          );
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        await _showDialog(
          context,
          'location_permissions_denied_title'.tr(),
          'location_permanently_denied'.tr(),
          () async {
            Navigator.of(context).pop();
            await Geolocator.openAppSettings();
          },
        );
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('location_timeout'.tr())),
        );
      }
      return null;
    }
  }

  static Future<void> _showDialog(BuildContext context, String title, String content, VoidCallback onConfirm) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(content),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          actions: <Widget>[
            TextButton(
              child: Text('cancel'.tr(), style: const TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              onPressed: onConfirm,
              child: Text('open_settings'.tr(), style: const TextStyle(color: Color(0xFF0D6B58), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
