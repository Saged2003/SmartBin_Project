import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shimmer/shimmer.dart';
import 'providers/user_provider.dart';
import 'providers/ble_sync_provider.dart';
import 'scanner_screen.dart';
import 'animated_button.dart';
import 'scan_success_screen.dart';
import 'api_service.dart';
import 'theme.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';

class HomeTab extends StatefulWidget {
  final Widget? navigatorKey;
  final VoidCallback onViewAll;
  const HomeTab({super.key, required this.onViewAll, this.navigatorKey});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = context.read<UserProvider>();
      userProvider.loadLocalData();
      userProvider.fetchProfileData();
      userProvider.fetchActivities(loadMore: false);
      context.read<BleSyncProvider>().syncOfflineData();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        context.read<UserProvider>().fetchActivities(loadMore: true);
      }
    });
    _wsSubscription = context.read<UserProvider>().userStream.listen((data) {
      if (mounted && (data['points_added'] ?? 0) > 0) {
        _showCelebrationDialog(data['points_added']);
      }
    });
  }

  void _showCelebrationDialog(int pointsAdded) {
    showDialog(
      context: context,
      builder: (context) {
        Future.delayed(const Duration(seconds: 3), () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('lib/assets/animations/celebration.json', width: 200, height: 200, repeat: false),
              Text('+$pointsAdded Points!', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 10)])),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  IconData _getIcon(String type) {
    String typeString = type.toLowerCase();
    if (typeString.contains('plastic')) return Icons.local_drink_outlined;
    if (typeString.contains('aluminum')) return Icons.change_history;
    if (typeString.contains('glass')) return Icons.wine_bar;
    if (typeString.contains('cardboard')) return Icons.inventory_2_outlined;
    return Icons.recycling;
  }

  Future<void> _handleScanQR(String code) async {
    final userProvider = context.read<UserProvider>();
    bool success = await userProvider.scanQR(code);
    if (success && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanSuccessScreen()));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('invalid_qr'.tr(), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildShimmerActivities() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 70,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final darkGreen = theme.primaryColor;
    final lightGreen = theme.colorScheme.surfaceContainerHighest;
    final accentGreen = theme.colorScheme.secondary;
    final greyColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final userProvider = context.watch<UserProvider>();
    int pointsLeft = 1000 - (userProvider.currentBalance % 1000);
    if (pointsLeft < 0) pointsLeft = 0;
    double progress = ((userProvider.currentBalance % 1000) / 1000).clamp(0.0, 1.0);
    String displayName = userProvider.fullName.isNotEmpty ? userProvider.fullName : userProvider.userName;

    return SafeArea(
      child: RefreshIndicator(
        color: darkGreen,
        onRefresh: () async {
          await ApiService().validateSession();
          await userProvider.fetchProfileData();
          await userProvider.fetchActivities(loadMore: false);
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('welcome'.tr(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: theme.brightness == Brightness.dark ? AppTheme.darkPrimaryColor : const Color(0xFF006653))),
                        const SizedBox(height: 4),
                        Text(displayName, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: darkGreen), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (userProvider.isOffline) const Icon(Icons.cloud_off, color: Colors.orange, size: 28),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: AnimatedButton(
                  onTap: () async {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
                    if (result != null && result.toString().isNotEmpty) {
                      _handleScanQR(result.toString());
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 40),
                    decoration: ShapeDecoration(
                      color: const Color(0xFFBDE038),
                      shape: const StadiumBorder(),
                      shadows: [BoxShadow(color: const Color(0xFFBDE038).withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_scanner, color: Color(0xFF184F35), size: 36),
                        const SizedBox(width: 16),
                        Text('scanner'.tr(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF184F35), letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text('current_balance'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkGreen)),
              const SizedBox(height: 12),
              AnimatedButton(
                onTap: widget.onViewAll,
                child: StreamBuilder<Map<String, dynamic>>(
                  stream: userProvider.userStream,
                  builder: (context, snapshot) {
                    final currentPoints = snapshot.data?['points'] ?? userProvider.currentBalance;
                    int ptsLeft = 1000 - (currentPoints % 1000) as int;
                    if (ptsLeft < 0) ptsLeft = 0;
                    double prog = ((currentPoints % 1000) / 1000).clamp(0.0, 1.0);

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: darkGreen, borderRadius: BorderRadius.circular(24)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$currentPoints', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white)),
                              const SizedBox(width: 8),
                              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('points'.tr(), style: TextStyle(fontSize: 16, color: theme.brightness == Brightness.dark ? Colors.black54 : Colors.white70))),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('premium_progress'.tr(), style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black54 : Colors.white70, fontSize: 13)),
                              Text('$ptsLeft ${'pts_left'.tr()}', style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: prog,
                              backgroundColor: theme.brightness == Brightness.dark ? Colors.black12 : Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(theme.brightness == Brightness.dark ? Colors.white : const Color(0xFFE2F3E8)),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('recent_activity'.tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkGreen)),
                  AnimatedButton(
                    onTap: widget.onViewAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: ShapeDecoration(
                        color: darkGreen,
                        shape: const StadiumBorder(),
                      ),
                      child: Text('view_all'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFBDE038))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              userProvider.isLoading && userProvider.recentActivities.isEmpty
                  ? _buildShimmerActivities()
                  : userProvider.recentActivities.isEmpty
                      ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("no_recent_activities".tr(), style: TextStyle(color: greyColor))))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: userProvider.recentActivities.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final activity = userProvider.recentActivities[index];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: lightGreen, borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
                                    child: Icon(_getIcon(activity['t'] ?? 'plastic'), color: darkGreen, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text((activity["t"] ?? 'plastic').toString().toLowerCase().tr().toUpperCase(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: darkGreen)),
                                        const SizedBox(height: 4),
                                        Text(activity["date"] != null ? activity["date"].toString().substring(0, 10) : "", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: greyColor)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('+${activity["points"] ?? activity["v"] ?? 0} ${'pts'.tr()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkGreen)),
                                      const SizedBox(height: 4),
                                      Text('${activity["weight"] ?? activity["w"] ?? 0.0} ${'kg'.tr()}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: greyColor)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.energy_savings_leaf, color: Colors.teal.shade400, size: 14),
                                          const SizedBox(width: 4),
                                          Text('${(activity['co2_saved_in_activity'] ?? 0.0).toStringAsFixed(2)} g', style: TextStyle(color: Colors.teal.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              if (userProvider.isLoading && userProvider.recentActivities.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}