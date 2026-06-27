import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'providers/auth_provider.dart';
import 'auth_success_screen.dart';
import 'animated_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final ValueNotifier<bool> _isPasswordHidden = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _isEmployee = ValueNotifier<bool>(false);
  final Color darkGreen = const Color(0xFF006958);
  final Color lightGreen = const Color(0xFFD4F0DA);
  final Color loginGreen = const Color(0xFFBFE037);
  final Color hintColor = const Color(0xFFB8C7C3);
  
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
  
  Future<void> _handleSignUp() async {
    if (!_validateInput()) return;
    final authProvider = context.read<AuthProvider>();
    bool success = await authProvider.signUp(emailController.text.trim(), passwordController.text, _isEmployee.value);
    if (success && mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthSuccessScreen()), (route) => false);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('signup_failed'.tr())));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.surfaceContainerHighest;
    final loginGreen = const Color(0xFFBFE037);
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
              Text('get_started'.tr(), textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textColor)),
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
                      hintText: 'create_password'.tr(),
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
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: _isEmployee,
                builder: (context, isEmployee, child) {
                  return CheckboxListTile(
                    title: Text("register_employee".tr(), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    value: isEmployee,
                    activeColor: primaryColor,
                    checkColor: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white,
                    side: BorderSide(color: textColor),
                    onChanged: (newValue) => _isEmployee.value = newValue!,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
              const SizedBox(height: 30),
              isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : AnimatedButton(
                      onTap: _handleSignUp,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(25)),
                        child: Center(child: Text('signup'.tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white))),
                      ),
                    ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('already_have_account'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text('login'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: loginGreen)),
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