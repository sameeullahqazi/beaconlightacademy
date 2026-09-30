import 'dart:async'; // Import this
import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/data/repositories/data_repository.dart';
import 'package:bla_flutter_app/services/data_sync_service.dart'; // Import this
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardController with ChangeNotifier {
  final LoginController _loginController;

  // STATE
  String? _selectedStudentId;
  int _unreadDiaries = 0;
  int _unreadCorrespondences = 0;

  bool _isDisposed = false;
  StreamSubscription? _syncSubscription; // Subscription handle

  // GETTERS
  String? get selectedStudentId => _selectedStudentId;
  int get unreadDiaries => _unreadDiaries;
  int get unreadCorrespondences => _unreadCorrespondences;
  int get totalUnread => _unreadDiaries + _unreadCorrespondences;

  DashboardController(this._loginController) {
    // 1. Initialize counts immediately on creation
    refreshCounts();

    // 2. Listen to the Sync Service!
    // This ensures that WHENEVER sync finishes (manual or auto), we update.
    _syncSubscription = DataSyncService.instance.stateStream.listen((state) {
      if (state == SyncState.synced) {
        // Add a small delay to ensure DB writes are fully committed
        Future.delayed(const Duration(seconds: 1), () {
          refreshCounts();
        });
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _syncSubscription?.cancel(); // 3. Clean up listener
    super.dispose();
  }

  void selectStudent(String? studentId) {
    _selectedStudentId = studentId;
    refreshCounts();
    if (!_isDisposed) notifyListeners();
  }

  Future<void> refreshCounts() async {
    // Safety: If login controller is disposing, repo might be null
    DataRepository? repo = _loginController.getDataRepository();
    if (repo == null) return;

    try {
      final diariesCount =
          await repo.getUnreadDiaryCount(studentId: _selectedStudentId);
      final correspondencesCount = await repo.getUnreadCorrespondenceCount(
          studentId: _selectedStudentId);

      if (_isDisposed) return;

      _unreadDiaries = diariesCount;
      _unreadCorrespondences = correspondencesCount;
      notifyListeners();

      // The OS icon badge always reflects the TOTAL across every student /
      // the whole account, not whichever child happens to be selected in
      // the dashboard right now - mirrors how WhatsApp's badge counts
      // everything, not just the open chat.
      final overallDiaries = await repo.getUnreadDiaryCount();
      final overallCorrespondences = await repo.getUnreadCorrespondenceCount();
      await _syncAppIconBadge(overallDiaries + overallCorrespondences);
    } catch (e) {
      print("Error refreshing counts: $e");
    }
  }

  Future<void> _syncAppIconBadge(int total) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('app_icon_badge_count', total);
      if (total > 0) {
        await FlutterAppBadger.updateBadgeCount(total);
      } else {
        await FlutterAppBadger.removeBadge();
      }
    } catch (_) {
      // Badge plugin failures shouldn't break count refreshing.
    }
  }
}
