import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'providers/bins_provider.dart';
import 'api_constants.dart';
import 'bin_map_screen.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController _mapController = MapController();
  WebSocket? _socket;

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _socket?.close();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _connectWebSocket() async {
    if (_isDisposed) return;
    try {
      _socket = await WebSocket.connect(ApiConstants.wsUrl).timeout(const Duration(seconds: 5));
      _socket?.listen((event) {
        try {
          final data = jsonDecode(event);
          if (data['type'] == 'bin_update') {
            final binsProvider = context.read<BinsProvider>();
            binsProvider.fetchBins(binsProvider.currentLat, binsProvider.currentLng);
          }
        } catch (_) {}
      }, onError: (_) {
        if (!_isDisposed) {
          Future.delayed(const Duration(seconds: 5), _connectWebSocket);
        }
      }, onDone: () {
        if (!_isDisposed) {
          Future.delayed(const Duration(seconds: 5), _connectWebSocket);
        }
      });
    } catch (_) {
      if (!_isDisposed) {
        Future.delayed(const Duration(seconds: 5), _connectWebSocket);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black87;

    final binsProvider = context.watch<BinsProvider>();
    final List<Marker> markers = [];

    for (var bin in binsProvider.bins) {
      final double? lat = bin['lat'] != null ? (bin['lat'] as num).toDouble() : null;
      final double? lng = bin['lng'] != null ? (bin['lng'] as num).toDouble() : null;

      if (lat != null && lng != null) {
        final double capacity = (bin['capacity'] ?? 0.0).toDouble();
        final String status = bin['status'] ?? 'idle';
        final bool isLow = capacity < 50;
        final bool isMedium = capacity >= 50 && capacity < 80;
        final Color markerColor = isLow ? Colors.green : (isMedium ? Colors.amber : Colors.red);

        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 70,
            height: 70,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BinMapScreen(
                      binId: bin['bin_id'],
                      lat: lat,
                      lng: lng,
                      status: status,
                      capacity: capacity,
                    ),
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: 'bin_icon_${bin['bin_id']}',
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: markerColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: textColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'live_map'.tr(),
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(binsProvider.currentLat, binsProvider.currentLng),
          initialZoom: 14.0,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.smartbin.app',
            tileBuilder: theme.brightness == Brightness.dark ? _darkModeTileBuilder : null,
          ),
          MarkerLayer(markers: markers),
        ],
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