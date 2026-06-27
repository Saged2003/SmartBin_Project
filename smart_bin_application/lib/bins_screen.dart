import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shimmer/shimmer.dart';
import 'providers/bins_provider.dart';
import 'bin_map_screen.dart';
import 'live_map_screen.dart';
import 'animated_button.dart';
import 'api_service.dart';

class BinsScreen extends StatefulWidget {
  const BinsScreen({super.key});

  @override
  State<BinsScreen> createState() => _BinsScreenState();
}

class _BinsScreenState extends State<BinsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BinsProvider>().loadCachedBins();
      context.read<BinsProvider>().getCurrentLocation(context);
    });
  }

  void _showLocationDialog(BinsProvider binsProvider, ThemeData theme) {
    TextEditingController latController = TextEditingController(text: binsProvider.currentLat.toString());
    TextEditingController lngController = TextEditingController(text: binsProvider.currentLng.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text('manual_location'.tr(), style: TextStyle(color: theme.primaryColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: latController, decoration: InputDecoration(labelText: 'latitude'.tr()), style: TextStyle(color: theme.textTheme.bodyLarge!.color)),
            TextField(controller: lngController, decoration: InputDecoration(labelText: 'longitude'.tr()), style: TextStyle(color: theme.textTheme.bodyLarge!.color)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr(), style: TextStyle(color: theme.textTheme.bodyLarge!.color))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor),
            onPressed: () {
              Navigator.pop(context);
              binsProvider.updateManualLocation(
                double.tryParse(latController.text) ?? binsProvider.currentLat,
                double.tryParse(lngController.text) ?? binsProvider.currentLng,
              );
            },
            child: Text('update'.tr(), style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer(ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300,
          highlightColor: theme.brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 150,
            decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.surfaceContainerHighest;

    final binsProvider = context.watch<BinsProvider>();
    
    int total = binsProvider.bins.length;
    int avail = binsProvider.bins.where((bin) => bin['status'] == 'idle').length;
    int low = binsProvider.bins.where((bin) => (bin['capacity'] ?? 0.0) < 50).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: () async {
            await ApiService().validateSession();
            await binsProvider.getCurrentLocation(context);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('bins_location'.tr(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: primaryColor)),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.map_outlined, color: primaryColor, size: 28),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LiveMapScreen()),
                            );
                          },
                        ),
                        if (binsProvider.isOffline) const Icon(Icons.cloud_off, color: Colors.orange),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('find_nearby_bins'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 24),
                
                AnimatedButton(
                  onTap: () => binsProvider.getCurrentLocation(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        Icon(Icons.near_me_outlined, color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('current_location'.tr(), style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black54 : Colors.white70, fontSize: 12)),
                              Text(binsProvider.currentLocationName, style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        
                        GestureDetector(
                          onTap: () => _showLocationDialog(binsProvider, theme),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: secondaryColor, borderRadius: BorderRadius.circular(20)),
                            child: Text('change'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatBox(total.toString(), 'total_bins'.tr(), theme),
                    const SizedBox(width: 12),
                    _buildStatBox(avail.toString(), 'available'.tr(), theme),
                    const SizedBox(width: 12),
                    _buildStatBox(low.toString(), 'low_crowd'.tr(), theme),
                  ],
                ),
                const SizedBox(height: 30),
                Text('nearby_bins'.tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                const SizedBox(height: 16),
                
                binsProvider.isLoading && binsProvider.bins.isEmpty 
                    ? _buildShimmer(theme)
                    : binsProvider.bins.isEmpty
                    ? Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            Icon(Icons.location_off, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('no_bins_found'.tr(), style: const TextStyle(color: Colors.grey)),
                            if (binsProvider.isOffline)
                              TextButton(onPressed: () => binsProvider.getCurrentLocation(context), child: Text('try_again'.tr(), style: TextStyle(color: primaryColor))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: binsProvider.bins.length,
                        itemBuilder: (context, index) {
                          var binData = binsProvider.bins[index];
                          String status = binData['status'] ?? 'idle';
                          double capacity = (binData['capacity'] ?? 0.0).toDouble();
                          bool isLow = capacity < 50;
                          bool isMedium = capacity >= 50 && capacity < 80;
                          String crowdText = isLow ? 'low_crowd'.tr() : (isMedium ? 'medium_crowd'.tr() : 'high_crowd'.tr());
                          Color crowdColor = isLow ? Colors.green : (isMedium ? Colors.amber : Colors.red);
                          double distance = binData['distance_km'] ?? 0.0;

                          return AnimatedButton(
                            onTap: () {
                              if (binData['lat'] != null && binData['lng'] != null) {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) => BinMapScreen(
                                    binId: binData['bin_id'],
                                    lat: binData['lat'],
                                    lng: binData['lng'],
                                    status: status,
                                    capacity: capacity,
                                  ),
                                ));
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: secondaryColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.3 : 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Hero(
                                            tag: 'bin_icon_${binData['bin_id']}',
                                            child: Material(
                                              type: MaterialType.transparency,
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: crowdColor,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.delete_outline, color: Colors.white, size: 16),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('${'bin'.tr()} ${binData['bin_id'] ?? ''}', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 16)),
                                        ],
                                      ),
                                      Text('${distance.toStringAsFixed(1)} ${'km'.tr()}', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, color: Colors.grey, size: 16),
                                      const SizedBox(width: 4),
                                      Text('${'lat'.tr()}: ${binData['lat'] ?? 0.0}, ${'lng'.tr()}: ${binData['lng'] ?? 0.0}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('bin_capacity'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                                      Text('${capacity.toInt()}%', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: capacity / 100,
                                      backgroundColor: theme.colorScheme.surface,
                                      valueColor: AlwaysStoppedAnimation<Color>(crowdColor),
                                      minHeight: 8,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildStatusChip(status == 'idle' ? 'available'.tr() : 'busy'.tr(), status == 'idle' ? Colors.green : Colors.red, false, theme),
                                        const SizedBox(width: 10),
                                        _buildStatusChip(crowdText, crowdColor, true, theme),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(String count, String label, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Text(count, style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black54 : Colors.white70, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String text, Color color, bool isDot, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          if (isDot) ...[
            Icon(Icons.circle, color: color, size: 10),
            const SizedBox(width: 6),
          ],
          Text(text, style: TextStyle(color: isDot ? theme.textTheme.bodyLarge!.color : color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}