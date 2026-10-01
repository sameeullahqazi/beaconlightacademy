import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bla_flutter_app/constants/storage_strings.dart';
import 'package:bla_flutter_app/db/sqlite.dart';
import 'package:bla_flutter_app/models/user_model.dart';
import 'package:bla_flutter_app/services/data_sync_service.dart';
import 'package:bla_flutter_app/services/sercure_storage_service.dart';
import 'package:bla_flutter_app/utils/helpers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/data_repository.dart';
import '../services/auth_service.dart';
import '../constants/table_names_strings.dart';
import '../models/posi_api_queue_model.dart';
import '../constants/api_strings.dart';
import 'package:bla_flutter_app/services/push_notification_service.dart';

class LoginController with ChangeNotifier {
  String username = "";
  String password = "";
  SQLiteDB? _sqLiteDB;
  UserModel? _user;
  StreamSubscription<SyncState>? syncStateStreamSubs;

  final AuthService _authService;

  // 1. Nullable Repository
  DataRepository? _dataRepository;

  SyncState lastSyncState = SyncState.synced;
  bool _isSyncCooldown = false;
  bool get isSyncCooldown => _isSyncCooldown; // Getter for UI

  AuthService get authService => _authService;

  // LoginController Constructor
  LoginController(this._authService) {
    // Constructor body
  }

  // 2. Getter returns nullable
  DataRepository? getDataRepository() {
    return _dataRepository;
  }

  SQLiteDB? get getDB => _sqLiteDB;

  UserModel? get getUser => _user;

  String _language = "en";
  String get language => _language;
  set language(String pLanguage) {
    if (pLanguage == "Spanish") {
      _language = "es";
    } else {
      _language = "en";
    }
    notifyListeners();
  }

  Future<void> login({
    String? topUsername,
    bool? bSwitchAccount,
    var userSwitchedCallback,
    bool? bForceVIPLogin,
    BuildContext? context,
  }) async {
    bool dbExists = await checkDBExists(username);

    if (!dbExists) {
      // --- FIRST LOGIN FLOW ---
      var isInternetAvailable = await checkInternetAvailability();

      if (isInternetAvailable) {
        bool loginSuccess = await _serverLogin(
          username,
          password,
          bForceVIPLogin: bForceVIPLogin,
          context: context,
        );

        if (loginSuccess) {
          await SecureStorageService.instance.write(
              key: StorageStringsConstants.userDataKey,
              value: jsonEncode(_user!.toMap()));

          if (topUsername != null) {
            await SecureStorageService.instance.write(
                key: StorageStringsConstants.topUserDataKey,
                value: jsonEncode(_user!.toMap()));
          }

          // Create DB and Init Repo
          await createDB(username, topUsername != null);

          // Show Progress Dialog
          Get.dialog(
            barrierDismissible: false,
            PopScope(
              canPop: false,
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 1, 30, 124)
                              .withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_sync_rounded,
                          size: 32,
                          color: Color.fromARGB(255, 1, 30, 124),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Setting Up Profile",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Please wait while we fetch your data...",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 30),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: const LinearProgressIndicator(
                          minHeight: 6,
                          color: Color.fromARGB(255, 1, 30, 124),
                          backgroundColor: Color.fromARGB(255, 124, 145, 212),
                        ),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<String>(
                        // Fix: Use bang operator (!) or null check
                        stream: _dataRepository
                            ?.downloadingStatusStreamController?.stream,
                        builder: (context, snapshot) {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              snapshot.data ?? "Initializing...",
                              key: ValueKey<String>(snapshot.data ?? ""),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color.fromARGB(255, 1, 30, 124),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          // Samee - 01/18/2026: We don't need to keep pinging the server here anymore
          // _authService.startKeepUserLoggedInScheduler();

          var dbSuccess = await _sqLiteDB!.open(shouldCreateSchema: true);

          if (dbSuccess) {
            await SecureStorageService.instance
                .write(key: username, value: password);

            if (_user != null) {
              // Fix: Use bang operator (!)
              await _dataRepository!
                  .saveDataToLocal(TableNames.users, _user!.toSQLLiteMap());
              // print("✅ Saved user ${_user!.username} to local SQLite users table");
            }

            bool isDataDownloaded = await downloadUserData(
              isEmployee: false,
              bForceVIPLogin: bForceVIPLogin,
              bSwitchAccount: bSwitchAccount,
              context: context,
            );

            if (isDataDownloaded) {
              setSyncingStateListener();
              Get.back(); // Close Dialog
              initControllers();

              await _syncFCMToken(); // ✅ ADD THIS HERE
              // print("First Login Success: Navigating to Dashboard");
              Get.offNamed('/dashboard');
            } else {
              Get.back();
              SQLiteDB.deleteDatabase(username);
              _showErrorDialog("Initialization failed",
                  "Error occurred while downloading data.");
            }
          } else {
            Get.back();
            _showErrorDialog(
                "Database Error", "Could not create local database.");
          }
        } else {
          SQLiteDB.deleteDatabase(username);
        }
      } else {
        _showErrorDialog(
            "No Internet", "Internet access is required for first setup.");
      }
    } else {
      // --- RETURNING USER FLOW ---
      String? storedPwd =
          await SecureStorageService.instance.read(key: username);
      bool checkPassword = storedPwd != null && storedPwd == password;
      // print("DB exists for $username. Stored password ${storedPwd != null ? "found to be $storedPwd" : "not found"}. Password match: $checkPassword");

      if (storedPwd == null) {
        _showErrorDialog("Credential Error",
            "Credentials not found. Deleting local data...... \nPlease try again.");
        // 2. Close DB
        var res = await _sqLiteDB?.close();
        // print("Closing DB result: $res, deleting DB file for $username");

        // 3. Delete DB File
        if (username.isNotEmpty) {
          await SQLiteDB.deleteDatabase(username);
        }
      } else if (checkPassword) {
        await createDB(username, topUsername != null);
        var dbSuccess = await _sqLiteDB!.open(shouldCreateSchema: false);

        if (dbSuccess) {
          // Fix: Use bang operator (!)
          DataSyncService.instance.startSyncScheduler(
              _dataRepository!, _sqLiteDB!, _authService, username, password);
          setSyncingStateListener();

          initControllers();

          // Prefer a fresh profile from the server (picks up class
          // transfers, fee-defaulter status, etc.) so the topic healer
          // below has current data; fall back to the local cache offline.
          bool haveFreshUser = await _serverLogin(username, storedPwd);
          if (haveFreshUser && _user != null) {
            await _dataRepository!
                .saveDataToLocal(TableNames.users, _user!.toSQLLiteMap());
            await SecureStorageService.instance.write(
                key: StorageStringsConstants.userDataKey,
                value: jsonEncode(_user!.toMap()));

            await _syncFCMToken();
            // print("Returning Login Success (fresh): Navigating to Dashboard");
            Get.offNamed('/dashboard');
          } else {
            // print("Server unreachable. Falling back to local cache...");
            var strUserData = await _dataRepository!.getUsers(userName: username);
            if (strUserData.isNotEmpty) {
              _user = UserModel.fromSQLiteMap(strUserData.toList().first);
              await SecureStorageService.instance.write(
                  key: StorageStringsConstants.userDataKey,
                  value: jsonEncode(_user!.toMap()));

              await _syncFCMToken();
              // print("Returning Login Success (cached): Navigating to Dashboard");
              Get.offNamed('/dashboard');
            } else {
              print("Returning login failed: no fresh or cached user data.");
              _showErrorDialog("Login Error",
                  "Unable to load your profile. Please check your connection and try again.");
            }
          }
        } else {
          _showErrorDialog(
              "Database Error", "Error initializing local database.");
        }
      }
    }
  }

  void _showErrorDialog(String title, String content) {
    Get.defaultDialog(
      title: title,
      middleText: content,
      confirm: ElevatedButton(
        onPressed: () => Get.back(),
        child: const Text("OK"),
      ),
    );
  }

  Future<bool> checkDBExists(String dbName) async =>
      await SQLiteDB.databaseExists(dbName);

  Future<String> deleteDBFileIfExists(String dbName) async =>
      await SQLiteDB.deleteDBFileIfExists(dbName);

  Future<bool> _serverLogin(String username, String password,
      {bool? bForceVIPLogin, BuildContext? context}) async {
    _user = await _authService.login(username, password);
    bool isLoggedIn = _user != null ? true : false;
    return isLoggedIn;
  }

  initControllers() {}

  Future<void> createDB(String dbName, bool bClose) async {
    if (bClose == true) {
      await _sqLiteDB?.close();
    }
    _sqLiteDB = SQLiteDB(dbName);

    // Initialize repository
    _dataRepository = DataRepository(_sqLiteDB!);

    // Fix: Use bang operator (!) because we just assigned it
    _dataRepository!.downloadingStatusStreamController ??=
        StreamController<String>()..add("Initializing..");

    // ✅ ADD THIS LINE: Tell the app (and DashboardController) the DB is ready!
    notifyListeners();
  }

  setSyncingStateListener() {
    syncStateStreamSubs =
        DataSyncService.instance.stateStream.listen((syncState) {
      if (syncState.name != lastSyncState.name &&
          syncState == SyncState.syncing) {
        final currentRoute = Get.currentRoute;
        if (currentRoute.contains('/ColorDetail')) {
          return;
        }

        Get.snackbar("", "",
            snackPosition: SnackPosition.BOTTOM,
            duration: Duration(seconds: 2),
            snackStyle: SnackStyle.GROUNDED,
            backgroundColor: Colors.transparent,
            margin: EdgeInsets.only(
                right: 16, left: MediaQuery.of(Get.context!).size.width - 72),
            icon: Container(
              width: 32,
              height: 32,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFEFC111)),
                  ),
                ),
              ),
            ));
      }
      lastSyncState = syncState;
    });
  }

  Future<bool> downloadUserData({
    required bool isEmployee,
    bool? bForceVIPLogin,
    bool? bSwitchAccount,
    BuildContext? context,
  }) async {
    // Fix: Use bang operator (!)
    return (await _dataRepository!.downloadAllData(
      isEmployee: isEmployee,
      cookies: _authService.cookieValue,
      init: true,
      bForceVIPLogin: bForceVIPLogin,
      bSwitchAccount: bSwitchAccount,
      context: context,
      userId: _authService.userId,
      accessToken: _authService.accessToken,
    ));
  }

  Map<String, String> getAuthHeaderForImages() {
    return _authService.getAuthHeader();
  }

  refreshCookies() async {
    await _authService.login(username, password);
  }

  getCookies() {
    return _authService.cookieValue;
  }

  void logoutOrExit() async {
    try {
      // ✅ 1. Get the current token before deleting it
      String? token = await FirebaseMessaging.instance.getToken();
      // print("logoutOrExit(): Current FCM token: $token");

      if (token != null) {
        // ✅ 2. Tell YOUR backend to delete this token from `user_fcm_tokens`
        // Note: Implement this API call in your AuthService or DataRepository
        await _dataRepository!.removeDeviceTokenFromServer(
          fcmToken: token,
          userId: _user!.id,
          authService: _authService,
        );
      }

      // ✅ 3. Burn the Firebase Token locally (This auto-drops topic subscriptions on Google's end!)
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      print("Error deleting FCM token: $e");
    }

    // 4. Proceed with normal logout cleanup
    _user = null;
    await _sqLiteDB?.close();
    syncStateStreamSubs?.cancel();
    DataSyncService.instance.dispose();
    removeLoggedInUser();
    removeLoggedInTopUser();
  }

  Future<UserModel?> getUserDetailsByTopLoggedInUser() async {
    UserModel? user;
    var topLoggedInUser = await getLoggedInTopUser();
    // Fix: Use bang operator (!)
    var strUserData =
        await _dataRepository!.getUsers(userName: topLoggedInUser.username);

    if (strUserData.isNotEmpty) {
      user = UserModel.fromSQLiteMap(strUserData.toList().first);
    }
    return user;
  }

  Future<bool> saveSettings(UserModel user) async {
    Map<String, dynamic> userMap = Map<String, dynamic>();
    var userId = user.id;
    userMap = {
      'firstName': user.firstname,
      'lastName': user.lastname,
      'emailAddress': user.email,
    };

    // Fix: Use bang operator (!)
    await _dataRepository!.updateDataToLocal(
        TableNames.users, userMap, "id=?", [userId.toString()]);

    userMap.remove("bLocal");
    userMap["id"] = userId;
    userMap["username"] = user.username;
    userMap["role"] = user.role;

    var request =
        "${APIStrings.postUser}${PostAPIQueueModel.requestSeparator}${jsonEncode(user.toMap())}";

    // Fix: Use bang operator (!)
    var postQueueItem = _dataRepository!.composeQueueItem(
        entityName: PostAPIEntityNames.user,
        action: PostAPIActions.saveUser,
        request: request,
        localEntityId: int.parse(userId),
        serverEntityId: null,
        bCompleted: false);

    // Fix: Use bang operator (!)
    await _dataRepository!
        .saveDataToLocal(TableNames.postApiQueue, postQueueItem.toMap());

    return true;
  }

  _setState() {
    notifyListeners();
  }

  Future<UserModel?> getUserByUsername(String username) async {
    UserModel? user;
    // Fix: Use bang operator (!)
    var strUserData = await _dataRepository!.getUsers(
      userName: username,
    );
    if (strUserData.isNotEmpty) {
      user = UserModel.fromSQLiteMap(strUserData.toList().first);
    }
    return user;
  }

  updateUserDataFetchDownloadStatus(bool bEmployee) {
    // Fix: Use bang operator (!) or safe call
    _dataRepository?.rawQuery(
        "update ${TableNames.userDataFetchDownloads} set status = 1 where status = 0");
  }

  runDataSync({int? postAPIQueueId, Function? callback}) async {
    // Fix: Use bang operator (!)
    await DataSyncService.instance.startSyncScheduler(
      _dataRepository!,
      _sqLiteDB!,
      _authService,
      username,
      password,
      postAPIQueueId: postAPIQueueId,
      callback: callback,
    );
  }

  // --- ADD THIS TO LoginController ---

  Future<void> manualSync(BuildContext context) async {
    if (_isSyncCooldown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please wait 1 minute before refreshing again."),
            duration: Duration(seconds: 2)),
      );
      return;
    }

    if (_user == null) return;

    _isSyncCooldown = true;
    notifyListeners();
    Timer(const Duration(seconds: 60), () {
      _isSyncCooldown = false;
      notifyListeners();
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Syncing data with server..."),
          duration: Duration(seconds: 2)),
    );

    try {
      String? pwd = password;
      if (pwd.isEmpty) {
        pwd = await SecureStorageService.instance.read(key: _user!.username!);
      }
      if (pwd == null) throw Exception("Credentials not found");

      // ==========================================
      // ✅ NEW: SILENTLY REFRESH THE USER PROFILE
      // ==========================================
      UserModel? freshUser = await _authService.login(_user!.username!, pwd);
      if (freshUser != null) {
        _user = freshUser; // Overwrite RAM
        // Overwrite Local DB
        await _dataRepository!
            .saveDataToLocal(TableNames.users, freshUser.toSQLLiteMap());
        // Overwrite Secure Storage
        await SecureStorageService.instance.write(
            key: StorageStringsConstants.userDataKey,
            value: jsonEncode(freshUser.toMap()));

        // 🚀 Run the Smart Topic Healer with the new data!
        await _syncFCMToken();
        notifyListeners(); // Updates the UI Dashboard Dropdown!
      }

      // Proceed with the standard data sync
      await DataSyncService.instance.startSyncScheduler(
        _dataRepository!,
        _sqLiteDB!,
        _authService,
        _user!.username!,
        pwd,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Sync complete!"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      print("Manual Sync Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Sync failed: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // --- ADD THIS TO LoginController ---

  // Attempt to log in automatically using stored credentials
  Future<bool> tryAutoLogin() async {
    try {
      // print("Attempting Auto-Login...");

      // 1. Read stored User Data JSON
      String? userJson = await SecureStorageService.instance
          .read(key: StorageStringsConstants.userDataKey);
      if (userJson == null) {
        print("Auto-Login: No user data found.");
        return false;
      }

      // 2. Reconstruct User Object
      _user = UserModel.fromMap(jsonDecode(userJson));
      if (_user == null || _user!.username == null) return false;

      // 3. Read Stored Password (needed for Sync Service authentication)
      String? storedPwd =
          await SecureStorageService.instance.read(key: _user!.username!);
      if (storedPwd == null) {
        print("Auto-Login: No password found for ${_user!.username}.");
        return false;
      }

      // 4. Restore State in Controller
      username = _user!.username!;
      password = storedPwd;

      // 5. Initialize Database & Repository
      // We pass 'false' to 'bClose' because there is no previous DB open to close
      await createDB(username, false);

      var dbSuccess = await _sqLiteDB!.open(shouldCreateSchema: false);
      if (!dbSuccess) {
        print("Auto-Login: Failed to open database.");
        return false;
      }

      // 6. Initialize Repo & Sync Service
      // We start the scheduler immediately so data stays fresh
      /*
      DataSyncService.instance.startSyncScheduler(
        _dataRepository!,
        _sqLiteDB!,
        _authService,
        username,
        password,
      );

      setSyncingStateListener();
*/
      // 7. Try to refresh the profile from the server (picks up class
      // transfers, fee-defaulter status, etc. before the topic healer
      // runs); silently keep the cached copy already loaded above if
      // the device is offline or the server is unreachable.
      UserModel? freshUser = await _authService.login(username, storedPwd);
      if (freshUser != null) {
        _user = freshUser;
        await _dataRepository!
            .saveDataToLocal(TableNames.users, freshUser.toSQLLiteMap());
        await SecureStorageService.instance.write(
            key: StorageStringsConstants.userDataKey,
            value: jsonEncode(freshUser.toMap()));
      }

      // 8. Restore Authentication State
      // Important: Ensure AuthService has the token/cookie so API calls work
      _authService.setCredentials(
        userId: _user!.id,
        accessToken: _user!.accessToken,
        cookie: "", // Cookies might be stale, but Token is what matters now
      );

      await _syncFCMToken();
      // print("✅ Auto-Login Successful for ${username}");
      return true;
    } catch (e, stackTrace) {
      print("❌ Auto-Login Error: $e, stackTrace: $stackTrace");
      return false;
    }
  }

  // clearAllData: Wipes DB, Storage, and resets State
  Future<void> clearAllData(BuildContext context) async {
    try {
      // 1. Stop Sync
      DataSyncService.instance.dispose();

      // 2. Close DB
      await _sqLiteDB?.close();

      // 3. Delete DB File
      if (username.isNotEmpty) {
        await SQLiteDB.deleteDatabase(username);
      }

      // 4. Clear Secure Storage
      await SecureStorageService.instance.deleteAll();

      // ✅ 1. Burn the Firebase Token so notifications stop arriving for the old user!
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (e) {
        print("Error deleting FCM token: $e");
      }

      // 5. Reset State
      _user = null;
      username = "";
      password = "";
      _dataRepository = null;
      _sqLiteDB = null;

      print("⚠️ App Data Wiped Successfully");

      // 6. Navigate to Login (Remove all history)
      if (context.mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      print("Error clearing data: $e");
    }
  }

  // --- FCM TOKEN & SMART TOPIC HELPER ---
  Future<void> _syncFCMToken() async {
    try {
      if (_user != null && _dataRepository != null) {
        // 1. Update the Device Token on the Server
        String? fcmToken =
            await PushNotificationService.instance.getDeviceToken();
        if (fcmToken != null) {
          String deviceId = await _getOrCreatePersistentDeviceId();

          await _dataRepository!.updateDeviceToken(
            fcmToken: fcmToken,
            userId: _user!.id,
            deviceId: deviceId,
            authService: _authService,
          );
        }

        // ==========================================
        // ✅ 2. THE SMART DIFFERENCE ALGORITHM
        // ==========================================
        final prefs = await SharedPreferences.getInstance();

        // A. Get Old Topics as a Set
        Set<String> oldTopics =
            (prefs.getStringList('subscribed_topics') ?? []).toSet();

        // B. Build New Topics as a Set
        Set<String> newTopics = {'school_all'};
        if (_user!.students != null) {
          for (var s in _user!.students!) {
            if (s['class_id'] != null) newTopics.add('class_${s['class_id']}');
          }
        }

        // ==========================================
        // ✅ NEW: DYNAMIC FEE DEFAULTER ROUTING
        // ==========================================
        if (_user!.role == 'parent' && _user!.isFeeDefaulter == 1) {
          newTopics.add('fee_defaulters');
        }
        // ==========================================

        // C. Calculate the exact differences!
        Set<String> topicsToRemove = oldTopics.difference(newTopics);
        Set<String> topicsToAdd = newTopics.difference(oldTopics);

        // D. Execute only the changes
        for (String topic in topicsToRemove) {
          await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
          // print("🔕 Auto-Heal: Unsubscribed from stale topic -> $topic");
        }

        for (String topic in topicsToAdd) {
          await FirebaseMessaging.instance.subscribeToTopic(topic);
          // print("🔔 Auto-Heal: Subscribed to fresh topic -> $topic");
        }

        // E. Save the new state if anything changed
        if (topicsToRemove.isNotEmpty || topicsToAdd.isNotEmpty) {
          await prefs.setStringList('subscribed_topics', newTopics.toList());
        } else {
          // print("✅ FCM Topics are perfectly up to date.");
        }
      }
    } catch (e) {
      print("Error syncing FCM token/topics: $e");
    }
  }

  // Android's device_info_plus `.id` is actually the OS build ID (e.g.
  // "SQ1D.220205.004"), which changes on every OS update - not a stable
  // per-device identifier. Using it as deviceId meant updateDeviceToken()'s
  // upsert never matched an existing row for a returning device, so
  // user_fcm_tokens accumulated a new row per OS update/reinstall instead of
  // updating one. Generate a UUID once and persist it instead, for both
  // platforms, so the same install is recognized as the same device.
  Future<String> _getOrCreatePersistentDeviceId() async {
    const storageKey = 'device_install_id';
    try {
      String? existing =
          await SecureStorageService.instance.read(key: storageKey);
      if (existing != null && existing.isNotEmpty) return existing;

      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 0x0F) | 0x40; // UUID v4 version bits
      bytes[8] = (bytes[8] & 0x3F) | 0x80; // UUID v4 variant bits
      final hex =
          bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final uuid = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
          '${hex.substring(20)}';

      await SecureStorageService.instance.write(key: storageKey, value: uuid);
      return uuid;
    } catch (e) {
      print("Error generating persistent device id: $e");
      return "unknown";
    }
  }
}
