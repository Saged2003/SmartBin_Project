import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shimmer/shimmer.dart';
import 'providers/rewards_provider.dart';
import 'animated_button.dart';
import 'api_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final Color premiumGold = const Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RewardsProvider>().fetchData();
    });
  }

  static IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'cafe':
        return Icons.local_cafe;
      case 'restaurant':
        return Icons.restaurant;
      case 'telecom':
        return Icons.phone_android;
      case 'retail':
        return Icons.shopping_cart;
      case 'cash':
        return Icons.attach_money;
      case 'grocery':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.confirmation_num;
      case 'premium':
        return Icons.workspace_premium;
      case 'voucher':
        return Icons.card_giftcard;
      case 'general':
        return Icons.category;
      case 'all':
        return Icons.all_inclusive;
      default:
        return Icons.star;
    }
  }

  String _formatTimeRemaining(String validUntil) {
    try {
      DateTime expiry = DateTime.parse(validUntil);
      Duration diff = expiry.difference(DateTime.now());
      if (diff.isNegative) return 'expired'.tr();
      if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
      if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
      return '${diff.inMinutes}m';
    } catch (_) {
      return '';
    }
  }

  Widget _buildShimmerRewards(ThemeData theme) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.58,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300,
          highlightColor: theme.brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade100,
          child: Container(decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20))),
        );
      },
    );
  }

  final List<String> _categories = [
    'all', 'general', 'cafe', 'restaurant', 'telecom', 'retail', 'grocery', 'cash', 'entertainment', 'premium'
  ];

  Widget _buildCategoryTabs(RewardsProvider rp, ThemeData theme) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          String cat = _categories[index];
          bool isSelected = rp.selectedCategory == cat;
          return GestureDetector(
            onTap: () => rp.setCategory(cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? theme.primaryColor : (theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  cat.tr(),
                  style: TextStyle(
                    color: isSelected ? (theme.brightness == Brightness.dark ? Colors.black87 : Colors.white) : (theme.brightness == Brightness.dark ? Colors.white70 : Colors.grey.shade700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.surfaceContainerHighest;

    final rp = context.watch<RewardsProvider>();
    double progress = 0.0;
    int milestoneInCycle = rp.milestonePoints;
    int pointsRemaining = 1000 - milestoneInCycle;
    if (pointsRemaining < 0) pointsRemaining = 0;
    progress = (milestoneInCycle / 1000).clamp(0.0, 1.0);

    List<dynamic> filteredRewards = rp.rewards.where((r) {
      bool isPremium = r['is_premium'] ?? false;
      if (isPremium && rp.userPoints < 1000) return false;
      if (rp.selectedCategory == 'all') return true;
      return r['category']?.toString().toLowerCase() == rp.selectedCategory.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: () async {
            await ApiService().validateSession();
            await rp.fetchData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('rewards'.tr(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: primaryColor)),
                    if (rp.isOffline) const Icon(Icons.cloud_off, color: Colors.orange),
                  ],
                ),
                const SizedBox(height: 4),
                Text('redeem_eco_points'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('available_points'.tr(), style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black54 : Colors.white70, fontSize: 14)),
                          Icon(Icons.card_giftcard, color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, size: 30),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${rp.userPoints}', style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('premium_progress'.tr(), style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black54 : Colors.white70, fontSize: 13)),
                          Text('${rp.nextMilestone} ${'pts'.tr()}', style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: theme.brightness == Brightness.dark ? Colors.black12 : Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(theme.brightness == Brightness.dark ? Colors.white : const Color(0xFFE2F3E8)),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$pointsRemaining ${'points_to_unlock'.tr()}', style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black54 : Colors.white70, fontSize: 12)),
                          if (rp.premiumUnlocked)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: premiumGold, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.workspace_premium, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text('PREMIUM'.tr(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('available_rewards'.tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                const SizedBox(height: 16),
                _buildCategoryTabs(rp, theme),
                const SizedBox(height: 16),
                rp.isLoading && rp.rewards.isEmpty
                    ? _buildShimmerRewards(theme)
                    : filteredRewards.isEmpty
                        ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("no_rewards_available".tr(), style: const TextStyle(color: Colors.grey))))
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.54,
                            ),
                            itemCount: filteredRewards.length,
                            itemBuilder: (context, index) {
                              var rd = filteredRewards[index];
                              int requiredPoints = rd['required_points'] ?? 0;
                              num? cost = rd['cost'];
                              num? discountPercentage = rd['discount_percentage'];
                              String rewardStatus = rd['status'] ?? 'locked';
                              bool isUnlocked = rewardStatus == 'redeem';
                              bool isExpired = rewardStatus == 'expired';
                              bool isOutOfStock = rewardStatus == 'out_of_stock';
                              bool isDisabled = isExpired || isOutOfStock;
                              bool isPremium = rd['is_premium'] ?? false;
                              String? validUntil = rd['valid_until'];
                              int? stockQuantity = rd['stock_quantity'];
                              String iconCategory = rd['icon_category'] ?? 'voucher';
                              double cardProgress = (rd['progress_percentage'] ?? 0.0).toDouble();

                              Color cardColor = isDisabled
                                  ? (theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade400)
                                  : (isPremium ? const Color(0xFF1A1A2E) : (theme.brightness == Brightness.dark ? theme.colorScheme.surface : primaryColor));
                              Color iconBgColor = isDisabled
                                  ? (theme.brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade300)
                                  : (isPremium ? premiumGold.withValues(alpha: 0.2) : secondaryColor);
                              Color iconColor = isDisabled
                                  ? (theme.brightness == Brightness.dark ? Colors.grey.shade500 : Colors.grey.shade600)
                                  : (isPremium ? premiumGold : primaryColor);
                              Color textColor = (theme.brightness == Brightness.dark && !isPremium && !isDisabled) ? Colors.white : Colors.white; // if it's primaryColor background

                              String statusLabel = isExpired
                                  ? 'expired'.tr()
                                  : isOutOfStock
                                      ? 'out_of_stock'.tr()
                                      : isUnlocked
                                          ? 'redeem'.tr()
                                          : 'locked'.tr();

                              return AnimatedButton(
                                onTap: isDisabled
                                    ? () {}
                                    : (isUnlocked
                                        ? () async {
                                            String? promoCode = await rp.redeemReward(rd['id'], requiredPoints);
                                            if (promoCode != null && mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('reward_redeemed_successfully'.tr(), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                  title: Text('your_promo_code'.tr(), textAlign: TextAlign.center, style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(rd['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), textAlign: TextAlign.center),
                                                      const SizedBox(height: 24),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                                        decoration: BoxDecoration(
                                                          color: theme.primaryColor.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(12),
                                                          border: Border.all(color: theme.primaryColor, width: 2),
                                                        ),
                                                        child: Text(promoCode, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 3, color: theme.primaryColor)),
                                                      ),
                                                      const SizedBox(height: 16),
                                                    ]
                                                  ),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(context), child: Text('ok'.tr(), style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)))
                                                  ],
                                                )
                                              );
                                            } else if (mounted && promoCode == null) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('failed_to_redeem'.tr())));
                                            }
                                          }
                                        : () {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('collect_more_points'.tr())));
                                          }),
                                child: Opacity(
                                  opacity: (!isUnlocked && !isDisabled) ? 0.7 : 1.0,
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.3 : 0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        )
                                      ],
                                      border: isPremium && !isDisabled
                                          ? Border.all(color: premiumGold.withValues(alpha: 0.5), width: 1.5)
                                          : null,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
                                              child: Icon(_getCategoryIcon(iconCategory), color: iconColor, size: 24),
                                            ),
                                            if (!isUnlocked && !isDisabled)
                                              Icon(Icons.lock_outline, color: textColor.withValues(alpha: 0.5), size: 18),
                                            if (isPremium && !isDisabled)
                                              Icon(Icons.workspace_premium, color: premiumGold, size: 18),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(rd['name'] ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Expanded(
                                          child: Text(rd['description'] ?? '', style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        ),
                                        if (discountPercentage != null && discountPercentage > 0) ...[
                                          Text(
                                            '${discountPercentage.toStringAsFixed(0)}% OFF',
                                            style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                        ] else if (cost != null && cost > 0) ...[
                                          Text(
                                            '$cost ${'currency'.tr()} OFF',
                                            style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        if (validUntil != null && !isExpired) ...[
                                          Row(
                                            children: [
                                              Icon(Icons.timer_outlined, color: Colors.amber.shade300, size: 13),
                                              const SizedBox(width: 4),
                                              Expanded(child: Text(_formatTimeRemaining(validUntil), style: TextStyle(color: Colors.amber.shade300, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                        if (stockQuantity != null && stockQuantity > 0 && !isDisabled) ...[
                                          Text('$stockQuantity ${'remaining'.tr()}', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 10)),
                                          const SizedBox(height: 4),
                                        ],
                                        if (!isUnlocked && !isDisabled) ...[
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: LinearProgressIndicator(
                                              value: cardProgress,
                                              backgroundColor: textColor.withValues(alpha: 0.2),
                                              valueColor: AlwaysStoppedAnimation<Color>(isPremium ? premiumGold : (theme.brightness == Brightness.dark ? primaryColor : secondaryColor)),
                                              minHeight: 4,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        if (isDisabled)
                                          Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            width: double.infinity,
                                            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                                            child: Center(child: Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                          )
                                        else
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(child: Text('$requiredPoints ${'pts'.tr()}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: isUnlocked ? (theme.brightness == Brightness.dark ? primaryColor : secondaryColor) : textColor.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  statusLabel,
                                                  style: TextStyle(color: isUnlocked ? (theme.brightness == Brightness.dark ? Colors.black87 : primaryColor) : textColor.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
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
}