import 'package:bla_flutter_app/controllers/dashboard_controller.dart'; // Import this
import 'package:bla_flutter_app/controllers/login_controller.dart'; // Import this
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
import 'package:provider/provider.dart'; // Import Provider
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart'; // ✅ Add this
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'firebase_options_staging.dart' as staging;
import 'firebase_options_live.dart' as live;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // 1. Ensure Flutter bindings are ready
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase
  // ✅ Only initialize if no apps exist yet!
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: APIStrings.env == "local"
          ? DefaultFirebaseOptions.currentPlatform
          : APIStrings.env == "dev"
              ? staging.DefaultFirebaseOptions.currentPlatform
              : live.DefaultFirebaseOptions.currentPlatform,
    );
  }

  // ✅ 3. Start listening for Push Notifications!
  await PushNotificationService.instance.initialize();

  // 3. Run your app
  runApp(const MyApp()); // Adjust this if your root widget is named differently
}

// ✅ Changed from StatelessWidget to StatefulWidget
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// ✅ Added WidgetsBindingObserver
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ 1. Clear badge if the user does a cold start (opens app from Terminated state)
    FlutterAppBadger.removeBadge();

    // ✅ 2. Check the Dirty Flag on Cold Start!
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
      // print("App resumed: Syncing data and wiping notification tray...");

      // ✅ 1. Wipe the Android swipe-down tray
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancelAll();

      // ✅ 2. Wipe the custom app icon badge
      FlutterAppBadger.removeBadge();

      // ✅ 2. Check the Dirty Flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // <--- ADD THIS LINE!
      bool pendingSync = prefs.getBool('pending_background_sync') ?? false;
      // print("App resumed: Pending background sync: $pendingSync");

      if (pendingSync) {
        // print("App resumed: Dirty flag is TRUE. Executing targeted sync...");

        // ✅ FIX: only clear the flag below if processing actually ran. This
        // used to reset it unconditionally even when the Get.context/user/
        // repo check failed and processPendingBackgroundPayloads() was
        // therefore skipped entirely - silently and permanently dropping
        // the queued payload, since nothing else would re-check it later.
        // A single failed check here should be rare (the app was already
        // running before backgrounding, unlike a fresh cold start), but if
        // it does happen the flag now stays true so the next resume or
        // login retries it, matching _checkColdStartDirtyFlag()'s pattern.
        bool processed = false;

        try {
          if (Get.context != null) {
            final loginCtrl =
                Provider.of<LoginController>(Get.context!, listen: false);
            if (loginCtrl.getUser != null &&
                loginCtrl.getDataRepository() != null) {
              // ✅ PROCESS THE OFFLINE PAYLOADS FIRST!
              await PushNotificationService.instance
                  .processPendingBackgroundPayloads();
              processed = true;

              // ✅ DEFER THE HEAVY SYNC so the UI can render instantly without locking
              Future.delayed(const Duration(seconds: 3), () {
                // loginCtrl.runDataSync();
              });
            }
          }
        } catch (e) {
          print("Lifecycle Sync Error: $e");
        }

        // ✅ 3. Reset the flag only once we've actually drained the queue.
        if (processed) {
          await prefs.setBool('pending_background_sync', false);
        }
      } else {
        // print("App resumed: Dirty flag is FALSE. Skipping sync.");
      }
    }
  }

// ✅ 3. Add this helper method to handle the Cold Start logic
  // ✅ UPGRADED: Robust Cold Start Loop
  Future<void> _checkColdStartDirtyFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Force read from disk
    bool pendingSync = prefs.getBool('pending_background_sync') ?? false;
    // print("Cold Start: Pending background sync: $pendingSync");

    if (pendingSync) {
      // 🚀 THE FIX: Instead of a blind 2-second wait, we actively poll until the app is ready.
      // We will check once a second, for up to 10 seconds.
      int retries = 0;
      bool syncTriggered = false;

      while (retries < 10 && !syncTriggered) {
        await Future.delayed(const Duration(seconds: 1)); // Wait 1 second

        try {
          if (Get.context != null) {
            final loginCtrl =
                Provider.of<LoginController>(Get.context!, listen: false);

            // Is the user authenticated and the local SQLite database open?
            if (loginCtrl.getUser != null &&
                loginCtrl.getDataRepository() != null) {
              // print("Cold Start Sync Triggered after $retries seconds!");

              // ✅ PROCESS THE OFFLINE PAYLOADS FIRST!
              await PushNotificationService.instance
                  .processPendingBackgroundPayloads();
              loginCtrl.runDataSync();
              syncTriggered = true; // Break the loop!
            }
          }
        } catch (e) {
          // Ignore Provider errors during early boot sequence
        }
        retries++;
      }

      // 🚀 THE FIX: ONLY reset the flag if we successfully told the app to sync.
      // If they aren't logged in (or it timed out), we keep the flag true for next time!
      if (syncTriggered) {
        await prefs.setBool('pending_background_sync', false);
      } else {
        // print("Cold Start Sync Timeout. Flag kept true.");
      }
    } else {
      // print("Cold Start: Dirty flag is FALSE. Normal boot up.");
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
