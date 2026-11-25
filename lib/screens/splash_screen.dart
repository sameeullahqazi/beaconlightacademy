import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/themes/constants.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
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
    // ✅ Force-update check (v9 backlog item, 2026-11-25): runs before
    // anything else on every cold start. Google Play's own In-App Update
    // API detects any higher versionCode already published to this app's
    // Play Store track with no server-side config needed on our side -
    // performImmediateUpdate() shows Play's native full-screen update flow,
    // which blocks the user (no skip/cancel) until the update completes,
    // matching "force prompt whenever a newer release is available"
    // directly. Wrapped defensively: this throws on an emulator/device
    // without Play Store or Play Services, or without network - none of
    // which should ever block a real user from using the app, so any
    // failure here is swallowed and login proceeds normally.
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable &&
          info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      print("InAppUpdate check skipped/failed: $e");
    }

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
