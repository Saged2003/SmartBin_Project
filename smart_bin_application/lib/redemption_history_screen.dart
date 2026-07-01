import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'providers/rewards_provider.dart';

class RedemptionHistoryScreen extends StatefulWidget {
  const RedemptionHistoryScreen({super.key});

  @override
  State<RedemptionHistoryScreen> createState() => _RedemptionHistoryScreenState();
}

class _RedemptionHistoryScreenState extends State<RedemptionHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _history = [];
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final rp = context.read<RewardsProvider>();
    final history = await rp.fetchRedemptionHistory(startDate: _startDate, endDate: _endDate);
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  IconData _getCategoryIcon(String? category) {
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
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('my_rewards'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month, color: theme.primaryColor),
            onPressed: () async {
              final pickedRange = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: _startDate != null && _endDate != null ? DateTimeRange(start: _startDate!, end: _endDate!) : null,
              );
              if (pickedRange != null) {
                setState(() {
                  _startDate = pickedRange.start;
                  _endDate = pickedRange.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
                  _isLoading = true;
                });
                _loadHistory();
              } else {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _isLoading = true;
                });
                _loadHistory();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('no_history'.tr(), style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
                    ],
                  ),
                )
              : Builder(builder: (context) {
                  var filteredHistory = _history;

                  
                  if (filteredHistory.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('no_history'.tr(), style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final item = filteredHistory[index];
                    final dateStr = item['redeemed_at'] ?? '';
                    String formattedDate = '';
                    if (dateStr.isNotEmpty) {
                      try {
                        // Parse as UTC and convert explicitly to local time (Egypt Time)
                        final parsedUtc = DateTime.parse(dateStr).toUtc();
                        final localTime = parsedUtc.toLocal();
                        formattedDate = DateFormat('yyyy-MM-dd | hh:mm a').format(localTime);
                      } catch (_) {}
                    }
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                                  child: Icon(_getCategoryIcon(item['icon_category']), color: theme.primaryColor),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['reward_name'] ?? 'Reward',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${'redeemed_on'.tr()}$formattedDate',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  Text('promo_code'.tr().toUpperCase(), style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600, letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['promo_code'] ?? 'N/A',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2, color: theme.primaryColor),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
    );
  }
}
