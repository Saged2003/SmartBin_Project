import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'providers/auth_provider.dart';
import 'auth_success_screen.dart';
import 'signup_screen.dart';
import 'animated_button.dart';
import 'providers/user_provider.dart';
import 'providers/rewards_provider.dart';
import 'providers/bins_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final ValueNotifier<bool> _isPasswordHidden = ValueNotifier<bool>(true);
  final Color darkGreen = const Color(0xFF006958);
  final Color lightGreen = const Color(0xFFD4F0DA);
  final Color accentGreen = const Color(0xFFA6E037);
  final Color hintColor = const Color(0xFFB8C7C3);
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().reset();
      context.read<RewardsProvider>().reset();
      context.read<BinsProvider>().reset();
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
  
  bool _validateInput() {
    if (emailController.text.trim().isEmpty || !emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('invalid_email'.tr())));
      return false;
    }
    if (passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('short_password'.tr())));
      return false;
    }
    return true;
  }
  
  Future<void> _handleLogin() async {
    if (!_validateInput()) return;
    final authProvider = context.read<AuthProvider>();
    bool success = await authProvider.login(emailController.text.trim(), passwordController.text);
    if (success && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthSuccessScreen()));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('login_failed'.tr())));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.surfaceContainerHighest;
    final accentGreen = const Color(0xFFA6E037);
    final hintColor = theme.brightness == Brightness.dark ? Colors.white54 : const Color(0xFFB8C7C3);
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.brightness == Brightness.dark ? Colors.white : primaryColor;

    final isLoading = context.watch<AuthProvider>().isLoading;
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50),
              Text('welcome'.tr(), textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(height: 60),
              Text('email'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: theme.textTheme.bodyLarge!.color),
                decoration: InputDecoration(
                  hintText: 'enter_email'.tr(),
                  hintStyle: TextStyle(color: hintColor, fontWeight: FontWeight.w500),
                  filled: true,
                  fillColor: secondaryColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              Text('password'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: _isPasswordHidden,
                builder: (context, isHidden, child) {
                  return TextField(
                    controller: passwordController,
                    obscureText: isHidden,
                    style: TextStyle(color: theme.textTheme.bodyLarge!.color),
                    decoration: InputDecoration(
                      hintText: 'enter_password'.tr(),
                      hintStyle: TextStyle(color: hintColor, fontWeight: FontWeight.w500),
                      filled: true,
                      fillColor: secondaryColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      suffixIcon: IconButton(
                        icon: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: textColor),
                        onPressed: () => _isPasswordHidden.value = !_isPasswordHidden.value,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 50),
              isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : AnimatedButton(
                      onTap: _handleLogin,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(25)),
                        child: Center(child: Text('login'.tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white))),
                      ),
                    ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('no_account'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
                    child: Text('signup'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: accentGreen)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}