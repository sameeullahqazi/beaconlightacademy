import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/themes/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    // Artificial delay to show logo (optional)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final loginCtrl = Provider.of<LoginController>(context, listen: false);

    // Attempt Auto Login
    bool success = await loginCtrl.tryAutoLogin();
    // print("successful auto login: $success, mounted: $mounted");

    if (success && mounted) {
      // Go to Dashboard (remove Splash from stack)
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      // Go to Login
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Replace with your Logo Asset
            Image.asset('assets/images/logo.png', width: 150),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.purplePrimary),
          ],
        ),
      ),
    );
  }
}
