import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'home_tab.dart';
import 'activity_screen.dart';
import 'rewards_screen.dart';
import 'bins_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ValueNotifier<int> _currentIndex = ValueNotifier<int>(0);

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
                BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: 'profile'.tr()),
              ],
            ),
          ),
        );
      },
    );
  }
}