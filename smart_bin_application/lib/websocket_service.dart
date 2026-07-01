import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  Function(Map<String, dynamic>)? onPointsUpdated;

  void connect(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final wsUrl = Uri.parse('ws://10.0.2.2:8000/ws/user/$username/');
    
    try {
      _channel = WebSocketChannel.connect(wsUrl);
      _channel?.stream.listen((message) {
        final data = jsonDecode(message);
        if (data['type'] == 'user_update' && data['message'] != null) {
          if (onPointsUpdated != null) {
            onPointsUpdated!(data['message']);
          }
        }
      }, onError: (error) {
        print('WebSocket Error: $error');
        _reconnect(username);
      }, onDone: () {
        print('WebSocket Closed');
        _reconnect(username);
      });
    } catch (e) {
      print('WebSocket Connection Error: $e');
    }
  }

  void _reconnect(String username) {
    Future.delayed(const Duration(seconds: 5), () {
      connect(username);
    });
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
