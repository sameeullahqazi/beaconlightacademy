import 'package:bla_flutter_app/controllers/dashboard_controller.dart';
import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/screens/settings.dart';
import 'package:bla_flutter_app/screens/splash_screen.dart';
import 'package:bla_flutter_app/services/auth_service.dart';
import 'package:bla_flutter_app/constants/api_strings.dart';
import 'package:bla_flutter_app/screens/correspondence.dart';
import 'package:bla_flutter_app/screens/login.dart';
import 'package:bla_flutter_app/screens/dashboard.dart';
import 'package:bla_flutter_app/screens/diary.dart';
import 'package:bla_flutter_app/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart'; // ✅ 1. Import Analytics
import 'firebase_options.dart';
import 'firebase_options_staging.dart' as staging;
import 'firebase_options_live.dart' as live;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: APIStrings.env == "local"
          ? DefaultFirebaseOptions.currentPlatform
          : APIStrings.env == "dev"
              ? staging.DefaultFirebaseOptions.currentPlatform
              : live.DefaultFirebaseOptions.currentPlatform,
    );
  }

  await PushNotificationService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // ✅ 2. Create Analytics instance
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterAppBadger.removeBadge();
    _checkColdStartDirtyFlag();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancelAll();
      FlutterAppBadger.removeBadge();

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      bool pendingSync = prefs.getBool('pending_background_sync') ?? false;

      if (pendingSync) {
        try {
          if (Get.context != null) {
            final loginCtrl =
                Provider.of<LoginController>(Get.context!, listen: false);
            if (loginCtrl.getUser != null &&
                loginCtrl.getDataRepository() != null) {
              loginCtrl.runDataSync();
            }
          }
        } catch (e) {
          print("Lifecycle Sync Error: $e");
        }

        await prefs.setBool('pending_background_sync', false);
      }
    }
  }

  Future<void> _checkColdStartDirtyFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    bool pendingSync = prefs.getBool('pending_background_sync') ?? false;

    if (pendingSync) {
      int retries = 0;
      bool syncTriggered = false;

      while (retries < 10 && !syncTriggered) {
        await Future.delayed(const Duration(seconds: 1));

        try {
          if (Get.context != null) {
            final loginCtrl =
                Provider.of<LoginController>(Get.context!, listen: false);

            if (loginCtrl.getUser != null &&
                loginCtrl.getDataRepository() != null) {
              loginCtrl.runDataSync();
              syncTriggered = true;
            }
          }
        } catch (e) {
          // Ignore
        }
        retries++;
      }

      if (syncTriggered) {
        await prefs.setBool('pending_background_sync', false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LoginController>(
          create: (_) => LoginController(AuthService(APIStrings.baseUrl)),
        ),
        ChangeNotifierProxyProvider<LoginController, DashboardController>(
          create: (context) => DashboardController(
            Provider.of<LoginController>(context, listen: false),
          ),
          update: (context, loginCtrl, previousDashboardCtrl) {
            return DashboardController(loginCtrl);
          },
        ),
      ],
      child: GetMaterialApp(
        title: "BLA Connect",
        debugShowCheckedModeBanner: false,
        // ✅ 3. Attach the Analytics Observer to GetX so it logs navigation & clicks automatically!
        navigatorObservers: [observer],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 26, 1, 70),
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/diary': (context) => const DiaryScreen(),
          '/correspondence': (context) => const CorrespondenceScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}
