import 'package:flutter/material.dart';

class NavigatorService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static NavigatorState? get navigator => navigatorKey.currentState;

  static void forceLogout() {
    navigator?.pushNamedAndRemoveUntil('/login', (route) => false);
  }
}