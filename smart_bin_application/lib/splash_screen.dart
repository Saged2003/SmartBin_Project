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

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  bool _showSecondIntro = false;
  bool _animationCompleted = false;
  Widget? _nextScreen;

  @override
  void initState() {
    super.initState();
    _controller1 = AnimationController(vsync: this);
    _controller2 = AnimationController(vsync: this);

    _controller1.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showSecondIntro = true;
        });
      }
    });

    _controller2.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationCompleted = true;
        _navigateIfReady();
      }
    });

    _performAsyncTasks();
  }

  Future<void> _performAsyncTasks() async {
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

    _nextScreen = token != null ? const MainScreen() : const LoginScreen();
    _navigateIfReady();
  }

  void _navigateIfReady() {
    if (_animationCompleted && _nextScreen != null && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => _nextScreen!));
    }
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: !_showSecondIntro
              ? Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Lottie.asset(
                    'lib/assets/animations/intro1.json',
                    key: const ValueKey(1),
                    controller: _controller1,
                    onLoaded: (composition) {
                      _controller1.duration = composition.duration;
                      _controller1.forward();
                    },
                    fit: BoxFit.contain,
                    width: MediaQuery.of(context).size.width * 0.8,
                  ),
                )
              : Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Lottie.asset(
                    'lib/assets/animations/intro2.json',
                    key: const ValueKey(2),
                    controller: _controller2,
                    onLoaded: (composition) {
                      _controller2.duration = composition.duration;
                      _controller2.forward();
                    },
                    fit: BoxFit.contain,
                    width: MediaQuery.of(context).size.width * 0.8,
                  ),
                ),
        ),
      ),
    );
  }
}