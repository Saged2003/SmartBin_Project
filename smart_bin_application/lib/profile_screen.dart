import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'providers/user_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'api_service.dart';

import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'about_screen.dart';
import 'employee_screen.dart';
import 'animated_button.dart';
import 'redemption_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadLocalData();
      context.read<UserProvider>().fetchProfileData();
    });
  }

  Future<void> _handleLogout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _toggleLanguage() {
    if (context.locale == const Locale('en')) {
      context.setLocale(const Locale('ar'));
    } else {
      context.setLocale(const Locale('en'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.surfaceContainerHighest;

    bool showEmployeeDashboard = userProvider.isEmployee && userProvider.isApprovedEmployee;
    String displayName = userProvider.fullName.isNotEmpty ? userProvider.fullName : userProvider.userName;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: () async {
          await ApiService().validateSession();
          await userProvider.fetchProfileData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Stack(
            children: [
              Container(
                height: 320,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white70,
                          backgroundImage: userProvider.fullProfilePicUrl != null
                              ? NetworkImage(userProvider.fullProfilePicUrl!)
                              : null,
                          child: userProvider.fullProfilePicUrl == null
                              ? const Icon(Icons.person, size: 70, color: Colors.grey)
                              : null,
                        ),
                        if (userProvider.isOffline)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                            child: const Icon(Icons.cloud_off, color: Colors.white, size: 20),
                          )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      userProvider.email.isNotEmpty ? userProvider.email : 'id_eco_user'.tr(),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 260, left: 20, right: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatCard(secondaryColor, primaryColor, Icons.military_tech_outlined, '${userProvider.currentBalance}', 'points'.tr(), theme),
                          _buildStatCard(theme.brightness == Brightness.dark ? Colors.purple.shade900.withValues(alpha: 0.3) : Colors.purple.shade50, Colors.purple.shade300, Icons.check_box_outlined, '${userProvider.deposits}', 'deposits'.tr(), theme),
                          _buildStatCard(theme.brightness == Brightness.dark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50, Colors.blue.shade400, Icons.bolt_outlined, userProvider.totalWeight.toStringAsFixed(1), 'kg_recycled'.tr(), theme),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (showEmployeeDashboard) ...[
                      AnimatedButton(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeScreen()));
                        },
                        child: _buildMenuOption(Icons.admin_panel_settings, 'employee_dashboard'.tr(), theme.brightness == Brightness.dark ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.amber.shade50, Colors.amber.shade800, false, theme),
                      ),
                      const SizedBox(height: 16),
                    ],
                    AnimatedButton(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const RedemptionHistoryScreen()));
                      },
                      child: _buildMenuOption(Icons.card_giftcard, 'my_rewards'.tr(), theme.brightness == Brightness.dark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50, Colors.green.shade600, false, theme),
                    ),
                    const SizedBox(height: 16),
                    AnimatedButton(
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(
                          currentName: userProvider.fullName,
                          currentEmail: userProvider.email,
                          currentPhone: userProvider.phone,
                          currentAddress: userProvider.address,
                          profilePicUrl: userProvider.profilePicUrl,
                        )));
                        if (mounted) {
                          context.read<UserProvider>().fetchProfileData();
                        }
                      },
                      child: _buildMenuOption(Icons.person_outline, 'edit_profile'.tr(), theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50, theme.textTheme.bodyLarge!.color!, false, theme),
                    ),
                    const SizedBox(height: 16),
                    AnimatedButton(
                      onTap: () => themeProvider.toggleTheme(),
                      child: _buildMenuOption(
                        themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        themeProvider.isDarkMode ? 'light_mode'.tr() : 'dark_mode'.tr(),
                        theme.brightness == Brightness.dark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade50,
                        theme.brightness == Brightness.dark ? Colors.blueGrey.shade100 : Colors.blueGrey.shade700,
                        false, theme,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedButton(
                      onTap: _toggleLanguage,
                      child: _buildMenuOption(
                        Icons.language,
                        '${'language'.tr()} (${context.locale == const Locale('en') ? 'العربية' : 'English'})',
                        theme.brightness == Brightness.dark ? Colors.indigo.shade900.withValues(alpha: 0.3) : Colors.indigo.shade50,
                        Colors.indigo.shade400,
                        false, theme,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedButton(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen()));
                      },
                      child: _buildMenuOption(Icons.info_outline, 'about_ecobin'.tr(), theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50, theme.textTheme.bodyLarge!.color!, false, theme),
                    ),
                    const SizedBox(height: 16),
                    AnimatedButton(
                      onTap: _handleLogout,
                      child: _buildMenuOption(Icons.logout, 'logout'.tr(), secondaryColor, primaryColor, true, theme),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(Color backgroundColor, Color iconColor, IconData icon, String value, String title, ThemeData theme) {
    return Column(
      children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: iconColor, size: 28)),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge!.color)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium!.color)),
      ],
    );
  }

  Widget _buildMenuOption(IconData icon, String title, Color backgroundColor, Color textColor, bool isLogout, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: isLogout ? textColor : (theme.brightness == Brightness.dark ? Colors.white70 : Colors.grey.shade600), size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isLogout ? textColor : theme.textTheme.bodyLarge!.color))),
          if (!isLogout) Icon(Icons.arrow_forward_ios, size: 18, color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87),
        ],
      ),
    );
  }
}