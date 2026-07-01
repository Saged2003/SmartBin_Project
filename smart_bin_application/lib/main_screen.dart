import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'home_tab.dart';
import 'activity_screen.dart';
import 'rewards_screen.dart';
import 'bins_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'websocket_service.dart';
import 'providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ValueNotifier<int> _currentIndex = ValueNotifier<int>(0);

  late final StreamSubscription<Map<String, dynamic>> _userSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _userSubscription = context.read<UserProvider>().userStream.listen((data) {
        if (data['points_added'] != null && data['points_added'] > 0) {
          _showCelebration(data);
        }
      });
    });
  }

  void _showCelebration(Map<String, dynamic> data) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.network('https://lottie.host/8c6e26eb-46c8-47bc-adcf-3bb1b4d0812b/X8S8Vn99bV.json', repeat: false),
            const SizedBox(height: 20),
            Text(
              '+${data['points_added']} Points!',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              'Total Balance: ${data['points']}',
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _userSubscription.cancel();
    super.dispose();
  }

  void _goToActivity() {
    _currentIndex.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final greyColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final bgColor = theme.scaffoldBackgroundColor;

    final List<Widget> pages = [
      HomeTab(onViewAll: _goToActivity),
      const ActivityScreen(),
      const RewardsScreen(),
      const BinsScreen(),
      const LeaderboardScreen(),
      const ProfileScreen(),
    ];

    return ValueListenableBuilder<int>(
      valueListenable: _currentIndex,
      builder: (context, currentIndex, child) {
        return Scaffold(
          body: pages[currentIndex],
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(top: BorderSide(color: greyColor.withValues(alpha: 0.3), width: 1)),
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: bgColor,
              elevation: 0,
              selectedItemColor: primaryColor,
              unselectedItemColor: greyColor,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              currentIndex: currentIndex,
              onTap: (index) => _currentIndex.value = index,
              items: [
                BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: 'home'.tr()),
                BottomNavigationBarItem(icon: const Icon(Icons.show_chart), label: 'activity'.tr()),
                BottomNavigationBarItem(icon: const Icon(Icons.card_giftcard), label: 'rewards'.tr()),
                BottomNavigationBarItem(icon: const Icon(Icons.location_on_outlined), activeIcon: const Icon(Icons.location_on), label: 'bins'.tr()),
                BottomNavigationBarItem(icon: const Icon(Icons.leaderboard_outlined), activeIcon: const Icon(Icons.leaderboard), label: 'Leaderboard'),
                BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: 'profile'.tr()),
              ],
            ),
          ),
        );
      },
    );
  }
}