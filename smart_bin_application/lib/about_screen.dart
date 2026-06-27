import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.surfaceContainerHighest;
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        'ecobin_app'.tr(),
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'version'.tr(),
                        style: TextStyle(fontSize: 13, color: theme.brightness == Brightness.dark ? Colors.white54 : Colors.grey.shade400),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            shape: BoxShape.circle
                          ),
                          child: Icon(Icons.track_changes, color: primaryColor, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'our_mission'.tr(),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'mission_desc'.tr(),
                      style: TextStyle(height: 1.6, color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'how_it_works'.tr(),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildStep(secondaryColor, primaryColor, '1', 'create_account'.tr(), 'create_account_desc'.tr(), theme),
                    const SizedBox(height: 24),
                    _buildStep(secondaryColor, primaryColor, '2', 'find_smart_bin'.tr(), 'find_smart_bin_desc'.tr(), theme),
                    const SizedBox(height: 24),
                    _buildStep(secondaryColor, primaryColor, '3', 'scan_deposit'.tr(), 'scan_deposit_desc'.tr(), theme),
                    const SizedBox(height: 24),
                    _buildStep(secondaryColor, primaryColor, '4', 'earn_redeem'.tr(), 'earn_redeem_desc'.tr(), theme),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'get_in_touch'.tr(),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)
                    ),
                    const SizedBox(height: 24),
                    _buildContactRow(secondaryColor, primaryColor, Icons.alternate_email, 'email'.tr(), 'ecobinsupport@gmail.com', true, theme),
                    const SizedBox(height: 24),
                    _buildContactRow(secondaryColor, primaryColor, Icons.fact_check_outlined, 'follow_us'.tr(), '@ecobinapp', false, theme),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'footer_rights'.tr(),
                style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white38 : Colors.black38, fontSize: 12),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(Color backgroundColor, Color iconColor, String stepNumber, String title, String description, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: backgroundColor,
          radius: 20,
          child: Text(
            stepNumber, 
            style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 18)
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title, 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.brightness == Brightness.dark ? Colors.white : Colors.black87)
              ),
              const SizedBox(height: 6),
              Text(
                description, 
                style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white54 : Colors.black54, fontSize: 13, height: 1.4)
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactRow(Color backgroundColor, Color iconColor, IconData icon, String title, String value, bool underline, ThemeData theme) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: backgroundColor,
          radius: 22,
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title, 
              style: TextStyle(fontSize: 12, color: theme.brightness == Brightness.dark ? Colors.white54 : Colors.black54)
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.brightness == Brightness.dark ? Colors.white : Colors.black87,
                decoration: underline ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ],
        ),
      ],
    );
  }
}