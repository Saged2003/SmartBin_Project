import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'api_service.dart';
import 'api_constants.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final data = await _apiService.getLeaderboard();
      if (mounted) {
        setState(() {
          _leaderboard = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leaderboard.isEmpty
              ? const Center(child: Text('No data available.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _leaderboard.length,
                  itemBuilder: (context, index) {
                    final item = _leaderboard[index];
                    final isFirst = item['rank'] == 1;
                    
                    return Card(
                      elevation: isFirst ? 8 : 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isFirst ? BorderSide(color: Colors.amber.shade400, width: 2) : BorderSide.none,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: isFirst ? Colors.amber.shade100 : Colors.grey.shade200,
                          backgroundImage: item['profile_picture'] != null 
                              ? NetworkImage('${ApiConstants.mediaUrl}${item['profile_picture']}') 
                              : null,
                          child: item['profile_picture'] == null
                              ? Icon(Icons.person, color: isFirst ? Colors.amber.shade700 : Colors.grey)
                              : null,
                        ),
                        title: Row(
                          children: [
                            Text(
                              '#${item['rank']} ${item['username']}',
                              style: TextStyle(
                                fontWeight: isFirst ? FontWeight.bold : FontWeight.w600,
                                fontSize: isFirst ? 18 : 16,
                                color: isFirst ? Colors.amber.shade800 : null,
                              ),
                            ),
                            if (isFirst) const SizedBox(width: 8),
                            if (isFirst) const Icon(Icons.emoji_events, color: Colors.amber),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  Icon(Icons.eco, size: 16, color: Colors.green.shade600),
                                  const SizedBox(width: 4),
                                  Text('${item['co2_saved']} kg CO₂'),
                                  const SizedBox(width: 16),
                                  Icon(Icons.stars, size: 16, color: Colors.blue.shade600),
                                  const SizedBox(width: 4),
                                  Text('${item['points']} pts'),
                                ],
                              ),
                            ),
                            if (isFirst)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('Monthly Reward Winner!', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
