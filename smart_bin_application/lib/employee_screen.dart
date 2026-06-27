import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'providers/user_provider.dart';
import 'providers/ble_sync_provider.dart';
import 'animated_button.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});
  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  final TextEditingController binIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _updateLocation() async {
    if (binIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('fill_all_fields'.tr())));
      return;
    }
    final userProvider = context.read<UserProvider>();
    final position = await userProvider.useCurrentLocation(context);
    if (position == null) return;

    final result = await userProvider.employeeUpdateLocation(
      binIdController.text,
      position.latitude,
      position.longitude,
    );
    if (result['success'] && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('location_updated'.tr()), backgroundColor: Colors.green));
      Navigator.pop(context);
    } else if (mounted) {
      if (result['error'] == 'network') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('network_error'.tr()), backgroundColor: Colors.orange));
      } else if (result['error'] != 'unauthorized') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('update_failed'.tr()), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _syncViaBLE() async {
    final bleProvider = context.read<BleSyncProvider>();
    await bleProvider.syncOfflineData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('sync_ble'.tr()), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.surfaceContainerHighest;
    final textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black;
    final bgColor = theme.scaffoldBackgroundColor;

    final isLoading = context.watch<UserProvider>().isLoading;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('employee_dashboard'.tr(), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('update_bin_location'.tr(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 24),
              TextField(
                controller: binIdController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'bin_id'.tr(),
                  labelStyle: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                  filled: true,
                  fillColor: secondaryColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 32),
              isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : AnimatedButton(
                      onTap: _updateLocation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Text('save_location'.tr(), style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                      ),
                    ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              AnimatedButton(
                onTap: _syncViaBLE,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bluetooth_connected, color: primaryColor),
                      const SizedBox(width: 8),
                      Text('sync_ble'.tr(), style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}