import 'package:bla_flutter_app/constants/table_names_strings.dart';
import 'package:bla_flutter_app/controllers/dashboard_controller.dart';
import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/models/correspondence_model.dart';
import 'package:bla_flutter_app/models/diary_model.dart';
import 'package:bla_flutter_app/screens/correspondence_details.dart';
import 'package:bla_flutter_app/screens/diary_details.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import 'package:bla_flutter_app/utils/helpers.dart';
import 'dart:convert';

// Serializes read-modify-write access to the pending_payloads /
// app_icon_badge_count SharedPreferences keys. Background messages can
// arrive milliseconds apart (observed: 3 within 41ms), and without this
// lock, two concurrent handler invocations could both read the same
// starting list before either writes it back - whichever writes last
// silently discards the other's addition (a lost-update race). Top-level
// so it's shared by every invocation of the background handler below.
final _pendingPayloadsLock = Lock();

// Queues a payload into pending_payloads and sets the pending_background_sync
// dirty flag, same as the background handler below - shared so the
// foreground listener can defer a message to the same already-robust
// "process once the app is ready" machinery (_checkColdStartDirtyFlag() /
// processPendingBackgroundPayloads() in main.dart) instead of attempting a
// direct save that needs Get.context before it may actually be available.
Future<void> _queuePendingPayload(Map<String, dynamic> data) async {
  await _pendingPayloadsLock.synchronized(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_background_sync', true);

    // This can run from the background isolate/engine, whose
    // SharedPreferences cache can be stale relative to the main isolate's
    // (e.g. right after the main isolate clears pending_payloads once it
    // finishes processing them). Without reloading first, this could append
    // onto an already-processed list and cause the same message to be
    // handled - and its unread counter incremented - more than once.
    await prefs.reload();

    // ✅ NEW: Queue the payload as a JSON string so the main app can process it when it wakes up!
    List<String> pendingPayloads =
        prefs.getStringList('pending_payloads') ?? [];
    pendingPayloads.add(jsonEncode(data));
    await prefs.setStringList('pending_payloads', pendingPayloads);

    // Optimistic +1 on the OS icon badge: this isolate has no live DB/Provider
    // access to compute the true unread total, so we bump a persisted counter
    // instead. DashboardController.refreshCounts() resyncs this to the real
    // count the next time the app is opened, synced, or gets a foreground push.
    try {
      final next = (prefs.getInt('app_icon_badge_count') ?? 0) + 1;
      await prefs.setInt('app_icon_badge_count', next);
      await FlutterAppBadger.updateBadgeCount(next);
    } catch (e) {
      print("Error bumping app icon badge in background: $e");
    }
  });
}

// 1. Top-level background handler (MUST be outside any class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
  await _queuePendingPayload(message.data);
}

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // --- INITIALIZE LISTENERS ---
  Future<void> initialize() async {
    // Register the background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 1. FOREGROUND LISTENER
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print(
          '🔥 Got a message whilst in the foreground! ${message.messageId}, type: ${message.data['type']}, data: ${message.data}');

      // ✅ Intercept and save the payload instantly - but only if the widget
      // tree is actually up. onMessage's listener is attached in main()
      // before runApp() (so Firebase can start delivering messages right
      // away), so a message landing in that brief window would otherwise
      // hit Get.context! with nothing registered yet and throw
      // (observed: "Error saving correspondence locally: Null check
      // operator used on a null value" during cold start). Defer to the
      // same pending_payloads queue + dirty flag the background handler
      // uses, which _checkColdStartDirtyFlag() in main.dart already
      // reliably drains once the app finishes booting.
      if (Get.context == null) {
        await _queuePendingPayload(message.data);
      } else if (message.data['type'] == 'diary_new') {
        await _saveDiaryLocally(message.data);
      } else if (message.data['type'] == 'correspondence_new') {
        await _saveCorrespondenceLocally(message.data); // uncomment when ready
      } else if (message.data['type'] == 'diary_comment_new') {
        await _saveDiaryCommentLocally(message.data); // ✅ Catch the comment!
      }

      if (message.notification != null) {
        // ✅ Only attempt to draw the snackbar if the UI is fully booted
        if (Get.overlayContext != null) {
          Get.snackbar(
            message.notification?.title ?? "New Notification",
            message.notification?.body ?? "",
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.white,
            colorText: Colors.black,
            icon: const Icon(Icons.notifications_active,
                color: Color(0xFF4CAF50)),
            duration: const Duration(seconds: 5),
            boxShadows: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
            onTap: (snack) {
              _handleNotificationTap(message.data);
            },
          );
        }
      }
    });

    // 2. BACKGROUND TAP LISTENER (App is minimized)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print(
          '🔥 Notification tapped from Background! ${message.messageId}, type: ${message.data['type']}, data: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // 3. TERMINATED TAP LISTENER (App is fully closed)
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    print("🔥 Initial message on cold start: $initialMessage");
    if (initialMessage != null) {
      print('🔥 App opened from Terminated state via notification tap!');

      // ✅ THE FIX: Wait for the app state to be fully ready before attempting to route
      _waitForAppReadyAndHandleTap(initialMessage.data);
    }
  }

  // ✅ NEW HELPER METHOD: Add this right below the initialize() method
  void _waitForAppReadyAndHandleTap(Map<String, dynamic> data) async {
    int retries = 0;
    bool isReady = false;

    // Wait up to 10 seconds for the LoginController and SQLite database to initialize
    while (retries < 10 && !isReady) {
      await Future.delayed(const Duration(seconds: 1));
      try {
        if (Get.context != null) {
          final loginCtrl =
              Provider.of<LoginController>(Get.context!, listen: false);
          if (loginCtrl.getUser != null &&
              loginCtrl.getDataRepository() != null) {
            isReady = true;
            _handleNotificationTap(data); // Safely trigger the routing now!
          }
        }
      } catch (_) {
        // Provider not mounted yet, keep waiting
      }
      retries++;
    }

    if (!isReady) {
      print(
          "Timeout waiting for app to be ready for terminated notification tap.");
    }
  }

  // --- ROUTING LOGIC ---
  void _handleNotificationTap(Map<String, dynamic> data) async {
    // print("Notification Tapped! Payload Data: $data");

    if (data.isEmpty) return;

    String? type = data['type'];

    if (type == 'diary_new') {
      try {
        // 1. Force the offline-first save just in case the app was in the background
        //    (If it was in the foreground, this just harmlessly overwrites the existing row)
        await _saveDiaryLocally(data);

        // 2. Fetch the newly constructed DiaryModel directly from SQLite
        final loginCtrl =
            Provider.of<LoginController>(Get.context!, listen: false);
        final repo = loginCtrl.getDataRepository();

        if (repo != null) {
          String diaryId = data['diaryId'].toString();
          final dbResult = await repo.rawQuery(
              "SELECT * FROM ${TableNames.diaries} WHERE diaryId = '$diaryId' LIMIT 1");
          // print("DB Result for Diary ID $diaryId: $dbResult");

          if (dbResult.isNotEmpty) {
            final diary = DiaryModel.fromSQLLiteMap(dbResult.first);

            // 3. Mark as read instantly (Safe Offline Mode)
            try {
              // If we have the server ID, tell the server!
              await repo.markDiaryAsRead(
                diary.diaryId,
                authService: loginCtrl.authService,
                id: diary.id.toString(),
              );
            } catch (e) {
              print("Server read sync skipped: $e");
            }

            try {
              Provider.of<DashboardController>(Get.context!, listen: false)
                  .refreshCounts();
            } catch (_) {}

            // ✅ 4. ADD THIS: Navigate to the Details Screen!
            Get.to(() => DiaryDetailsScreen(item: diary));
            return;
          }
        }
      } catch (e) {
        print("Error routing to Diary Details: $e");
      }

      // Fallback: Go to dashboard if something failed
      Get.offNamedUntil('/dashboard', (route) => route.isFirst);
    } else if (type == 'correspondence_new') {
      await _saveCorrespondenceLocally(data);

      final loginCtrl =
          Provider.of<LoginController>(Get.context!, listen: false);
      final repo = loginCtrl.getDataRepository();

      if (repo != null) {
        int corrId = int.tryParse(data['correspondenceId'].toString()) ?? 0;

        // Fetch the Parent Thread to pass to the Chat Screen
        final dbResult = await repo.rawQuery(
            "SELECT * FROM ${TableNames.correspondences} WHERE id = $corrId LIMIT 1");

        if (dbResult.isNotEmpty) {
          final thread = CorrespondenceModel.fromSQLLiteMap(
              dbResult.first); // Ensure you have this factory or similar

          // 3. Mark as read instantly (Safe Offline Mode)
          try {
            // If we have the server ID, tell the server!
            await repo.markCorrespondenceAsRead(
              thread.id,
              authService: loginCtrl.authService,
            );
          } catch (e) {
            print("Server read sync skipped: $e");
          }

          try {
            Provider.of<DashboardController>(Get.context!, listen: false)
                .refreshCounts();
          } catch (_) {}

          // ✅ NAVIGATE TO CONVERSATION
          // Note: Check your ConversationView constructor. It usually takes a model.
          Get.to(() => CorrespondenceDetailsScreen(item: thread));
          return;
        }
      }
    } else if (type == 'diary_comment_new') {
      // ✅ NEW: ROUTE TO DIARY DETAILS ON COMMENT TAP

      try {
        // 1. Save the comment locally so it's there when the screen opens
        await _saveDiaryCommentLocally(data);

        final loginCtrl =
            Provider.of<LoginController>(Get.context!, listen: false);
        final repo = loginCtrl.getDataRepository();

        if (repo != null) {
          String diaryId = data['diaryId'].toString();

          // 2. Fetch the Parent Diary directly from SQLite
          final dbResult = await repo.rawQuery(
              "SELECT * FROM ${TableNames.diaries} WHERE diaryId = '$diaryId' LIMIT 1");

          if (dbResult.isNotEmpty) {
            final diary = DiaryModel.fromSQLLiteMap(dbResult.first);

            // 3. Mark the parent diary as read (since they are opening it)
            try {
              await repo.markDiaryAsRead(
                diary.diaryId,
                authService: loginCtrl.authService,
                id: diary.id.toString(),
              );
            } catch (_) {}

            try {
              Provider.of<DashboardController>(Get.context!, listen: false)
                  .refreshCounts();
            } catch (_) {}

            // ✅ 4. Navigate directly to the Diary Details Screen!
            Get.to(() => DiaryDetailsScreen(item: diary));
            return;
          } else {
            // Edge case: They tapped a comment for a diary their phone doesn't have yet!
            print("Parent diary not found locally. Triggering fallback sync.");
            loginCtrl.runDataSync();
          }
        }
      } catch (e) {
        print("Error routing to Diary Comment Details: $e");
      }

      // Fallback: If anything fails, safely drop them at the dashboard
      Get.offNamedUntil('/dashboard', (route) => route.isFirst);
    }
  }

  // --- OFFLINE FIRST: SAVE INCOMING DATA DIRECTLY TO SQLITE ---
  Future<void> _saveDiaryLocally(Map<String, dynamic> data) async {
    try {
      final loginCtrl =
          Provider.of<LoginController>(Get.context!, listen: false);
      final repo = loginCtrl.getDataRepository();
      final user = loginCtrl.getUser;

      if (repo != null) {
        var objDiary = {
          'diaryId': data['diaryId'],
          'classId': data['classId'],
          'className': data['className'],
          'title': data['title'],
          'details': data['details'],
          'diaryType': data['diaryType'],
          'subject': data['subject'],
          'dateDue': data['dateDue'] == 'NULL' || data['dateDue'] == ''
              ? null
              : data['dateDue'],
          'createdDate': DateTime.now().toString(),
          'attachment':
              data['attachment'] == 'NULL' ? null : data['attachment'],
          'attachment2':
              data['attachment2'] == 'NULL' ? null : data['attachment2'],
          'bRead': 0,
          'is_deleted': 0,
        };
        // ✅ NEW: Handle Global vs Class-Specific matching
        List<dynamic> matchingStudents = [];
        if (user != null &&
            user.students != null &&
            user.students!.isNotEmpty) {
          // 1. Find which of the parent's students belong to this incoming class notification
          if (data['classId'] == 'all') {
            // It's a global notice: Apply to ALL of the parent's children
            matchingStudents = user.students!;
          } else {
            if (data['diaryType'] == 'fd') {
              matchingStudents = user.students!
                  .where((s) => s['id'].toString() == data['studentId'])
                  .toList();
            } else {
              // It's class-specific: Match the exact class
              matchingStudents = user.students!
                  .where((s) => s['class_id'].toString() == data['classId'])
                  .toList();
            }
          }

          for (var student in matchingStudents) {
            // ✅ PREVENT DUPLICATES: Check if it already exists
            final existing = await repo.rawQuery(
                "SELECT diaryId FROM ${TableNames.diaries} WHERE diaryId = '${data['diaryId']}' AND studentId = '${student['id']}'");
            objDiary['studentId'] =
                student['id']; // Set the studentId for this diary entry
            // The bulk-sync path's `id` for a parent/student row is the
            // server's app_users_notifications.id, which isn't present in
            // the push payload. This client-only "{diaryId}-{studentId}"
            // convention won't match that exactly on a later full sync, but
            // it's stable and unique enough to let idx_diaries_unique_id
            // dedupe repeat/retried pushes for the same student.
            objDiary['id'] = '${data['diaryId']}-${student['id']}';

            if (existing.isEmpty) {
              // 2. Insert the new diary for EACH matching student
              await repo.saveDataToLocal(TableNames.diaries, objDiary);
            }
          }

          // print("✅ Diary inserted for ${matchingStudents.length} students & UI refreshed!");
        } else {
          objDiary['classId'] = data['classId']; //
          objDiary['className'] = data['className']; //
          // Mirrors the backend's own "Unique ID trick" for staff/class-
          // scoped rows (API.class.php's getAPIDiaryList():
          // CONCAT(d.id, '-', IFNULL(dc.classId, '0'))) so a push-inserted
          // row's id matches what a later bulk sync would assign for the
          // same diary+class, letting idx_diaries_unique_id correctly
          // replace rather than duplicate it.
          final rawClassId = data['classId'];
          final normalizedClassId =
              (rawClassId == null || rawClassId == 'all' || rawClassId == '')
                  ? '0'
                  : rawClassId.toString();
          objDiary['id'] = '${data['diaryId']}-$normalizedClassId';
          await repo.saveDataToLocal(TableNames.diaries, objDiary);
          // print("✅ Diary inserted for staff & UI refreshed!");
        }
        // 3. Advance the serverTimestamp so we don't fetch it again!_saveDiaryLocally
        await repo.rawUpdate(
            "UPDATE ${TableNames.userDataFetches} SET serverTimestamp = ?, lastID = ? WHERE action = ?",
            [
              data['createdDate'].toString(),
              data['diaryId'].toString(),
              'diaries'
            ]);

        // ✅ 4. Force UI refresh WITH A DELAY so SQLite can finish writing!
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            if (Get.context != null) {
              Provider.of<DashboardController>(Get.context!, listen: false)
                  .refreshCounts();
            }
          } catch (e) {
            print("Dashboard refresh failed: $e");
          }
        });
      }
    } catch (e) {
      print("❌ Error saving diary locally: $e");
    }
  }

  // --- OFFLINE FIRST: SAVE CORRESPONDENCE LOCALLY ---
  Future<void> _saveCorrespondenceLocally(Map<String, dynamic> data) async {
    try {
      final loginCtrl =
          Provider.of<LoginController>(Get.context!, listen: false);
      final repo = loginCtrl.getDataRepository();

      print("saveCorrespondenceLocally called with data: ${data.toString()}");
      // print("Current Repo Instance: $repo");

      if (repo != null) {
        // ✅ FIX: Force parse IDs into Integers so the Dart Models don't crash!
        int corrId = int.tryParse(data['correspondenceId'].toString()) ?? 0;
        int msgId = int.tryParse(data['id'].toString()) ?? 0;
        int sId = int.tryParse(data['senderId'].toString()) ?? 0;

        // 1. CREATE OR UPDATE THE PARENT THREAD
        final existingThread = await repo.rawQuery(
            "SELECT id FROM ${TableNames.correspondences} WHERE id = $corrId");

        // print("Existing thread check for correspondenceId $corrId: $existingThread");
        String serverTimestamp = data['createdDate'].toString();

        if (existingThread.isEmpty) {
          // Brand new thread! Insert it so the UI can see it.
          // Convert to local time before storing, same as the existing-thread
          // branch below - otherwise a brand-new thread's modifiedDate stays
          // in UTC (~5 hours behind Pakistan time), sorting it below older
          // threads whose modifiedDate was already converted. Mutate `data`
          // itself (not just inline) so the message insert further below,
          // shared by both branches, also picks up the converted values.
          data['date'] = utcToLocal(data['date']);
          data['createdDate'] = utcToLocal(data['createdDate']);
          await repo.saveDataToLocal(TableNames.correspondences, {
            'id': corrId, // <-- Int
            'subject': data['correspondenceTitle'],
            'message': data['message'],
            'date': data['date'],
            'dateEnded': data['dateEnded'] == '' ? null : data['dateEnded'],
            'senderName': data['senderName'],
            'contactName': data['senderName'],
            'bRead': 0,
            'modifiedDate': data['createdDate'],
            'is_deleted': 0,
            'numUnreadMessages': 1,
          });

          // 3. Advance Sync Timestamp
          await repo.rawUpdate(
            "UPDATE ${TableNames.userDataFetches} SET serverTimestamp = ?, lastID = ? WHERE action = ?",
            [serverTimestamp, corrId.toString(), 'correspondences'],
          );
        } else {
          // Thread exists! Just update the preview snippet and mark unread
          // ✅ Convert dates to PST before saving!
          // print("about to update existing thread with new message preview and unread status");
          data['date'] = utcToLocal(data['date']);
          data['createdDate'] = utcToLocal(data['createdDate']);
          await repo.rawUpdate(
              "UPDATE ${TableNames.correspondences} SET bRead = 0, message = ?, date = ?, modifiedDate = ?, numUnreadMessages = IFNULL(numUnreadMessages, 0) + 1 WHERE id = ?",
              [
                data['message'],
                data['date'],
                data['createdDate'].toString(),
                corrId.toString()
              ]);
        }

        // 2. INSERT THE MESSAGE
        final existingMsg = await repo.rawQuery(
            "SELECT id FROM ${TableNames.correspondencesMessages} WHERE id = $msgId");

        // print("Existing message check for messageId $msgId: $existingMsg");

        if (existingMsg.isEmpty) {
          await repo.saveDataToLocal(TableNames.correspondencesMessages, {
            'id': msgId, // <-- Int
            'correspondenceId': corrId, // <-- Int
            'senderId': sId, // <-- Int
            'senderName': data['senderName'],
            'message': data['message'],
            'date': data['date'],
            // 'correspondenceTitle': data['correspondenceTitle'],
            // 'correspondenceDate': data['correspondenceDate'],
            // 'dateEnded': data['dateEnded'] == '' ? null : data['dateEnded'],
            'createdDate': data['createdDate'],
            'modifiedDate': data['createdDate'],
            'is_deleted': 0,
            'bLocal': 0,
          });
        }

        // 3. Advance Sync Timestamp
        await repo.rawUpdate(
          "UPDATE ${TableNames.userDataFetches} SET serverTimestamp = ?, lastID = ? WHERE action = ?",
          [serverTimestamp, msgId.toString(), 'correspondencesMessages'],
        );

        // ✅ 4. Force UI refresh WITH A DELAY so SQLite can finish writing!
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            if (Get.context != null) {
              Provider.of<DashboardController>(Get.context!, listen: false)
                  .refreshCounts();
            }
          } catch (e) {
            print("Dashboard refresh failed: $e");
          }
        });
      }
    } catch (e) {
      print("❌ Error saving correspondence locally: $e");
    }
  }

  // --- OFFLINE FIRST: SAVE DIARY COMMENTS LOCALLY ---
  Future<void> _saveDiaryCommentLocally(Map<String, dynamic> data) async {
    try {
      final loginCtrl =
          Provider.of<LoginController>(Get.context!, listen: false);
      final repo = loginCtrl.getDataRepository();

      if (repo != null) {
        // Parse IDs safely
        int msgId = int.tryParse(data['commentId'].toString()) ?? 0;
        int diaryId = int.tryParse(data['diaryId'].toString()) ?? 0;
        int sId = int.tryParse(data['senderId'].toString()) ?? 0;
        String senderName = data['senderName'] ?? 'Unknown';

        // Note: Make sure 'diary_comments' matches the exact string you use in TableNames
        final String tableName = TableNames.diariesComments;

        // 1. Check if it already exists
        final existing =
            await repo.rawQuery("SELECT id FROM $tableName WHERE id = $msgId");

        if (existing.isEmpty) {
          // 2. Save it locally so the UI updates instantly
          await repo.saveDataToLocal(tableName, {
            'id': msgId,
            'diaryId': diaryId,
            'senderId': sId,
            'senderName': senderName,
            'message': data['message'],
            'createdDate': DateTime.now().toString(),
          });

          await repo.rawUpdate(
              "UPDATE ${TableNames.userDataFetches} SET serverTimestamp = ?, lastID = ? WHERE action = ?",
              [
                data['createdDate'].toString(),
                msgId.toString(),
                'diariesComments'
              ]);

          // 3. Force UI refresh (If they are currently looking at the DiaryDetails screen, it will pop in!)
          Future.delayed(const Duration(milliseconds: 500), () {
            try {
              if (Get.context != null) {
                Provider.of<DashboardController>(Get.context!, listen: false)
                    .refreshCounts();
              }
            } catch (_) {}
          });
        }
      }
    } catch (e) {
      print("❌ Error saving diary comment locally: $e");
    }
  }

  // --- FETCH TOKEN (Your existing code) ---
  Future<String?> getDeviceToken() async {
    try {
      // ✅ FIX: these native Firebase Messaging calls can hang indefinitely
      // (rather than throw) when Google Play Services is unreachable
      // (observed: "SERVICE_NOT_AVAILABLE" logged natively, but nothing ever
      // threw on the Dart side) - without a timeout, login gets stuck on its
      // loading spinner forever even after the actual data sync already
      // succeeded, since _syncFCMToken() runs this before navigating to the
      // dashboard.
      NotificationSettings settings = await _fcm
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
          .timeout(const Duration(seconds: 10));

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token =
            await _fcm.getToken().timeout(const Duration(seconds: 10));
        // print("🔥 FCM Device Token: $token");
        return token;
      }
      return null;
    } catch (e) {
      print("Error getting FCM token: $e");
      return null;
    }
  }

  // ✅ NEW: Process the background queue when the app wakes up
  Future<void> processPendingBackgroundPayloads() async {
    // Claim the queue atomically (read then immediately clear, under the
    // same lock the background handler uses) instead of reading now and
    // clearing only after the whole loop below finishes. Previously, a
    // message queued by the background handler *during* that loop would
    // get silently wiped by the final clear, since it blindly reset the
    // list to [] regardless of what had been added since the initial read.
    List<String> pendingPayloads = [];
    await _pendingPayloadsLock.synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      pendingPayloads = prefs.getStringList('pending_payloads') ?? [];
      if (pendingPayloads.isNotEmpty) {
        await prefs.setStringList('pending_payloads', []);
      }
    });

    if (pendingPayloads.isNotEmpty) {
      print(
          "🔥 Processing ${pendingPayloads.length} payloads from the background queue...");
      for (String payloadStr in pendingPayloads) {
        try {
          Map<String, dynamic> data = jsonDecode(payloadStr);
          String? type = data['type'];

          if (type == 'diary_new') {
            await _saveDiaryLocally(data);
          } else if (type == 'correspondence_new') {
            await _saveCorrespondenceLocally(data);
          } else if (type == 'diary_comment_new') {
            await _saveDiaryCommentLocally(data);
          } else {
            print("Skipping pending payload with unrecognized type '$type': $payloadStr");
          }
        } catch (e) {
          print("Error processing pending payload: $e");
        }
      }
    }
  }

  // --- TOPIC SUBSCRIPTIONS ---
  Future<void> subscribeToTopics(List<String> classIds) async {
    try {
      // Subscribe to a global topic for school-wide notices
      await _fcm.subscribeToTopic('school_all');
      // print("🔔 Subscribed to topic: school_all");

      // Subscribe to specific classes (parents might have multiple kids in different classes!)
      for (String classId in classIds) {
        await _fcm.subscribeToTopic('class_$classId');
        // print("🔔 Subscribed to topic: class_$classId");
      }
    } catch (e) {
      print("Error subscribing to topics: $e");
    }
  }
}
