import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shimmer/shimmer.dart';
import 'providers/user_provider.dart';
import 'api_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().fetchActivities(loadMore: false);
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        context.read<UserProvider>().fetchActivities(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getImage(String type) {
    String typeString = type.toLowerCase();
    if(typeString.contains('plastic')) return 'lib/assets/images/plastic_bottle.png';
    if(typeString.contains('aluminum')) return 'lib/assets/images/aluminum_can.png';
    if(typeString.contains('glass')) return 'lib/assets/images/glass_bottle.png';
    if(typeString.contains('cardboard')) return 'lib/assets/images/cardboard_box.png';
    if(typeString.contains('newspaper')) return 'lib/assets/images/newspaper.png';
    return 'lib/assets/images/plastic_bottle.png';
  }

  Widget _buildShimmerEffect(ThemeData theme) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300,
          highlightColor: theme.brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade100,
          child: Container(margin: const EdgeInsets.only(bottom: 12), height: 80, decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.surfaceContainerHighest;

    final userProvider = context.watch<UserProvider>();
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('activity_history'.tr(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: primaryColor)),
                  if (userProvider.isOffline) const Icon(Icons.cloud_off, color: Colors.orange),
                ],
              ),
              const SizedBox(height: 4),
              Text('track_journey'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.trending_up, color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, size: 30),
                          const SizedBox(height: 12),
                          Text('${userProvider.currentBalance}', style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                          Text('total_points_earned'.tr(), style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black54 : Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.inventory_2_outlined, color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, size: 30),
                          const SizedBox(height: 12),
                          Text('${userProvider.totalWeight.toStringAsFixed(1)} ${'kg'.tr()}', style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                          Text('total_weight'.tr(), style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black54 : Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('all_deposits'.tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 16),
              Expanded(
                child: userProvider.isLoading && userProvider.recentActivities.isEmpty
                    ? _buildShimmerEffect(theme)
                    : userProvider.recentActivities.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('no_activities_yet'.tr(), style: const TextStyle(color: Colors.grey)),
                            if (userProvider.isOffline)
                              TextButton(onPressed: () => userProvider.fetchActivities(), child: Text('try_again'.tr(), style: TextStyle(color: primaryColor))),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: primaryColor,
                        onRefresh: () async {
                          await ApiService().validateSession();
                          await userProvider.fetchActivities(loadMore: false);
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          itemCount: userProvider.recentActivities.length + (userProvider.hasMoreActivities ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == userProvider.recentActivities.length) {
                              return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
                            }
                            var activity = userProvider.recentActivities[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(color: secondaryColor, borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                children: [
                                  Image.asset(_getImage(activity['t'] ?? 'plastic'), width: 40, height: 40, errorBuilder: (context, error, stackTrace) => const Icon(Icons.recycling, size: 40)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text((activity['t'] ?? 'plastic').toString().toLowerCase().tr().toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Text(activity['date'] != null ? activity['date'].toString().substring(0, 10) : '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('+${activity['points'] ?? 0} ${'pts'.tr()}', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text('${activity['weight'] ?? 0.0} ${'kg'.tr()}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
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