import 'dart:async';
import 'dart:convert';

import 'package:bla_flutter_app/constants/storage_strings.dart';
import 'package:bla_flutter_app/data/repositories/data_repository.dart';
import 'package:bla_flutter_app/db/sqlite.dart';
import 'package:bla_flutter_app/models/user_model.dart';
import 'package:bla_flutter_app/services/auth_service.dart';
import 'package:bla_flutter_app/services/sercure_storage_service.dart';
import 'package:bla_flutter_app/utils/extensions/datetime_extension.dart';
import 'package:bla_flutter_app/utils/helpers.dart';

enum SyncState { syncing, synced, error, networkUnavailable, postApiError }

class DataSyncService {
  final _stateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get stateStream => _stateController.stream;
  static const classLogName = "Sync Service:";

  Timer? _syncTimer;
  String? lastSyncDateTime;

  // Private constructor
  DataSyncService._();

  // Static instance variable
  static final DataSyncService _instance = DataSyncService._();

  // Getter for the singleton instance
  static DataSyncService get instance => _instance;

  Future<void> startSyncScheduler(
    DataRepository dataRepository,
    SQLiteDB sqLiteDB,
    AuthService authService,
    String username,
    String password, {
    int? postAPIQueueId,
    Function? callback,
  }) async {
    _syncTimer?.cancel();

    //Sync before timer activates
    // Samee - Immediately run syncdata upon login
    // print("startSyncScheduler() running syncData()!");

    await syncData(
      dataRepository,
      sqLiteDB,
      authService,
      username,
      password,
      postAPIQueueId: postAPIQueueId,
      callback: callback,
    );

    //Periodic syncing timer activation
    // Samee - Do NOT run syncdata periodically since it can run clicking Refresh

    /*
    _syncTimer = Timer.periodic(
      // Duration(minutes: 1000000),
      Duration(minutes: 5),
      (timer) async {
        await syncData(
            dataRepository, sqLiteDB, authService, username, password);
      },
    );
    */
  }

  void _setState(SyncState newState) {
    _stateController.add(newState);
  }

  // ✅ NEW (2026-10-10): lets a caller outside this service signal "a
  // screen listening on stateStream should reload" without pretending a
  // real sync happened. Added specifically because
  // push_notification_service.dart's _handleNotificationTap() navigates
  // via GetX's Get.to() (global navigator), which - unlike the in-list
  // tap's local Navigator.push(...).then((_) { if (!isRead) _loadData() })
  // - has no refresh-on-return of its own. Reuses SyncState.synced since
  // that's the one DiaryListTab (and potentially other screens) already
  // correctly responds to by reloading - this is the narrow fix; the
  // underlying issue (listenTableChanges() not being a real reactive
  // stream - it only ever fires once, on initial subscribe) is still
  // outstanding, deliberately deferred as a separate, broader task.
  void notifyExternalDataChange() {
    _setState(SyncState.synced);
  }

  Future<void> syncData(
    DataRepository dataRepository,
    SQLiteDB sqLiteDB,
    AuthService authService,
    String username,
    String password, {
    int? postAPIQueueId,
    Function? callback,
  }) async {
    checkInternetAvailability().then((isInternetAvailable) async {
      if (isInternetAvailable) {
        _setState(SyncState.syncing);
        UserModel? user;
        var storedUserData = await SecureStorageService.instance
            .read(key: StorageStringsConstants.userDataKey);
        if (storedUserData != null) {
          user = UserModel.fromMap(jsonDecode(storedUserData));
          // print("syncData() - storedUser from secure storage: ${storedUserData.toString()}");
        } else {
          print("syncData() - No stored user data found in secure storage.");
          user = await authService.login(username, password);
        }

        // Check if existing Users customerIDs string is different than that of the logged in user
        // UserModel? existingUser;
        // var strUserData = await dataRepository.getUsers(
        //  userName: username,
        // );
        // print("LoginController::getUserByUsername() - strUserData: ${strUserData.toList().first}");
        // if (strUserData.isNotEmpty) {
        // existingUser = UserModel.fromSQLiteMap(strUserData.toList().first);
        // print("DataSyncService::syncData() - existingUser.userCustomerIDs: ${existingUser.userCustomerIDs}, user.userCustomerIDs: ${user?.userCustomerIDs}");
        // }

        if (user != null) {
          var postAPIItemList = await dataRepository.uploadDataToServer(
            authService,
            postAPIQueueId: postAPIQueueId,
          );

          // print("postAPIItemList : ${postAPIItemList?.toList().toString()}");

          if (postAPIItemList != null) {
            //Delete the postAPI entries from table
            for (var queueItem in postAPIItemList) {
              await dataRepository.deletePostAPIData(queueItem);
            }
          } else {
            print("$classLogName postApiError");
            _setState(SyncState.postApiError);
          }
          // print("user.userType: ${user.userType}, isEmployee: $isEmployee, user.isEmployee: ${user.isEmployee}");
          var success = await dataRepository.downloadAllData(
            cookies: authService.cookieValue,
            isEmployee: false,
            // userId: authService.userId!,
            userId: user.id,
            // accessToken: authService.accessToken!,
            accessToken: user.accessToken!,
          );

          if (!success) {
            print("$classLogName Unable to fetch data");
            _setState(SyncState.error);
          } else {
            _setState(SyncState.synced);
            lastSyncDateTime = DateTime.now().toyMdHmsFormattedString();
            // print("$classLogName Sync data at $lastSyncDateTime");
          }
        } else {
          print("$classLogName Unable to authenticate user from server");
        }
      } else {
        print("$classLogName networkUnavailable");
        _setState(SyncState.networkUnavailable);
      }
      if (callback != null) {
        callback();
      }
    });
  }

  static String getSyncStateMessage(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        return 'Syncing data...';
      case SyncState.synced:
        return 'Data synced successfully';
      case SyncState.error:
        return 'Error occurred during sync';
      case SyncState.networkUnavailable:
        return 'Could not sync due to network unavailability';
      case SyncState.postApiError:
        return 'Error occurred while uploading sync data';
    }
  }

  static String formatTitle(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        return 'Syncing Data';
      case SyncState.synced:
        return 'Synced Successfully';
      case SyncState.error:
        return 'Sync Error';
      case SyncState.networkUnavailable:
        return 'Network Unavailable';
      case SyncState.postApiError:
        return 'Sync Upload Error';
      default:
        return 'Unknown State';
    }
  }

  void dispose() {
    // _stateController.close();
    _syncTimer?.cancel();
  }
}
