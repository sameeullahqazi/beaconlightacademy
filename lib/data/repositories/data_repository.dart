import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bla_flutter_app/constants/api_strings.dart';
import 'package:bla_flutter_app/constants/table_names_strings.dart';
import 'package:bla_flutter_app/data/sources/api_client.dart';
import 'package:bla_flutter_app/data/sources/remote/api_data_source_interface.dart';
import 'package:bla_flutter_app/data/sources/remote/diaries_source.dart';
import 'package:bla_flutter_app/data/sources/remote/diaries_comments_source.dart';
import 'package:bla_flutter_app/data/sources/remote/correspondence_sync_source.dart';
import 'package:bla_flutter_app/data/sources/remote/contacts_source.dart';
import 'package:bla_flutter_app/data/sources/remote/classes_source.dart';
import 'package:bla_flutter_app/data/sources/remote/report_cards_list_source.dart';
import 'package:bla_flutter_app/data/sources/remote/report_card_6plus_source.dart';
import 'package:bla_flutter_app/data/sources/remote/report_card_nur5_source.dart';
import 'package:bla_flutter_app/db/sqlite.dart';
import 'package:bla_flutter_app/models/base_model.dart';
import 'package:bla_flutter_app/models/user_model.dart';
import 'package:bla_flutter_app/models/diary_model.dart';
import 'package:bla_flutter_app/models/diary_comments_model.dart';
import 'package:bla_flutter_app/models/correspondence_model.dart';
import 'package:bla_flutter_app/models/correspondence_message_model.dart';
import 'package:bla_flutter_app/models/posi_api_queue_model.dart';
import 'package:bla_flutter_app/models/report_card_list_model.dart';
import 'package:bla_flutter_app/models/data_fetches_model.dart'; // ✅ Import

import 'package:bla_flutter_app/services/auth_service.dart';
import 'package:bla_flutter_app/utils/helpers.dart';
import 'package:bla_flutter_app/utils/extensions/bool_extension.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DataRepository {
  static const classLogName = "DataRepository:";
  final SQLiteDB _sqLiteDB;
  final APIClient _apiClient = APIClient(APIStrings.baseUrl);

  StreamController<String>? downloadingStatusStreamController;

  final ApiDiariesDataSource _diaryDataSource = ApiDiariesDataSource();
  final ApiDiariesCommentsDataSource _diaryCommentsDataSource =
      ApiDiariesCommentsDataSource();
  // ApiCorrespondencesDataSource/ApiCorrespondenceMessagesDataSource (the
  // old two-endpoint sync) are superseded by the combined sync below, but
  // deliberately left in lib/data/sources/remote/ as a rollback path -
  // their backend endpoints (apiCorrespondenceList/apiCorrespondenceMessages)
  // are likewise still live, unmodified.
  final ApiCorrespondenceSyncDataSource _correspondenceSyncDataSource =
      ApiCorrespondenceSyncDataSource();
  final ApiContactsDataSource _contactsDataSource = ApiContactsDataSource();
  final ApiClassesDataSource _classesDataSource =
      ApiClassesDataSource(); // ✅ Add this
  final ApiReportCardsListDataSource _reportCardsListDataSource =
      ApiReportCardsListDataSource();
  final ApiReportCard6PlusDataSource _reportCard6PlusDataSource =
      ApiReportCard6PlusDataSource();
  final ApiReportCardNur5DataSource _reportCardNur5DataSource =
      ApiReportCardNur5DataSource();

  DataRepository(this._sqLiteDB);

  // Download Color, Jobs, JobsColors, Reads and Formulas to local database
  Future<bool> downloadAllData({
    bool isEmployee = false,
    String cookies = "",
    bool init = false,
    bool? bForceVIPLogin,
    bool? bSwitchAccount,
    BuildContext? context,
    String? userId,
    String? accessToken,
    // ✅ NEW (2026-11-22, design-flaws-and-changes doc): when provided, only
    // these entities are synced - everything else is skipped entirely
    // (not even attempted). Used by pull-to-refresh on a single screen
    // (e.g. just FetchAction.diaries from the Diary list) so a quick
    // per-screen refresh doesn't pay for a full 8-entity sync every time.
    // `null` (the default) means "sync everything", matching every
    // existing caller (login, Refresh button, resume/cold-start-sync).
    Set<FetchAction>? only,
  }) async {
    try {
      //Initialize controller if it is null
      downloadingStatusStreamController ??= StreamController<String>();

      // print("dataRepository::downloadAllData() - isEmployee: $isEmployee");

      var success = true;

      if (only == null || only.contains(FetchAction.diaries)) {
        success = await syncEntity(
          cookies,
          0,
          1000,
          _diaryDataSource,
          FetchAction.diaries,
          TableNames.diaries,
          shouldDownloadJson: false,
          shouldFetchInBatches: true,
          userId: userId,
          accessToken: accessToken,
          preserveLocalUnread: true,
        );
        if (!success) {
          throw Exception("Failure while syncing Diaries");
        }
      }

      // ✅ REMOVED (2026-11-22, design-flaws-and-changes doc): diary
      // comments are disabled by staff decision (see bug_diary_oom_crash
      // memory) and have never been shown in the app - Samee's explicit
      // call was to stop paying for this sync entirely (an extra full
      // batched entity fetch on every sync) rather than keep fetching data
      // nothing ever displays. This is independent of the `only` scoping
      // above/below - diariesComments is dropped unconditionally, not just
      // when a caller scopes a partial sync to exclude it. Re-add this
      // syncEntity() call (FetchAction.diariesComments /
      // TableNames.diariesComments) if comments are ever re-enabled.

      // ✅ REPLACED (2026-11-25, correspondence sync optimization): the old
      // two independent syncEntity() calls (FetchAction.correspondences on
      // corr.created, FetchAction.correspondencesMessages on m.created) had
      // a real gap - a reply to an existing thread never re-matched the
      // thread-level cursor, so a thread's own preview/unread count could
      // go stale even though its messages synced fine. One combined call
      // now drives both tables off a single message.created cursor (see
      // project_correspondence_sync_optimization_2026_11_25 memory) -
      // reuses the existing FetchAction.correspondencesMessages cursor
      // value directly (same column/semantics), so already-synced users
      // get a normal incremental fetch here, not a full backlog refetch.
      if (only == null ||
          only.contains(FetchAction.correspondences) ||
          only.contains(FetchAction.correspondencesMessages)) {
        success = await syncCorrespondenceSyncDetails(
          cookies,
          userId: userId,
          accessToken: accessToken,
        );
        if (!success) {
          throw Exception("Failure while syncing Correspondences");
        }
      }

      if (only == null || only.contains(FetchAction.contacts)) {
        // Sync Contacts
        success = await syncEntity(
          cookies,
          0, // offset
          1000, // limit (fetch all)
          _contactsDataSource, // or generic fetcher
          FetchAction.contacts,
          TableNames.contacts,
          shouldDownloadJson: false,
          userId: userId,
          accessToken: accessToken,
        );
        if (!success) {
          throw Exception("Failure while syncing Contacts");
        }
      }

      if (only == null || only.contains(FetchAction.classes)) {
        // ✅ Sync Classes
        success = await syncEntity(
          cookies,
          0,
          1000,
          _classesDataSource,
          FetchAction.classes,
          TableNames.classes,
          shouldDownloadJson: false,
          userId: userId,
          accessToken: accessToken,
        );
        if (!success) {
          throw Exception("Failure while syncing Classes");
        }
      }

      // Report Cards (v9): list is cheap/always-full-refetch (no
      // modifiedDate support server-side - see getAPIReportCardList()'s own
      // comment on why), 6+ and NUR-5 detail are incremental via the normal
      // modifiedDate cursor. None of these being missing should fail the
      // whole login/sync cycle - Report Cards is a new, optional-for-now
      // feature, not core data parents already depend on (unlike Diary/
      // Correspondence above), so a failure here is logged and swallowed
      // rather than thrown.
      if (only == null || only.contains(FetchAction.reportCardsList)) {
        success = await syncEntity(
          cookies,
          0,
          1000,
          _reportCardsListDataSource,
          FetchAction.reportCardsList,
          TableNames.reportCardsList,
          shouldFetchInBatches: true,
          userId: userId,
          accessToken: accessToken,
        );
        if (!success) {
          print("Data Repository: Failure while syncing Report Cards list (non-fatal)");
        }
      }

      if (only == null || only.contains(FetchAction.reportCard6Plus)) {
        success = await syncReportCard6PlusDetails(
          cookies,
          userId: userId,
          accessToken: accessToken,
        );
        if (!success) {
          print("Data Repository: Failure while syncing Report Card 6+ details (non-fatal)");
        }
      }

      if (only == null || only.contains(FetchAction.reportCardNur5)) {
        success = await syncEntity(
          cookies,
          0,
          1000,
          _reportCardNur5DataSource,
          FetchAction.reportCardNur5,
          TableNames.reportCardNur5Data,
          shouldFetchInBatches: true,
          userId: userId,
          accessToken: accessToken,
        );
        if (!success) {
          print("Data Repository: Failure while syncing Report Card NUR-5 details (non-fatal)");
        }
      }

      // Samee - We probably don't need this anymore.
      // print("bForceVIPLogin: $bForceVIPLogin, bSwitchAccount: $bSwitchAccount");
      if (bSwitchAccount == true) {
        // print("bSwitchAccount is true, so closing downloadingStatusStreamController...");
        downloadingStatusStreamController ??= StreamController<String>();
        await downloadingStatusStreamController?.close();
        if (context != null) Navigator.of(context).pop();
      }
      return true;
    } catch (e, s) {
      print("Data Repository: Exception ${e.toString()} \n${s.toString()}");
      return false;
    }
  }

  // See the preserveLocalUnread doc comment on syncEntity() for why this
  // exists. One query for the whole batch (not one per row) - bounded to
  // however many ids are already locally unread, not a table scan.
  Future<List<Map<String, dynamic>>> _mapsPreservingLocalUnread(
      String tableName, List<BaseModel> batch) async {
    final ids = batch.map((c) => c.modelId.toString()).toList();
    if (ids.isEmpty) return [];

    final idList = ids.map((id) => "'$id'").join(',');
    final unreadRows = await _sqLiteDB.rawQuery(
        "SELECT id FROM $tableName WHERE id IN ($idList) AND bRead = 0");
    final locallyUnreadIds = unreadRows.map((r) => r['id'].toString()).toSet();

    return batch.map((c) {
      final map = c.toSQLLiteMap();
      if (locallyUnreadIds.contains(map['id'].toString())) {
        map['bRead'] = 0;
      }
      return map;
    }).toList();
  }

  Future<bool> syncEntity(
    String cookies,
    int startId,
    int batchSize,
    APIDataSourceInterface apiDataSourceInterface,
    FetchAction fetchAction,
    String tableName, {
    bool shouldFetchInBatches = true,
    bool shouldDownloadJson = false,
    String? userId,
    String? accessToken,
    // ✅ FIX (2026-11-25, staff diary badge): getAPIDiaryList()'s staff
    // branch hardcodes `1 as bRead` for every row - there's no real
    // per-staff read-tracking server-side at all. The "unread" a staff
    // member actually sees is purely client-invented
    // (push_notification_service.dart sets bRead=0 on arrival, flipped to
    // 1 only once the user opens it). A bulk sync's upsert is a full row
    // REPLACE, so re-fetching an already-arrived, still-unopened diary
    // was silently overwriting that local bRead=0 with the server's
    // always-1, wiping the badge on every sync regardless of whether the
    // user had actually looked at it - confirmed live (Samee saw a
    // real-time 18 -> 2 badge drop on toobaroghay's account purely from
    // backgrounding/foregrounding the app). When true, preserves whatever
    // the existing local row's bRead already is instead of accepting the
    // incoming batch's value - only meaningful for entities where the
    // server's own bRead isn't trustworthy (diaries' staff branch), so
    // this is opt-in per entity rather than a blanket behavior change.
    bool preserveLocalUnread = false,
  }) async {
    try {
      // Samee - temporarily not downloading json
      // shouldDownloadJson = false;
      //Load data from user_data_fetches table for color action
      // print("syncEntity() - fetchAction: ${fetchAction.name}, tableName: $tableName");
      var entityRow = await _sqLiteDB.query(
        TableNames.userDataFetches,
        "action=?",
        [fetchAction.name],
      );
      // print("syncEntity() - fetchAction run successfully, entityRow: $entityRow");

      // Timestamp for last modified from server
      DateTime? date; // DateFormat('yyyy-MM-dd HH:mm:ss.S').parse(
      //(await _apiClient.get(
      //   endPoint: APIStrings.getCurrentDBTime))["date"]);

      //Preparing headers for filters
      var paramsList = <String>[];
      DataFetchesModel? dataFetchModel;
      if (entityRow.isNotEmpty && shouldFetchInBatches) {
        dataFetchModel = DataFetchesModel.fromMap(entityRow.first);
        paramsList.addAll([
          // "modifiedDate=${dataFetchModel.serverTimestamp.toyMdHmsFormattedString()}"
          // Samee - so that formatting is possible at the backend, reduce 23 further if needed (to 22 e.g.)
          // "modifiedDate=${dataFetchModel.serverTimestamp.substring(0, 23)}"
          "modifiedDate=${dataFetchModel.serverTimestamp}"
        ]);
      }

      var entityResult = {};
      var entityList = <BaseModel>[];
      int totalRowsFetched = 0;
      String latestDateStr = "";
      dynamic lastRowId;

      //Check if it is fetching for the first time and should fetch in batches
      if (paramsList.isEmpty && shouldFetchInBatches) {
        int _startId = startId; // This is our SQL offset (starts at 0)
        int numberOfRowsFetched = 0;

        do {
          paramsList.add("offset=$_startId&limit=$batchSize");

          downloadingStatusStreamController
              ?.add("Downloading ${tableName.replaceAll("_", " ")}");

          //Fetch data from server
          entityResult = await apiDataSourceInterface.fetchData(
            cookies: cookies,
            params: paramsList,
            userId: userId,
            accessToken: accessToken,
          );

          // ✅ FIX 1: Isolate the current batch
          var currentBatch = entityResult["dataList"] as List<BaseModel>;
          numberOfRowsFetched = currentBatch.length;

          //Exit loop if no data is returned
          if (numberOfRowsFetched == 0) {
            break;
          }

          // ✅ FIX: Track the running max modifiedDate and last row ID
          // without retaining every batch's full model objects for the
          // whole sync. A first-time sync fetching 19,000+ rows (e.g. a
          // coordinator's full diary backlog), each carrying a raw HTML
          // `details` field, was blowing the heap by keeping all of them
          // in entityList simultaneously even though DB inserts were
          // already correctly limited to one batch at a time.
          String batchMaxDate = getLatestModifiedDateString(currentBatch);
          if (batchMaxDate.isNotEmpty &&
              (latestDateStr.isEmpty ||
                  DateTime.parse(latestDateStr)
                      .isBefore(DateTime.parse(batchMaxDate)))) {
            latestDateStr = batchMaxDate;
          }
          lastRowId = currentBatch.last.modelId;

          downloadingStatusStreamController
              ?.add("Saving ${tableName.replaceAll("_", " ")} to database");

          // ✅ FIX 2: Only insert the CURRENT batch into SQLite to prevent freezing!
          await _sqLiteDB.executeTransaction(
              tableName,
              preserveLocalUnread
                  ? await _mapsPreservingLocalUnread(tableName, currentBatch)
                  : currentBatch.map((c) => c.toSQLLiteMap()).toList());

          // ✅ FIX 3: Standard SQL offset increments exactly by batchSize (0 -> 1000 -> 2000)
          _startId += batchSize;

          totalRowsFetched += numberOfRowsFetched;
          paramsList.clear();

          // print("Data Repository: ${fetchAction.name} - Total rows fetched so far: $totalRowsFetched, number of rows fetched in this batch: $numberOfRowsFetched, batchSize: $batchSize, next offset: $_startId");
        } while (numberOfRowsFetched == batchSize);
      } else {
        if (shouldDownloadJson) {
          paramsList.add("downloadJSON=1");
        }

        downloadingStatusStreamController
            ?.add("Downloading ${tableName.replaceAll("_", " ")}");
        //Fetch data from server
        entityResult = await apiDataSourceInterface.fetchData(
          cookies: cookies,
          params: paramsList,
          shouldDownloadJson: shouldDownloadJson,
          userId: userId,
          accessToken: accessToken,
        );
        entityList = entityResult["dataList"] as List<BaseModel>;

        // debugPrint(
        //     "Data Repository: ${fetchAction.name} Syncing ${entityList.toString()}");

        downloadingStatusStreamController
            ?.add("Saving ${tableName.replaceAll("_", " ")} to database");
        //Storing data locally in tables
        if (tableName.toLowerCase() == 'users') {
          // print("loggedInUser data: ${topUser.toMap().toString()}");
        }
        await _sqLiteDB.executeTransaction(
          tableName,
          preserveLocalUnread
              ? await _mapsPreservingLocalUnread(tableName, entityList)
              : entityList.map((c) {
                  return c.toSQLLiteMap();
                }).toList(),
        );
        if (tableName.toLowerCase() == 'users') {
          var numUsers = entityList.length;
          for (var i = 0; i < numUsers; i++) {
            var c = entityList[i];
            // print("users table data: ${c.toMap().toString()}");
            UserModel? userToUpdate = UserModel.fromMap(c.toMap());
            // print("updating user in local storage!");
            var topUser = await getLoggedInTopUser();

            if (topUser.username == userToUpdate.username) {
              // if (!topUser.isEmployee) {
              await setLoggedInTopUser(userToUpdate);
              // }
            }
          }
        }
        totalRowsFetched = entityList.length;
      }

      //Sort by modifiedDate
      // if(entityList.isNotEmpty) {
      //   entityList.sort((a, b) {
      //     return a.colorId!.compareTo(b.colorId!);
      //   });
      // }

      //Timestamp for last modified
      // String dateString = entityResult["date"];
      // DateTime date =
      //     DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'").parse(dateString);

      //Find LastID

      // print("totalRowsFetched for $tableName: $totalRowsFetched");
      if (totalRowsFetched > 0) {
        // The batched path above already tracks these incrementally; the
        // single-shot (non-batched, non-paginated) path below still
        // populates entityList directly, so derive them from it here.
        if (latestDateStr.isEmpty && entityList.isNotEmpty) {
          latestDateStr = getLatestModifiedDateString(entityList);
        }
        lastRowId ??= entityList.isNotEmpty ? entityList.last.modelId : null;

        var lastID = dataFetchModel != null
            ? dataFetchModel.lastID
            : (lastRowId ?? "-1");

        //creating data_fetch model for colors
        dataFetchModel = DataFetchesModel(
            username: _sqLiteDB.dbName,
            action: fetchAction,
            // serverTimestamp: date.toString().replaceAll(RegExp(r'Z'), ''), // date,
            // ✅ FIX: Use the raw string directly. No regex or formatting needed.
            serverTimestamp: latestDateStr,
            numRowsFetched: totalRowsFetched,
            lastID: lastID);
        //Inserting into user_data_fetches table
        // print("user_data_fetches row for $tableName: ${dataFetchModel.toMap()}");

        await _sqLiteDB.insertOrUpdate(
            TableNames.userDataFetches, dataFetchModel.toMap());
      }

      return true;
    } catch (e, s) {
      print("Data Repository: ${e.toString()} \n ${s.toString()}");
      return false;
    }
  }

  // Combined correspondence sync (2026-11-25) - apiCorrespondenceSync's
  // response, like apiReportCard6Plus's, doesn't fit syncEntity()'s
  // one-row-per-table model: one call returns both correspondences[] and
  // messages[], cursored purely on message.created (see
  // project_correspondence_sync_optimization_2026_11_25 memory for why a
  // separate thread-level cursor was dropped). Reuses the existing
  // FetchAction.correspondencesMessages cursor row directly - its stored
  // value is already message.created-based, identical to what this query
  // needs, so switching to this method costs already-synced users nothing
  // (no backlog refetch), only new/incremental rows are fetched.
  Future<bool> syncCorrespondenceSyncDetails(
    String cookies, {
    String? userId,
    String? accessToken,
  }) async {
    try {
      String? modifiedDate;
      var entityRow = await _sqLiteDB.query(
        TableNames.userDataFetches,
        "action=?",
        [FetchAction.correspondencesMessages.name],
      );
      if (entityRow.isNotEmpty) {
        modifiedDate = DataFetchesModel.fromMap(entityRow.first).serverTimestamp;
      }

      downloadingStatusStreamController?.add("Downloading correspondences");
      var result = await _correspondenceSyncDataSource.fetchCorrespondenceSync(
        cookies: cookies,
        modifiedDate: modifiedDate,
        userId: userId,
        accessToken: accessToken,
      );

      var correspondences = result['correspondences'] as List<CorrespondenceModel>;
      var messages = result['messages'] as List<CorrespondenceMessageModel>;

      downloadingStatusStreamController?.add("Saving correspondences to database");
      if (correspondences.isNotEmpty) {
        await _sqLiteDB.executeTransaction(
          TableNames.correspondences,
          correspondences.map((c) => c.toSQLLiteMap()).toList(),
        );
      }
      if (messages.isNotEmpty) {
        await _sqLiteDB.executeTransaction(
          TableNames.correspondencesMessages,
          messages.map((m) => m.toSQLLiteMap()).toList(),
        );
      }

      // The cursor must advance even when only messages (no new threads)
      // came back - a reply to an existing thread is exactly the case the
      // old two-cursor design used to miss (see memory). Only messages[]
      // is guaranteed non-empty whenever anything changed at all, since
      // every correspondences[] entry is itself backed by a message row.
      if (messages.isNotEmpty) {
        String latestDateStr = getLatestModifiedDateString(messages);
        var dataFetchModel = DataFetchesModel(
          username: _sqLiteDB.dbName,
          action: FetchAction.correspondencesMessages,
          serverTimestamp: latestDateStr.isNotEmpty ? latestDateStr : (modifiedDate ?? ''),
          numRowsFetched: messages.length,
          lastID: messages.last.modelId,
        );
        await _sqLiteDB.insertOrUpdate(
            TableNames.userDataFetches, dataFetchModel.toMap());
      }

      return true;
    } catch (e, s) {
      print("Data Repository: ${e.toString()} \n ${s.toString()}");
      return false;
    }
  }

  // Report Cards 6+ detail doesn't fit syncEntity()'s one-row-per-table
  // model - getAPIReportCard6Plus() returns one composite object per report
  // card (examTypes/subjects/marks/summary bundled together), flattened
  // here into report_card_marks_6plus and report_card_summary_6plus.
  // Reuses the same user_data_fetches cursor-tracking convention as
  // syncEntity() so this participates in incremental sync the same way.
  Future<bool> syncReportCard6PlusDetails(
    String cookies, {
    String? userId,
    String? accessToken,
    int? reportCardId,
  }) async {
    try {
      String? modifiedDate;
      if (reportCardId == null) {
        var entityRow = await _sqLiteDB.query(
          TableNames.userDataFetches,
          "action=?",
          [FetchAction.reportCard6Plus.name],
        );
        if (entityRow.isNotEmpty) {
          modifiedDate = DataFetchesModel.fromMap(entityRow.first).serverTimestamp;
        }
      }

      downloadingStatusStreamController?.add("Downloading report card details");
      var reportCards = await _reportCard6PlusDataSource.fetchReportCards(
        cookies: cookies,
        modifiedDate: modifiedDate,
        reportCardId: reportCardId,
        userId: userId,
        accessToken: accessToken,
      );

      if (reportCards.isEmpty) return true;

      var headerRows = <Map<String, dynamic>>[];
      var marksRows = <Map<String, dynamic>>[];
      var summaryRows = <Map<String, dynamic>>[];
      String latestDateStr = modifiedDate ?? '';

      for (var rcDynamic in reportCards) {
        var rc = rcDynamic as Map<String, dynamic>;
        var reportCardId = rc['reportCardId'];

        final header = rc['header'] as Map<String, dynamic>?;
        if (header != null) {
          headerRows.add({
            'reportCardId': reportCardId,
            'studentName': header['studentName'],
            'fathersName': header['fathersName'],
            'grNo': header['grNo'],
            'rollNo': header['rollNo'],
            'branch': header['branch'],
            'classNumber': header['classNumber'],
            'section': header['section'],
            'classTeacher': header['classTeacher'],
          });
        }

        var examTypeLabelsById = <String, String>{};
        for (var et in (rc['examTypes'] as List<dynamic>)) {
          examTypeLabelsById[et['id'].toString()] = et['name'];
        }
        var subjectNamesById = <String, String>{};
        for (var s in (rc['subjects'] as List<dynamic>)) {
          subjectNamesById[s['id'].toString()] = s['name'];
        }

        for (var m in (rc['marks'] as List<dynamic>)) {
          marksRows.add({
            'reportCardId': reportCardId,
            'examTypeId': m['examTypeId'],
            'examTypeLabel': examTypeLabelsById[m['examTypeId'].toString()],
            'subjectId': m['subjectId'],
            'subjectName': subjectNamesById[m['subjectId'].toString()],
            'maxMarks': m['maxMarks'],
            'obtainedMarks': m['marksObtained'],
            'passingMarks': m['passingMarks'],
            'highestMarks': m['highestMarks'],
          });
        }

        for (var s in (rc['summary'] as List<dynamic>)) {
          summaryRows.add({
            'reportCardId': reportCardId,
            'examTypeId': s['examTypeId'],
            'isAnnual': s['isAnnual'] == true ? 1 : 0,
            'attendanceVal': s['attendanceVal'],
            'attendanceTotal': s['attendanceTotal'],
            'highestInClass': s['highestInClass'],
            'totalStudents': s['totalStudents'],
            'behavior': s['gen_behavior'],
            'punctuality': s['punctuality'],
            'academicPotential': s['academic_potential'],
            'participation': s['class_participation'],
            'creativity': s['creativity'],
            'examDate': s['date'],
            'remarks': s['remarks'],
          });
        }

        var rcModified = rc['modifiedDate']?.toString();
        if (rcModified != null &&
            rcModified.isNotEmpty &&
            (latestDateStr.isEmpty ||
                DateTime.parse(latestDateStr).isBefore(DateTime.parse(rcModified)))) {
          latestDateStr = rcModified;
        }
      }

      downloadingStatusStreamController?.add("Saving report card details to database");
      await _sqLiteDB.executeTransaction(TableNames.reportCardHeader6Plus, headerRows);
      await _sqLiteDB.executeTransaction(TableNames.reportCardMarks6Plus, marksRows);
      await _sqLiteDB.executeTransaction(TableNames.reportCardSummary6Plus, summaryRows);

      // A single-card on-demand fetch must NOT touch the incremental sync
      // cursor - it's one card pulled out of order (possibly older than
      // what's already been synced), not a step forward in the regular
      // cursor-driven sync.
      if (reportCardId == null) {
        var dataFetchModel = DataFetchesModel(
          username: _sqLiteDB.dbName,
          action: FetchAction.reportCard6Plus,
          serverTimestamp: latestDateStr,
          numRowsFetched: reportCards.length,
          lastID: "-1",
        );
        await _sqLiteDB.insertOrUpdate(
            TableNames.userDataFetches, dataFetchModel.toMap());
      }

      return true;
    } catch (e, s) {
      print("Data Repository: ${e.toString()} \n ${s.toString()}");
      return false;
    }
  }

  // NUR-5's on-demand single-card counterpart to syncReportCard6PlusDetails()
  // above. NUR-5's rows are already flat (no composite object to flatten, see
  // ApiReportCardNur5DataSource), and like the 6+ version, this deliberately
  // does NOT touch the reportCardNur5 incremental sync cursor.
  Future<bool> fetchReportCardNur5Detail(
    int reportCardId, {
    required String cookies,
    String? userId,
    String? accessToken,
  }) async {
    try {
      downloadingStatusStreamController?.add("Downloading report card details");
      var result = await _reportCardNur5DataSource.fetchData(
        cookies: cookies,
        params: ['reportCardId=$reportCardId'],
        userId: userId,
        accessToken: accessToken,
      );
      var rows = (result["dataList"] as List<BaseModel>)
          .map((c) => c.toSQLLiteMap())
          .toList();

      downloadingStatusStreamController?.add("Saving report card details to database");
      await _sqLiteDB.executeTransaction(TableNames.reportCardNur5Data, rows);
      return true;
    } catch (e, s) {
      print("Data Repository: ${e.toString()} \n ${s.toString()}");
      return false;
    }
  }

  DateTime getLatestDateTime(List<BaseModel> dateTimeList) {
    DateTime latestDateTime = dateTimeList.first.modDate.toUtc();
    // print("latestDateTime: $latestDateTime, latestDateTime in utc: ${latestDateTime.toUtc()}");
    for (var dateTime in dateTimeList) {
      var tmpMap = dateTime.toMap();
      // print(     "tmpMap: ${tmpMap['modifiedDate']}, dateTime.modDate: ${dateTime.modDate}, in utc: ${dateTime.modDate.toUtc()}");
      if (dateTime.modDate.compareTo(latestDateTime) > 0) {
        latestDateTime = dateTime.modDate.toUtc();
      }
    }
    return latestDateTime;
  }

  // Helper: Get the latest modifiedDate string directly (Lexicographical compare)
  String getLatestModifiedDateString(List<BaseModel> entityList) {
    if (entityList.isEmpty) return "";

    // Initialize with the first item's modifiedDate string
    // Casting to dynamic allows us to access the specific 'modifiedDate' field
    // present in DiaryModel, CorrespondenceModel, etc.
    String maxDate = (entityList.first as dynamic).modifiedDate ?? "";

    for (var entity in entityList) {
      String currentDate = (entity as dynamic).modifiedDate ?? "";
      // String comparison works for YYYY-MM-DD format
      // if (currentDate.compareTo(maxDate) > 0) {
      // print("Comparing maxDate: $maxDate with currentDate: $currentDate");
      if (maxDate.isEmpty || currentDate.isEmpty) continue;
      if (DateTime.parse(maxDate).isBefore(DateTime.parse(currentDate))) {
        maxDate = currentDate;
      }
    }
    return maxDate;
  }

  // Inside DataRepository class

  // 1. Get Unread Diary Count (Optimized SQL COUNT)
  Future<int> getUnreadDiaryCount({
    String? studentId,
    String? classId,
    List<String>? types,
    bool? isTimetable,
  }) async {
    List<String> filters = ["bRead = 0", "is_deleted = 0"];

    // ✅ Filter out ancient data from the badge counts
    filters.add("createdDate >= '${_getAcademicYearCutoff()}'");

    if (studentId != null) {
      filters.add("studentId = '$studentId'");
    }

    if (classId != null && classId.isNotEmpty) {
      filters.add(
          "(classId = '$classId' OR classId IS NULL OR classId = 'null' OR classId = '0')");
    }

    if (types != null && types.isNotEmpty) {
      String typesStr = types.map((t) => "'$t'").join(',');
      filters.add("diaryType IN ($typesStr)");
    }

    // If filtering for Timetable tab specifically
    if (isTimetable == true) {
      filters.add(
          " (COALESCE(title,'') LIKE '%timetable%' OR COALESCE(title,'') LIKE '%time table%') AND (attachment IS NOT NULL OR attachment2 IS NOT NULL)");
    }
// If filtering for Notices tab, exclude them so they don't double up!
    // COALESCE guards against a NULL title - see getDiaries() for why.
    //
    // ✅ FIX (2026-11-24): was excluding on the title match alone, not
    // mirroring the Timetable tab's actual inclusion condition above (title
    // match AND an attachment present). A general notice whose title
    // happens to mention "timetable" but has no attached file was excluded
    // here (assumed to belong under Timetable instead) while also failing
    // the Timetable tab's own attachment requirement - falling into a gap
    // where it was invisible and unopenable in every tab, yet still counted
    // in the overall unread badge with no way to ever clear it. Now only
    // excluded here if it would actually appear in Timetable.
    else if (isTimetable == false) {
      filters.add(
          " NOT ((COALESCE(title,'') LIKE '%timetable%' OR COALESCE(title,'') LIKE '%time table%') AND (attachment IS NOT NULL OR attachment2 IS NOT NULL))");
    }

    return await getTotalRowCountForTable(TableNames.diaries, filters);
  }

  // 2. Get Unread Correspondence Count (sum of unread messages, not thread count)
  Future<int> getUnreadCorrespondenceCount({String? studentId}) async {
    List<String> filters = ["bRead = 0", "is_deleted = 0"];

    // ✅ Filter out ancient data from the badge counts
    filters.add("modifiedDate >= '${_getAcademicYearCutoff()}'");

    if (studentId != null) {
      filters.add("studentId = '$studentId'");
    }

    // Sum numUnreadMessages rather than counting threads: a thread's bRead
    // flag only moves once per read/unread cycle, so a count of unread
    // threads stops changing after the first new message in an
    // already-unread thread, even though more messages keep arriving.
    var query =
        'SELECT SUM(numUnreadMessages) as total FROM ${TableNames.correspondences}';
    if (filters.isNotEmpty) {
      query += ' WHERE ${filters.join(" AND ")}';
    }
    final result = await _sqLiteDB.rawQuery(query);
    return result.isNotEmpty
        ? ((result.first['total'] as num?)?.toInt() ?? 0)
        : 0;
  }

  // Fetch Diaries with Filters & Pagination
  Future<List<DiaryModel>> getDiaries({
    String? studentId,
    String? classId, // ✅ ADD THIS
    List<String>? types,
    int limit = 100, // Default to 100
    int offset = 0, // Default to 0 (start)
    bool? isTimetable,
    String? searchQuery,
    bool unreadOnly = false,
    bool todayOnly = false,
  }) async {
    String whereClause = "is_deleted = 0";
    List<dynamic> whereArgs = [];

    // ✅ Restrict the UI list to the current academic year
    whereClause += " AND createdDate >= ?";
    whereArgs.add(_getAcademicYearCutoff());

    // Filter by Student
    if (studentId != null) {
      whereClause += " AND studentId = ?";
      whereArgs.add(studentId);
    }

    // ✅ Filter by Class (For Teachers/Staff)
    if (classId != null && classId.isNotEmpty) {
      // ✅ Show it if it belongs to the selected class, OR if it's a global notice (null/0)
      whereClause +=
          " AND (classId = ? OR classId IS NULL OR classId = 'null' OR classId = '0')";
      whereArgs.add(classId);
    }

    // Filter by Type (cw, hw, gn)
    if (types != null && types.isNotEmpty) {
      String placeholders = List.filled(types.length, '?').join(',');
      whereClause += " AND diaryType IN ($placeholders)";
      whereArgs.addAll(types);
    }

    // If filtering for Timetable tab specifically
    if (isTimetable == true) {
      whereClause +=
          " AND (COALESCE(title,'') LIKE '%timetable%' OR COALESCE(title,'') LIKE '%time table%') AND (attachment IS NOT NULL OR attachment2 IS NOT NULL)";
    }
// If filtering for Notices tab, exclude them so they don't double up!
    // COALESCE guards against a NULL title - "title LIKE ..." on NULL
    // evaluates to SQL NULL (not FALSE), which SQLite's WHERE clause treats
    // as excluding the row entirely, silently dropping untitled notices.
    //
    // ✅ FIX (2026-11-24): see getUnreadDiaryCount()'s identical fix - was
    // excluding on the title match alone instead of mirroring the Timetable
    // tab's actual inclusion condition (title match AND an attachment
    // present), leaving a "timetable"-titled notice with no attachment
    // invisible in every tab. Now only excluded here if it would actually
    // appear in Timetable.
    else if (isTimetable == false) {
      whereClause +=
          " AND NOT ((COALESCE(title,'') LIKE '%timetable%' OR COALESCE(title,'') LIKE '%time table%') AND (attachment IS NOT NULL OR attachment2 IS NOT NULL))";
    }

    // Search by subject, className, title, or details (full, untruncated
    // column - the substr() in the SELECT below only limits what's
    // returned for the preview, not what this WHERE clause can match
    // against).
    // ✅ FIX: subject and className were missing entirely - the list's
    // header line (e.g. "URDU - 1 Sapphire Gulshan") is built from those
    // two fields, not title, so searching "urdu" or "gulshan" found
    // nothing even though it's right there on screen. title holds the
    // diary's own heading (e.g. "Bla"), a separate field.
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause +=
          " AND (subject LIKE ? OR className LIKE ? OR title LIKE ? OR details LIKE ?)";
      final likeArg = '%${searchQuery.trim()}%';
      whereArgs.add(likeArg);
      whereArgs.add(likeArg);
      whereArgs.add(likeArg);
      whereArgs.add(likeArg);
    }

    if (unreadOnly) {
      whereClause += " AND bRead = 0";
    }

    // createdDate is the same field _buildItem() parses to decide whether a
    // row's date badge reads "TODAY" - matching that here keeps this filter
    // consistent with what the list already visually labels as today's.
    if (todayOnly) {
      whereClause += " AND createdDate LIKE ?";
      whereArgs.add('${DateFormat('yyyy-MM-dd').format(DateTime.now())}%');
    }

    // Order by date descending
    String orderBy = "diaryId DESC";

    // 1. Construct the raw query to support LIMIT and OFFSET safely
    // (Assuming your SQLiteDB.query wrapper doesn't expose limit/offset yet)
    // print("getDiaries() - SQL: $sql, whereArgs: $whereArgs");

    // 2. Execute using rawQuery to ensure arguments are bound correctly
    // We need to inject the whereArgs into the raw query placeholders manually
    // OR (safer) use the underlying sqflite DB object if accessible.
    // Given your SQLiteDB wrapper, rawQuery is the accessible route.

    // Since binding args with rawQuery '?' placeholders can be tricky with string manipulation,
    // let's use the SQLiteDB.db instance if possible, or simple string injection for the limit/offset
    // while keeping the WHERE clause secure.

    // Safer approach compatible with your wrapper:
    final db = await _sqLiteDB.database;
    // ✅ Truncate the raw-HTML `details` column via substr() instead of
    // selecting it in full: for a wide-scope role (e.g. a coordinator
    // covering 167 classes), the academic-year cutoff above barely narrows
    // the dataset (observed: 19,088 of ~19,100 total rows still match), so
    // SQLite's post-filter sort by diaryId was materializing the FULL
    // details blob (tens of KB each, observed) for thousands of candidate
    // rows just to throw away all but `limit` of them. Measured on a
    // synthetic 19k-row/50KB-blob table: full SELECT * cost ~2.45s CPU vs
    // ~0.55s for substr(details, 1, 300) vs ~0.02s excluding it entirely -
    // (100 chars, used below, costs even less)
    // this keeps the list's preview snippet while recovering most of that
    // difference. The diary detail screen gets the full details separately.
    final List<dynamic> limitOffsetArgs = [...whereArgs, limit, offset];
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT id, diaryId, studentId, classId, title, subject, diaryType,
             substr(details, 1, 100) AS details, className, dateDue,
             attachment, attachment2, bRead, createdDate, modifiedDate,
             dateSubmitted, is_deleted, bLocal
      FROM ${TableNames.diaries}
      WHERE $whereClause
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
      ''',
      limitOffsetArgs,
    );

    // print("getDiaries() - whereClause: $whereClause, whereArgs: $whereArgs, orderBy: $orderBy, limit: $limit, offset: $offset, maps length: ${maps.length}");

    return List.generate(maps.length, (i) {
      return DiaryModel.fromSQLLiteMap(maps[i]);
    });
  }

  // Fetch the full (untruncated) details for a single diary row by id.
  // getDiaries() above only returns a 300-char preview of this field for
  // list-screen performance - the detail screen calls this once it's
  // actually opened.
  Future<String?> getDiaryDetailsById(String id) async {
    final db = await _sqLiteDB.database;
    final List<Map<String, dynamic>> maps = await db.query(
      TableNames.diaries,
      columns: ['details'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['details'] as String?;
  }

  // Fetch Correspondences with Filters & Pagination
  Future<List<CorrespondenceModel>> getCorrespondences({
    String? studentId,
    int limit = 100,
    int offset = 0,
    String? searchQuery,
    bool unreadOnly = false,
    bool todayOnly = false,
  }) async {
    String whereClause = "is_deleted = 0";
    List<dynamic> whereArgs = [];

    // ✅ Restrict the UI list to the current academic year
    whereClause += " AND modifiedDate >= ?";
    whereArgs.add(_getAcademicYearCutoff());

    // Filter by Student
    if (studentId != null) {
      whereClause += " AND studentId = ?";
      whereArgs.add(studentId);
    }

    // Search by subject, the thread's last-message preview, or the
    // student/sender name shown as the list item's own label.
    // ✅ FIX: same bug class as diary search (see getDiaries()) -
    // studentName/senderName are what's actually displayed per row, but
    // weren't searchable, so e.g. searching a child's name found nothing.
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause +=
          " AND (subject LIKE ? OR message LIKE ? OR studentName LIKE ? OR senderName LIKE ?)";
      final likeArg = '%${searchQuery.trim()}%';
      whereArgs.add(likeArg);
      whereArgs.add(likeArg);
      whereArgs.add(likeArg);
      whereArgs.add(likeArg);
    }

    if (unreadOnly) {
      whereClause += " AND bRead = 0";
    }

    // modifiedDate is the structured/sortable date field (unlike `date`,
    // which is a display-formatted string like "EEE, dd/MM/yyyy hh:mm:ss a"
    // not directly comparable here).
    if (todayOnly) {
      whereClause += " AND modifiedDate LIKE ?";
      whereArgs.add('${DateFormat('yyyy-MM-dd').format(DateTime.now())}%');
    }

    // Order by date descending (newest first)
    // Assuming 'date' or 'modifiedDate' column.
    // Check your model: you use 'date' (display string) and 'modifiedDate' (ISO).
    // Best to sort by modifiedDate or id desc.
    String orderBy = "modifiedDate DESC"; // "id DESC";
    // print("getCorrespondences() whereClaseuse: $whereClause, whereArgs: $whereArgs, orderBy: $orderBy, limit: $limit, offset: $offset");
    final db = await _sqLiteDB.database;
    final List<Map<String, dynamic>> maps = await db.query(
      TableNames.correspondences,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) {
      return CorrespondenceModel.fromSQLLiteMap(maps[i]);
    });
  }

  // --- Report Cards (v9) ---

  Future<List<ReportCardListModel>> getReportCardsList() async {
    final db = await _sqLiteDB.database;
    final List<Map<String, dynamic>> maps = await db.query(
      TableNames.reportCardsList,
      where: "is_deleted = 0",
      orderBy: "studentName ASC",
    );
    return List.generate(
        maps.length, (i) => ReportCardListModel.fromSQLLiteMap(maps[i]));
  }

  Future<Map<String, dynamic>?> getReportCard6PlusHeader(int reportCardId) async {
    final db = await _sqLiteDB.database;
    final rows = await db.query(
      TableNames.reportCardHeader6Plus,
      where: "reportCardId = ?",
      whereArgs: [reportCardId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getReportCard6PlusMarks(
      int reportCardId) async {
    final db = await _sqLiteDB.database;
    return db.query(
      TableNames.reportCardMarks6Plus,
      where: "reportCardId = ?",
      whereArgs: [reportCardId],
      orderBy: "examTypeId ASC, subjectId ASC",
    );
  }

  Future<List<Map<String, dynamic>>> getReportCard6PlusSummary(
      int reportCardId) async {
    final db = await _sqLiteDB.database;
    return db.query(
      TableNames.reportCardSummary6Plus,
      where: "reportCardId = ?",
      whereArgs: [reportCardId],
      orderBy: "isAnnual ASC, examTypeId ASC",
    );
  }

  Future<List<Map<String, dynamic>>> getReportCardNur5Data(
      int reportCardId) async {
    final db = await _sqLiteDB.database;
    return db.query(
      TableNames.reportCardNur5Data,
      where: "reportCardId = ?",
      whereArgs: [reportCardId],
      orderBy: "examTypeId ASC, sortIndex ASC",
    );
  }

  // Only 'available' report cards count toward unread - the other states
  // (not_created/class_hidden/student_hidden/fee_defaulter) have nothing to
  // actually view, so badging them as "unread" would be misleading.
  Future<int> getUnreadReportCardCount({String? studentId}) async {
    final db = await _sqLiteDB.database;
    var where = "is_deleted = 0 AND state = 'available' AND bRead = 0";
    if (studentId != null) {
      where += " AND studentId = '$studentId'";
    }
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM ${TableNames.reportCardsList} WHERE $where",
    );
    return (result.first['c'] as int?) ?? 0;
  }

  // A report_card_available push can't carry the real row directly the way
  // diary/correspondence pushes do: the class-wide "App" button broadcasts
  // to a shared class topic, which can't embed a different correct
  // reportCardId per recipient, and even the per-student Save-button push
  // only nudges - so instead of a local insert from payload, every
  // report_card_available push (see push_notification_service.dart)
  // triggers this instead: a plain re-run of the same list-only sync
  // downloadAllData() already does, scoped to just this one entity so it
  // doesn't also hit Diary/Correspondence/etc. Cheap - getAPIReportCardList()
  // always does a full re-fetch anyway (see its own comment on why), there's
  // no incremental cursor to worry about missing here.
  Future<bool> syncReportCardsListOnly({
    required String cookies,
    String? userId,
    String? accessToken,
  }) async {
    return syncEntity(
      cookies,
      0,
      1000,
      _reportCardsListDataSource,
      FetchAction.reportCardsList,
      TableNames.reportCardsList,
      shouldFetchInBatches: true,
      userId: userId,
      accessToken: accessToken,
    );
  }

  // bRead lives directly on the backend's report_cards row (not an
  // app_notifications-backed row like diary/correspondence) - same two-step
  // pattern as markDiaryAsRead() either way: instant local update, then a
  // real server round-trip so the read status survives a reinstall/re-
  // sync/new device.
  Future<void> markReportCardAsRead(String studentId, String reportCardId,
      {AuthService? authService}) async {
    await _sqLiteDB.update(
      TableNames.reportCardsList,
      {'bRead': 1},
      'studentId = ?',
      [studentId],
    );

    if (authService != null) {
      await postDataToServer(
        authService.cookieValue,
        "markReportCardRead",
        jsonEncode({"reportCardId": reportCardId}),
        accessToken: authService.accessToken,
      );
    }
  }

  // --- ADD THESE METHODS TO DataRepository ---

  // 2. Fetch comments for a SPECIFIC diary
  // You'll need to import 'package:bla_flutter_app/models/diary_comments_model.dart';
  Future<List<DiaryCommentModel>> getDiaryComments(String diaryId) async {
    // The previous issue was likely missing the 'diaryId = ?' WHERE clause
    final List<Map<String, dynamic>> maps = await _sqLiteDB.query(
      TableNames.diariesComments,
      'diaryId = ? AND is_deleted = 0',
      [diaryId],
      orderBy: "id ASC", // Show oldest comments first
    );
    // print("getDiaryComments() - diaryId: $diaryId, SQL: SELECT * FROM ${TableNames.diariesComments} WHERE diaryId = '$diaryId' AND is_deleted = 0 ORDER BY createdDate ASC, maps length: ${maps.length}");

    return List.generate(maps.length, (i) {
      return DiaryCommentModel.fromSQLLiteMap(maps[i]);
    });
  }

  // --- Correspondence Methods ---

  // 1. Fetch Messages
  Future<List<Map<String, dynamic>>> getCorrespondenceMessages(
      String correspondenceId) async {
    // We use raw maps here to be safe, or you can create a specific model
    String sql = '''
      SELECT * FROM ${TableNames.correspondencesMessages} 
      WHERE correspondenceId = '$correspondenceId' AND is_deleted = 0
      ORDER BY id ASC
    ''';
    // print("getCorrespondenceMessages() - SQL: $sql");
    return await _sqLiteDB.rawQuery(sql);
  }

  Future<List<Map<String, dynamic>>> getAllDataFromTable(String tableName,
      {String? where, String? orderBy}) async {
    var query = "Select * from $tableName";
    if (where != null) {
      query += " where $where";
    }
    if (orderBy != null) {
      query += " order by $orderBy";
    }
    // print("getAllDataFromTable() - query: $query");
    var result = await _sqLiteDB.rawQuery(query);
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllDataFromQuery(String query) async {
    // print("getAllDataFromQuery() - query: $query");
    var result = await _sqLiteDB.rawQuery(query);
    return result;
  }

  // NOT a real reactive stream - see sqlite.dart's listenTableChanges() for
  // why. No longer called anywhere in the app as of 2026-10-12: diary.dart
  // and correspondence.dart's three former subscriptions to this were
  // removed as dead code (DataSyncService.stateStream and DashboardController
  // already provide genuine reactivity for all of their consumers). Kept
  // here, unused, in case a real per-table reactive stream is worth
  // building later - don't wire new consumers to it as-is.
  Stream<List<Map<String, dynamic>>> listenTableChanges(String tableName) {
    return _sqLiteDB.listenTableChanges("select * from $tableName");
  }

  Future<List<Map<String, dynamic>>> getUsers({
    String? userName,
  }) async {
    var query = '''SELECT * from users ''';

    // print("where: $where");
    if (userName != null) {
      query += " where userName='$userName'";
    }

    // print("getUsers() - query: $query");
    var result = await _sqLiteDB.rawQuery(query);
    return result;
  }

  // Fetch Contacts (Teachers/Admins) for Correspondence
  Future<List<Map<String, String>>> getContacts(
      {String? selectedStudentId}) async {
    String sqlContacts =
        "SELECT * FROM ${TableNames.contacts} WHERE is_deleted = 0";

    if (selectedStudentId != null && selectedStudentId.isNotEmpty) {
      sqlContacts += " AND (studentId = '$selectedStudentId')";
    }
    // print("getContacts() - selectedStudentId: $selectedStudentId, SQL: $sqlContacts");
    var contacts = await _sqLiteDB.rawQuery(sqlContacts);
    return contacts
        .map((e) => {
              'id': e['id'].toString(),
              'name': e['fullName'].toString(),
              'classId': e['classId']?.toString() ?? '', // ✅ New
              'studentId': e['studentId']?.toString() ?? '', // ✅ New
            })
        .toList();
  }

  // Fetch Classes for the Staff Dropdown
  Future<List<Map<String, String>>> getClasses() async {
    var classes = await _sqLiteDB
        .rawQuery("SELECT * FROM ${TableNames.classes} ORDER BY className ASC");
    return classes
        .map((e) => {
              'id': e['id'].toString(),
              'className': e['className'].toString(),
            })
        .toList();
  }

  Future<int> saveDataToLocal(
      String tableName, Map<String, dynamic> row) async {
    return await _sqLiteDB.insertOrUpdate(tableName, row);
  }

  // One-time cleanup (2026-11-13) for duplicate diary rows that predate the
  // id-alignment fix (push_notification_service.dart's _saveDiaryLocally()
  // now uses the server's real appUsersNotificationId instead of inventing
  // "{diaryId}-{studentId}"). A device that already received a diary via the
  // old scheme, then later real-synced the same diary under its real id,
  // ends up with two rows for the same (diaryId, studentId) - confirmed live
  // (see bug_push_delivery_confirmation_gap_2026_11_05 memory). Only ever
  // deletes a row when a real-id alternative for the same diaryId+studentId
  // already exists in the local table - never guesses when every row still
  // has the old invented id (i.e. no real sync has happened for that diary
  // yet), since there's nothing to safely prefer in that case. Staff/class-
  // scoped rows (studentId null/empty) are untouched - their id scheme was
  // already aligned by the 2026-10-02 fix and was never exposed to this bug.
  Future<int> dedupeDuplicateDiaries() async {
    final groups = await _sqLiteDB.rawQuery(
        "SELECT diaryId, studentId FROM ${TableNames.diaries} "
        "WHERE studentId IS NOT NULL AND studentId != '' "
        "GROUP BY diaryId, studentId HAVING COUNT(*) > 1");

    int totalDeleted = 0;
    for (final group in groups) {
      final diaryId = group['diaryId'];
      final studentId = group['studentId'];
      final rows = await _sqLiteDB.rawQuery(
          "SELECT id FROM ${TableNames.diaries} WHERE diaryId = '$diaryId' AND studentId = '$studentId'");
      final ids = rows.map((r) => r['id'].toString()).toList();

      // The real server id (app_users_notifications.id) is always a plain
      // integer; only the old invented scheme ever contains a hyphen.
      final hasRealId = ids.any((id) => !id.contains('-'));
      if (!hasRealId) continue;

      for (final id in ids) {
        if (id.contains('-')) {
          await _sqLiteDB.delete(TableNames.diaries, 'id = ?', [id]);
          totalDeleted++;
        }
      }
    }
    return totalDeleted;
  }

  dynamic updateDataToLocal(String tableName, Map<String, dynamic> row,
      String where, List<String> whereArgs) async {
    return await _sqLiteDB.update(tableName, row, where, whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql) async {
    return await _sqLiteDB.rawQuery(sql);
  }

  Future<int> rawInsert(String sql, List<String> args) async {
    return await _sqLiteDB.rawInsert(sql, args);
  }

  Future<int> rawUpdate(String sql, List<String> args) async {
    return await _sqLiteDB.rawUpdate(sql, args);
  }

  Future<int> deleteRowWithCondition(
      String tableName, String where, List<dynamic> whereArgs) async {
    return await _sqLiteDB.delete(tableName, where, whereArgs);
  }

  Future<Map<String, dynamic>> getDataFromServer(
    String cookies,
    String request,
  ) async {
    var res = await _apiClient.get(
      endPoint: request,
      cookies: cookies,
    );
    return res;
  }

  Future<Map<String, dynamic>> postDataToServer(
    String cookies,
    String endPoint,
    String body, {
    String? uploadFilename,
    String? accessToken,
  }) async {
    var dataMap = await _apiClient.post(
      endPoint: endPoint,
      body: body,
      cookies: cookies,
      uploadFilename: uploadFilename,
      accessToken: accessToken,
    );
    return dataMap;
  }

  Future<List<PostAPIQueueModel>?> uploadDataToServer(
    AuthService authService, {
    int? postAPIQueueId,
  }) async {
    //TODO: When we sync
    return await processPostAPIQueue(
      authService,
      postAPIQueueId: postAPIQueueId,
    );
  }

  Future<List<PostAPIQueueModel>> getPostAPIsData({
    int? postAPIQueueId,
  }) async {
    String where = "bCompleted=0";
    if (postAPIQueueId != null) where += " AND id=$postAPIQueueId";
    var data =
        (await getAllDataFromTable(TableNames.postApiQueue, where: where))
            .map((e) => PostAPIQueueModel.fromMap(e))
            .toList();
    return data;
  }

  Future<List<PostAPIQueueModel>?> processPostAPIQueue(
    AuthService authService, {
    int? postAPIQueueId,
  }) async {
    //Get all rows from table where bCompleted = 0
    List<PostAPIQueueModel> postAPIsList = await getPostAPIsData(
      postAPIQueueId: postAPIQueueId,
    );
    List<PostAPIQueueModel> postAPIsListToDelete = <PostAPIQueueModel>[];

    try {
      // The queue processor iterates the table sequentially, looking for pending requests. It finds the saveColor entry
      int i = 0;
      for (i = 0; i < postAPIsList.length; i++) {
        var queueItem = postAPIsList[i];

        if (queueItem.method == "GET") {
          await getDataFromServer(authService.cookieValue, queueItem.request);
        } else {
          //Splitting into endpoint and body json where # is the split character stored in the table
          List<String> splittedRequest = []; // queueItem.request.split("#");
          var length = queueItem.request.indexOf("#");
          // print("length: $length, request: ${queueItem.request}");
          if (length == -1) {
            // If there is no # in the request, we assume the whole request is the endpoint
            splittedRequest.add(queueItem.request);
            splittedRequest.add("{}");
          } else {
            // Normal case where # is in the middle
            splittedRequest.add(queueItem.request.substring(0, length));
            splittedRequest.add(queueItem.request.substring(length + 1));
          }
          // print("POST URL: ${splittedRequest.first}, post request: ${splittedRequest.last}");
          //Posting data to server
          var dataMap = (await postDataToServer(
            authService.cookieValue,
            splittedRequest.first,
            splittedRequest.last,
            uploadFilename: queueItem.uploadFilename,
          ));

          // print("response from postDataToServer(): ${dataMap.toString()}");
          PostAPIEntityNames entityName = queueItem.entity;
          String idColumnName = PostAPIQueueModel.getIdTag(entityName);
          // print("entityName: ${entityName}, idColumnName: ${idColumnName}");

          //Storing serverId received from server for the inserted row
          int serverId = (dataMap.isNotEmpty &&
                  (dataMap['data'] != null && dataMap['data'].isNotEmpty))
              ? dataMap['data'].first[idColumnName]
              : 0;
          queueItem.serverEntityId = serverId;
        }

        //Marking row as complete
        queueItem.bCompleted = true;

        // Update the table
        await updatePostAPIQueueData(queueItem);

        if (queueItem.method != "GET") {
          //Add postAPI item to deleting data
          postAPIsListToDelete.add(queueItem);

          String tableNameToDelete =
              PostAPIQueueModel.getEntityTableName(queueItem.action);
          String deleteCriteria =
              "${PostAPIQueueModel.getTableEntityColumn(queueItem.entity)} = ? AND bLocal = ?";
          // print("tableNameToDelete: $tableNameToDelete, deleteCriteria: $deleteCriteria, localEntityId: ${queueItem.localEntityId}, queueItem.bCompleted: ${queueItem.bCompleted}");
          if (tableNameToDelete.isNotEmpty) {
            //Delete the local color entry from DB
            await _sqLiteDB.delete(
              tableNameToDelete,
              deleteCriteria,
              [
                queueItem.localEntityId,
                queueItem.bCompleted.toInt(),
              ],
            );
          }
          //Iterating through all the following rows and updating the placeholders
          if (queueItem.urlPlaceholder != null) {
            for (int j = i; j < postAPIsList.length; j++) {
              var item = postAPIsList[j];
              // Pattern pattern = "{${queueItem.entity.name}:${queueItem.localEntityId}}";
              if (queueItem.urlPlaceholder != null) {
                if (queueItem.urlPlaceholder!.isNotEmpty) {
                  Pattern pattern = queueItem.urlPlaceholder!;
                  String replacingString = "${queueItem.serverEntityId}";
                  item.request =
                      item.request.replaceAll(pattern, replacingString);
                }
              }
              // print(item.request);
            }
          }
        }
      }

      // print(postAPIsList.toString());

      // //Delete the local color entry from DB
      // if (data.isNotEmpty) {
      //   var deletedId = await _sqLiteDB.delete(TableNames.colors,
      //       "colorId = ? AND bLocal = ?", [data.first.localEntityId, 1]);
      // }

      return postAPIsListToDelete;
    } catch (e, s) {
      print(
          "processPostAPIQueue exception - $classLogName ${e.toString()}, trace: {$s.toString()}");

      // Updating the records which are not completed
      for (var queueItem in postAPIsList) {
        if (!queueItem.bCompleted) {
          await updatePostAPIQueueData(queueItem);
        }
      }

      return null;
    }
  }

  Future<int> deletePostAPIData(PostAPIQueueModel queueItem) async {
    //Delete the local color entry from DB
    var tableNameToDelete =
        PostAPIQueueModel.getEntityTableName(queueItem.action);
    var deletedId = 0;
    if (tableNameToDelete.isNotEmpty) {
      deletedId = await _sqLiteDB.delete(
        tableNameToDelete,
        "${PostAPIQueueModel.getTableIdTag(queueItem.entity)} = ? AND bLocal = ?",
        [
          queueItem.localEntityId,
          queueItem.bCompleted.toInt(),
        ],
      );
    }
    return deletedId;
  }

  String createPaginationSQL(String sourceTable, List<String> filterParams,
      int offset, int limit, List<String>? columnsToFetch,
      {String sortClause = ""}) {
    final StringBuffer sql = StringBuffer();
    sql.write('SELECT ');
    if (columnsToFetch != null && columnsToFetch.isNotEmpty) {
      sql.write(columnsToFetch.join(', '));
    } else {
      sql.write('*');
    }
    sql.write(' FROM $sourceTable');

    if (filterParams.isNotEmpty) {
      sql.write(' WHERE ');
      final List<String> conditions = filterParams;
      // filterParams.forEach((key, value) {
      //   conditions.add('$key = ?');
      // });
      sql.write(conditions.join(' AND '));
    }

    if (sortClause.isNotEmpty) {
      sql.write(" ORDER BY $sortClause");
    }

    sql.write(' LIMIT $limit OFFSET $offset');
    return sql.toString();
  }

  Future<int> getTotalRowCountForTable(
      String tableName, List<String> filters) async {
    var query = 'SELECT COUNT(*) as count FROM $tableName';
    if (filters.isNotEmpty) {
      query += (" WHERE ${filters.join(" AND ")}");
    }
    // print("getTotalRowCountForTable() - query: $query");
    final List<Map<String, dynamic>> result = await _sqLiteDB.rawQuery(query);
    return result.isNotEmpty ? result.first['count'] : 0;
  }

  Future<List<Map<String, dynamic>>> runRawQuery(String sqlQuery) async {
    return await _sqLiteDB.rawQuery(sqlQuery);
  }

  Future<void> updatePostAPIQueueData(PostAPIQueueModel data) async {
    //Updating example queue data into post_api_queue table
    await saveDataToLocal(TableNames.postApiQueue, data.toMap());
    // print("$classLogName update postQueue item at id=$id");
  }

  PostAPIQueueModel composeQueueItem({
    required PostAPIEntityNames entityName,
    required PostAPIActions action,
    required String request,
    required int localEntityId,
    required int? serverEntityId,
    bool? bCompleted,
    bool shouldAddPlaceholder = true,
    String? urlPlaceholder,
    String? uploadFilename,
    String? method,
  }) {
    return PostAPIQueueModel(
      entity: entityName,
      action: action,
      urlPlaceholder: urlPlaceholder ??
          (shouldAddPlaceholder ? "{${entityName.name}:$localEntityId}" : null),
      request: request,
      localEntityId: localEntityId,
      serverEntityId: serverEntityId,
      bCompleted: bCompleted ?? false,
      uploadFilename: uploadFilename,
      method: method,
    );
  }

  Future<String> getPlaceHolderId(
    PostAPIEntityNames entityName,
    int idValue, {
    PostAPIActions? action,
    String? tableName,
    String? primaryKeyColumn,
  }) async {
    String res = idValue.toString();
    try {
      if (idValue > 0) {
        tableName ??= PostAPIQueueModel.getTableName(entityName);
        primaryKeyColumn ??= PostAPIQueueModel.getTableIdTag(entityName);
        // primaryKeyColumn = PostAPIQueueModel.getTableEntityColumn(entityName);
        String sql = '''select api.* from $tableName 
        inner join post_api_queue api on (api.localEntityId = $tableName.$primaryKeyColumn and $tableName.bLocal = 1)
        where api.bCompleted = 0 
        and api.localEntityId = $idValue
        and api.entity = '${entityName.name}' ''';

        /*String sql = '''select api.* 
            from post_api_queue api 
            where api.bCompleted = 0 
            and api.entity = '${entityName.name}'
            and api.localEntityId = $idValue''';*/
        if (action != null) {
          sql += " and api.action = '${action.name}'";
        }
        List<Map<String, dynamic>> listMap = await getAllDataFromQuery(sql);
        // print("getPlaceHolderId() - sql: $sql");
        if (listMap.isNotEmpty) {
          res = listMap.first['url'].toString();
        }
      }
    } catch (e, s) {
      print(
          "error in DataRepository::getPlaceHolderId() - ${e.toString()}, trace: ${s.toString()}");
    }
    return res;
  }

  /// Queues a request and attempts immediate sync if AuthService is provided
  Future<bool> queuePostApi({
    required PostAPIEntityNames entity,
    required PostAPIActions action,
    required String endpoint,
    required Map<String, dynamic> bodyMap,
    required int localId,
    AuthService? authService, // Pass this to trigger immediate upload
  }) async {
    try {
      // 1. Construct Request String (Endpoint # JSON Body)
      String jsonBody = jsonEncode(bodyMap);
      String request = "$endpoint#$jsonBody";

      // 2. Create Queue Item
      // Note: We use 0 as serverEntityId initially.
      var queueItem = composeQueueItem(
        entityName: entity,
        action: action,
        request: request,
        localEntityId: localId,
        serverEntityId: 0,
        bCompleted: false,
      );

      // 3. Save to SQLite (Persistence)
      await saveDataToLocal(TableNames.postApiQueue, queueItem.toMap());
      // print("$classLogName Queued $entity $action (LocalID: $localId)");

      // 4. Try Immediate Sync (if Auth & Internet available)
      if (authService != null) {
        bool isOnline = await checkInternetAvailability();
        if (isOnline) {
          // print("$classLogName Attempting immediate upload...");
          await uploadDataToServer(authService);
          return true; // Sent (or at least attempted)
        }
      }
      return false; // Just queued
    } catch (e) {
      print("$classLogName queuePostApi Error: $e");
      return false;
    }
  }

/*
// 1. Mark a diary entry as read
  Future<void> markDiaryAsRead(String diaryId) async {
    await _sqLiteDB.update(
      TableNames.diaries,
      {'bRead': 1}, // Update bRead to 1 (true)
      'diaryId = ?', // Where diaryId matches
      [diaryId],
    );
  }
*/
  // -------------------------
  // --- 1. MARK DIARY READ ---
  // -------------------------
  Future<void> markDiaryAsRead(String diaryId,
      {AuthService? authService, String? userId, String? id}) async {
    // 1. Local Update (Instant UI Feedback)
    await _sqLiteDB.update(
      TableNames.diaries,
      {'bRead': 1},
      'diaryId = ?',
      [diaryId],
    );

    if (authService != null) {
      // 3. Immediate Server Fetch (Optional)
      await postDataToServer(
        authService.cookieValue,
        "readNotification",
        jsonEncode({
          "appUserNotificationId": id,
          "id": id,
          "diaryId": diaryId,
          "userId": authService.userId ?? "",
        }),
        accessToken: authService.accessToken,
      );
      // print("markDiaryAsRead() - immediate fetch response: ${res.toString()}");
    }
  }

  // ---------------------------------
  // --- 2. MARK CORRESPONDENCE READ ---
  // ---------------------------------
  Future<void> markCorrespondenceAsRead(String id,
      {AuthService? authService, String? userId}) async {
    // 1. Local Update
    await _sqLiteDB.update(
      TableNames.correspondences,
      {'bRead': 1},
      'id = ?',
      [id],
    );

    // 1. Local Update
    await _sqLiteDB.rawUpdate(
      "UPDATE ${TableNames.correspondences} SET numUnreadMessages = 0 WHERE id = ?",
      [id],
    );

    if (authService != null) {
      await postDataToServer(
        authService.cookieValue,
        "readNotification",
        jsonEncode({
          "appUserNotificationId": id,
          "id": id,
          "correspondenceId": id,
          "userId": authService.userId ?? "",
        }),
        accessToken: authService.accessToken,
      );
      // print("markCorrespondenceAsRead() - immediate fetch response: ${res.toString()}");
    }
/*
    // 2. Queue Server Update
    await queuePostApi(
      entity: PostAPIEntityNames.correspondence,
      action: PostAPIActions.update,
      endpoint: "apiSetCorrespondenceRead", // CHECK PHP ENDPOINT NAME
      bodyMap: {"correspondenceId": id, "userId": userId ?? "", "bRead": 1},
      localId: int.tryParse(id) ?? 0,
      authService: authService,
    );
    */
  }

  // ---------------------------------
  // --- 2b. CLOSE CORRESPONDENCE ---
  // ---------------------------------
  // Either party (teacher or parent) can close a conversation - matches the
  // backend's existing endCorrespondence endpoint (classes/API.class.php),
  // which was already built but never wired up to the Flutter "CLOSE
  // CONVERSATION" button. Local-first like markCorrespondenceAsRead() above,
  // so the list/detail screen reflects "closed" immediately rather than
  // waiting on a round trip.
  Future<void> closeCorrespondence(String id,
      {required AuthService authService}) async {
    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    await _sqLiteDB.update(
      TableNames.correspondences,
      {'dateEnded': nowStr},
      'id = ?',
      [id],
    );

    // ✅ FIX: endCorrespondence reads appCorrespondenceId from the query
    // string (restapi.php's 'params' registration), not the JSON body -
    // confirmed live via curl: posting it in the body (matching
    // markCorrespondenceAsRead()'s readNotification convention) got back
    // "Param 'appCorrespondenceId' cannot be empty!" every time. postDataToServer()
    // just concatenates `endPoint` straight into the URL
    // (api_client.dart's post(): '...?endpoint=$endPoint&accessToken=...'),
    // so appending it there is the correct fix, not a workaround.
    await postDataToServer(
      authService.cookieValue,
      "endCorrespondence&appCorrespondenceId=$id",
      jsonEncode({}),
      accessToken: authService.accessToken,
    );
  }

  // ---------------------------------
  // --- 3. ADD NEW CORRESPONDENCE ---
  // ---------------------------------
  Future<Map<String, dynamic>> addNewCorrespondence({
    required String subject,
    required String message,
    required List<String> recipientIds,
    required String studentId,
    required String studentName, // ✅ Add this
    required AuthService authService,
    String senderName = "Me",
  }) async {
    var res = await postDataToServer(
      authService.cookieValue,
      "startCorrespondence",
      jsonEncode({
        "year": DateTime.now().year,
        "title": subject,
        "message": message,
        "contactId": recipientIds.join(","),
        "studentId": studentId,
      }),
      accessToken: authService.accessToken,
    );

    if (res.isNotEmpty && res['success'] == true) {
      try {
        int newCorrId = 0;
        if (res['data'] != null && res['data']['appCorrespondenceId'] != null) {
          newCorrId = int.parse(res['data']['appCorrespondenceId'].toString());
        }

        if (newCorrId > 0) {
          // Clean time format without milliseconds
          String formattedDate =
              DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

          // 1. Insert Parent Thread
          await saveDataToLocal(TableNames.correspondences, {
            'id': newCorrId,
            'studentId': studentId,
            'studentName': studentName, // ✅ Added student name
            'subject': subject,
            'message': message,
            // ✅ FIX: was missing the time component entirely ("Sat,
            // 03/10/2026" with no timestamp), unlike every other date
            // field in this app - matches the format the push-received
            // path now uses (see formatLocalDisplayDate() in helpers.dart).
            'date': DateFormat('EEE, dd/MM/yyyy hh:mm:ss a')
                .format(DateTime.now()),
            'senderName': senderName,
            'contactName': "Teacher",
            'bRead': 1,
            'modifiedDate': formattedDate, // ✅ Clean format
            'is_deleted': 0,
            'bLocal': 0 // ✅ Set to 0 (Already synced)
          });

          // 2. ✅ CRITICAL: Insert the First Message!
          int newMsgId = 0;
          if (res['data']['appCorrespondenceMessageId'] != null) {
            newMsgId =
                int.parse(res['data']['appCorrespondenceMessageId'].toString());
          } else {
            newMsgId = DateTime.now().millisecondsSinceEpoch; // Fallback
          }

          await saveDataToLocal(TableNames.correspondencesMessages, {
            'id': newMsgId,
            'correspondenceId': newCorrId,
            'senderId': authService.userId,
            'senderName': senderName,
            'message': message,
            'date': DateFormat('EEE, dd/MM/yyyy').format(DateTime.now()),
            'createdDate': formattedDate, // ✅ Clean format
            'modifiedDate': formattedDate, // ✅ Clean format
            'is_deleted': 0,
            'bLocal': 0 // ✅ Set to 0
          });
        }
      } catch (e) {
        print("❌ Error saving new correspondence locally: $e");
      }
    }
    return res;
  }

  // ---------------------------
  // --- 4. ADD DIARY COMMENT ---
  // ---------------------------
  Future<Map<String, dynamic>?> addDiaryComment({
    required String diaryId,
    required String comment,
    required AuthService authService,
    String senderName = "Me", // ✅ Add this to display immediately
  }) async {
    // 1. Send to Server
    var res = await postDataToServer(
      authService.cookieValue,
      "sendComment",
      jsonEncode({"appDiaryId": diaryId, "message": comment}),
      accessToken: authService.accessToken,
    );

    // print("addDiaryComment response: ${res.toString()}");

    // 2. ✅ SAVE LOCALLY (If successful)
    if (res.isNotEmpty && res['success'] == true) {
      try {
        int newId = 0;
        if (res['data'] != null && res['data']['appDiaryCommentId'] != null) {
          newId = int.parse(res['data']['appDiaryCommentId'].toString());
        } else {
          newId = DateTime.now().millisecondsSinceEpoch;
        }

        String formattedDate =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

        await saveDataToLocal(TableNames.diariesComments, {
          'id': newId,
          'diaryId': diaryId,
          'senderId': authService.userId,
          'senderName': senderName,
          'message': comment,
          'createdDate': formattedDate, // ✅ Clean format
          'modifiedDate': formattedDate, // ✅ Added modifiedDate
          'is_deleted': 0,
          'bLocal': 0 // ✅ Set to 0
        });
      } catch (e) {}
    }

    return res;
  }

/*// 2. Send Reply (This usually goes to a Sync Queue)
  Future<void> sendCorrespondenceReply(
      String correspondenceId, String message, String userId) async {
    // 1. Save locally first for instant UI update
    await _sqLiteDB.insertOrUpdate(TableNames.correspondencesMessages, {
      'correspondenceId': correspondenceId,
      'message': message,
      'senderId': userId, // Assuming we store this to know it's "Me"
      'createdDate': DateTime.now().toString(), // ISO String
      'bLocal': 1, // Mark as local so sync service picks it up
      'is_deleted': 0
    });

    // 2. TODO: Add to PostAPIQueue for server sync (We can do this later)
  } */

  // ---------------------------------
  // --- 4. SEND CORRESPONDENCE REPLY ---
  // ---------------------------------
  Future<Map<String, dynamic>> sendCorrespondenceReply({
    required String correspondenceId,
    required String message,
    required AuthService authService,
    String? userId,
    String senderName = "Me", // ✅ Added senderName
  }) async {
    // 1. Send to Server First
    var res = await postDataToServer(
      authService.cookieValue,
      "sendMessage",
      jsonEncode({"appCorrespondenceId": correspondenceId, "message": message}),
      accessToken: authService.accessToken,
    );
    // print("response from sendCorrespondenceReply(): ${res.toString()}");

    // 2. ✅ Save locally AFTER success
    if (res.isNotEmpty && res['success'] == true) {
      try {
        int newMsgId = 0;
        // Looking at your previous Postman tests, the ID usually comes back in 'appCorrespondenceMessageId'
        if (res['data'] != null &&
            res['data']['appCorrespondenceMessageId'] != null) {
          newMsgId =
              int.parse(res['data']['appCorrespondenceMessageId'].toString());
        } else {
          newMsgId = DateTime.now().millisecondsSinceEpoch; // Fallback
        }

        String formattedDate =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

        // Insert the actual message
        await saveDataToLocal(TableNames.correspondencesMessages, {
          'id': newMsgId,
          'correspondenceId': correspondenceId,
          'senderId': userId,
          'senderName': senderName, // ✅ Now populated
          'message': message,
          // ✅ FIX: was missing the time component (see addNewCorrespondence()
          // above for the same fix and why).
          'date': DateFormat('EEE, dd/MM/yyyy hh:mm:ss a').format(
              DateTime.now()), // ✅ Added
          'createdDate': formattedDate, // ✅ Clean format
          'modifiedDate': formattedDate, // ✅ Clean format
          'is_deleted': 0,
          'bLocal': 0 // ✅ Set to 0
        });

        // ✅ Bonus: Update the parent thread so the Dashboard list shows the latest preview!
        await rawUpdate(
            "UPDATE ${TableNames.correspondences} SET message = ?, modifiedDate = ? WHERE id = ?",
            [message, formattedDate, correspondenceId]);
      } catch (e) {
        print("❌ Error saving reply locally: $e");
      }
    }

    return res;
  }

  // ---------------------------------
  // --- 4. SEND CORRESPONDENCE REPLY ---
  // ---------------------------------
  Future<Map<String, dynamic>> savePassword({
    required String password,
    required AuthService authService,
    String? id,
  }) async {
    try {
      // 1. Send to Server First
      var res = await postDataToServer(
        authService.cookieValue,
        "saveUserInfo",
        jsonEncode({"password": password, "id": id ?? authService.userId}),
        accessToken: authService.accessToken,
      );
      print("response from savePassword(): ${res.toString()}");
      return res;
    } catch (e) {
      print("❌ Error in savePassword(): $e");
      return {"success": false, "message": e.toString()};
    }
  }

  // ---------------------------------
  // --- UPDATE DEVICE FCM TOKEN ---
  // ---------------------------------
  Future<void> updateDeviceToken({
    required String fcmToken,
    required String userId,
    required String deviceId, // ✅ Add this
    required AuthService authService,
  }) async {
    try {
      // print("Updating device token for userId: $userId, deviceId: $deviceId, fcmToken: $fcmToken");
      await postDataToServer(
        authService.cookieValue,
        "updateDeviceToken",
        jsonEncode({
          "userId": userId,
          "deviceToken": fcmToken,
          "deviceId": deviceId, // ✅ Pass it to PHP
          // ✅ FIX: was hardcoded to "android" - harmless while iOS wasn't
          // in use, but would have mislabeled every iPhone registration in
          // user_fcm_tokens once it was.
          "platform": Platform.isIOS ? "ios" : "android",
        }),
        accessToken: authService.accessToken,
      );
    } catch (e) {
      print("❌ Error updating device token: $e");
    }
  }

  // ---------------------------------
  // --- UPDATE DEVICE FCM TOKEN ---
  // ---------------------------------
  Future<void> removeDeviceTokenFromServer({
    required String fcmToken,
    required String userId,
    required AuthService authService,
  }) async {
    try {
      await postDataToServer(
        authService.cookieValue,
        "removeDeviceToken",
        jsonEncode({
          "deviceToken": fcmToken,
          "userId": userId,
        }),
        accessToken: authService.accessToken,
      );
    } catch (e) {
      print("❌ Error removing device token: $e");
    }
  }

  Future<PostAPIQueueModel?> getPlaceHolder({
    int? id,
    int? localEntityId,
    String? entity,
  }) async {
    PostAPIQueueModel? res;
    try {
      String whereClause = '';
      if (id != null && id > 0) whereClause = '''where id = $id''';
      if (localEntityId != null && localEntityId > 0 && entity != null) {
        String urlPlaceholder = '';
        switch (entity) {
          case "color":
            urlPlaceholder = "{color:$localEntityId}";
            break;
          case "formula":
            urlPlaceholder = "{formula:$localEntityId}";
            break;
          case "targetRead":
            urlPlaceholder = "{targetRead:$localEntityId}";
            break;
          case "sampleRead":
          case "colorRead":
          case "read":
            urlPlaceholder = "{sampleRead:$localEntityId}";
            break;
          case "formulaSampleRead":
          case "formulaRead":
            urlPlaceholder = "{formulaSampleRead:$localEntityId}";
            break;
          case "salesOrder":
            urlPlaceholder = "{salesOrder:$localEntityId}";
            break;
          case "job":
            urlPlaceholder = "{job:$localEntityId}";
            break;
        }
        whereClause =
            "where localEntityId = $localEntityId and url = '$urlPlaceholder'";
      }
      String sql = "select * from post_api_queue $whereClause";

      List<Map<String, dynamic>> listMap = await getAllDataFromQuery(sql);
      res =
          listMap.isNotEmpty ? PostAPIQueueModel.fromMap(listMap.first) : null;
      // print("getPlaceHolder() - sql: $sql");
      // print("getPlaceHolder() - res: ${listMap.first.toString()}");
    } catch (e, s) {
      print(
          "error in DataRepository::getPlaceHolderById() - ${e.toString()}, trace: ${s.toString()}");
    }
    return res;
  }

  Future<int> getPlaceHolderServerEntityId({
    int? id,
    int? localEntityId,
    String? entity,
  }) async {
    try {
      PostAPIQueueModel? res = getPlaceHolder(
        id: id,
        localEntityId: localEntityId,
        entity: entity,
      ) as PostAPIQueueModel?;
      if (res != null) {
        return res.serverEntityId ?? 0;
      }
    } catch (e, s) {
      print(
          "error in DataRepository::getPlaceHolderById() - ${e.toString()}, trace: ${s.toString()}");
    }
    return 0;
  }

  // ✅ ACADEMIC YEAR CUTOFF HELPER
  String _getAcademicYearCutoff() {
    final now = DateTime.now();

    // If before August (month < 8), the academic year started last year.
    // TODO - Samee change 9 to 8 for August cutoff
    final startYear = now.month < 8 ? now.year - 1 : now.year;
    // Formatted for standard SQLite datetime comparison
    return '$startYear-06-01 00:00:00';
  }
}
