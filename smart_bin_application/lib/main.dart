import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'navigator_service.dart';
import 'theme.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/bins_provider.dart';
import 'providers/rewards_provider.dart';
import 'providers/ble_sync_provider.dart';
import 'api_service.dart';

import 'providers/theme_provider.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (_) {}

    await Hive.initFlutter();
    await Hive.openBox('offline_data');

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    runApp(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'lib/assets/translations',
        fallbackLocale: const Locale('en'),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => BinsProvider()),
            ChangeNotifierProvider(create: (_) => RewardsProvider()),
            ChangeNotifierProvider(create: (_) => BleSyncProvider()),
          ],
          child: const SmartBinApp(),
        ),
      ),
    );
  }, (error, stackTrace) {
    debugPrint('Global Error Caught: $error');
  });
}

class SmartBinApp extends StatefulWidget {
  const SmartBinApp({super.key});
  @override
  State<SmartBinApp> createState() => _SmartBinAppState();
}

class _SmartBinAppState extends State<SmartBinApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ApiService().validateSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Waste Bin',
      navigatorKey: NavigatorService.navigatorKey,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}