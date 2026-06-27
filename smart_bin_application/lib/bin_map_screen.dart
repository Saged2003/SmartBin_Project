import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class BinMapScreen extends StatefulWidget {
  final String binId;
  final double lat;
  final double lng;
  final String status;
  final double capacity;

  const BinMapScreen({super.key, required this.binId, required this.lat, required this.lng, required this.status, required this.capacity});

  @override
  State<BinMapScreen> createState() => _BinMapScreenState();
}

class _BinMapScreenState extends State<BinMapScreen> {
  final MapController _mapController = MapController();

  Future<void> _moveToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _mapController.move(LatLng(position.latitude, position.longitude), 16.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black87;

    bool isLow = widget.capacity < 50;
    bool isMedium = widget.capacity >= 50 && widget.capacity < 80;
    Color markerColor = isLow ? Colors.green : (isMedium ? Colors.amber : Colors.red);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: textColor), onPressed: () => Navigator.pop(context)),
        title: Text('bin_location'.tr(args: [widget.binId.toString()]), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(widget.lat, widget.lng),
          initialZoom: 16.0,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.smartbin.app',
            tileBuilder: theme.brightness == Brightness.dark ? _darkModeTileBuilder : null,
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(widget.lat, widget.lng),
                width: 80,
                height: 80,
                child: GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('bin_capacity_alert'.tr(args: [widget.binId.toString(), widget.capacity.toInt().toString()]), style: const TextStyle(fontWeight: FontWeight.bold)))),
                  child: Column(
                    children: [
                      Hero(
                        tag: 'bin_icon_${widget.binId}',
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: markerColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                          child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: textColor, size: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: _moveToCurrentLocation,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  Widget _darkModeTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -1,  0,  0, 0, 255,
         0, -1,  0, 0, 255,
         0,  0, -1, 0, 255,
         0,  0,  0, 1,   0,
      ]),
      child: tileWidget,
    );
  }
}