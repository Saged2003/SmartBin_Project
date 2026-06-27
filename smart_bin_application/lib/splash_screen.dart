import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'main_screen.dart';
import 'login_screen.dart';
import 'api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ValueNotifier<bool> _showSecondIntro = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      _showSecondIntro.value = true;
    }
    await Future.delayed(const Duration(seconds: 3));
    await _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token != null) {
      try {
        await ApiService().validateSession();
        prefs = await SharedPreferences.getInstance();
        token = prefs.getString('token');
      } catch (_) {
        token = null;
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => token != null ? const MainScreen() : const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: ValueListenableBuilder<bool>(
          valueListenable: _showSecondIntro,
          builder: (context, showSecondIntro, child) {
            return Lottie.asset(
              !showSecondIntro ? 'lib/assets/animations/intro1.json' : 'lib/assets/animations/intro2.json',
              fit: BoxFit.contain,
              width: MediaQuery.of(context).size.width * 0.8,
            );
          },
        ),
      ),
    );
  }
}