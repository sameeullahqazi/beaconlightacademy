import 'package:bla_flutter_app/controllers/dashboard_controller.dart';
import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/models/correspondence_model.dart';
import 'package:bla_flutter_app/screens/correspondence_details.dart';
import 'package:bla_flutter_app/screens/new_correspondence.dart';
import 'package:bla_flutter_app/themes/constants.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:bla_flutter_app/components/app_header.dart';
import 'package:bla_flutter_app/components/app_footer.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:bla_flutter_app/services/data_sync_service.dart';
import 'package:bla_flutter_app/models/data_fetches_model.dart';

// --- PART 1: THE MAIN SCREEN SHELL ---
class CorrespondenceScreen extends StatefulWidget {
  const CorrespondenceScreen({super.key});

  @override
  State<CorrespondenceScreen> createState() => _CorrespondenceScreenState();
}

class _CorrespondenceScreenState extends State<CorrespondenceScreen> {
  String? _currentStudentId;

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _todayOnly = false;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    final dashCtrl = Provider.of<DashboardController>(context, listen: false);
    _currentStudentId = dashCtrl.selectedStudentId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _isSearching = false;
        _searchQuery = '';
        _searchController.clear();
        _todayOnly = false;
        _unreadOnly = false;
      } else {
        _isSearching = true;
      }
    });
  }

  // Debounced so CorrespondenceList doesn't re-query on every keystroke.
  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _searchQuery = val);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardController>(
      builder: (context, dashboardCtrl, child) {
        if (_currentStudentId != dashboardCtrl.selectedStudentId) {
          _currentStudentId = dashboardCtrl.selectedStudentId;
        }

        return Scaffold(
          appBar: AppHeader(
            // Not all-caps - that was truncating to "CORRESPONDEN..." at
            // this header's width.
            title: "Correspondences",
            showBackButton: true,
            backgroundColor: AppColors.purplePrimary,
            notificationCount: dashboardCtrl.totalUnread,
            showSearch: true,
            isSearching: _isSearching,
            searchController: _searchController,
            onSearchToggle: _toggleSearch,
            onSearchChanged: _onSearchChanged,
            showFilter: _isSearching,
            todayOnly: _todayOnly,
            unreadOnly: _unreadOnly,
            onTodayChanged: (val) => setState(() => _todayOnly = val),
            onUnreadChanged: (val) => setState(() => _unreadOnly = val),
          ),
          body: Stack(
            children: [
              CorrespondenceList(
                studentId:
                    _currentStudentId, // ✅ Removed the totalUnread trap!
                searchQuery: _searchQuery,
                todayOnly: _todayOnly,
                unreadOnly: _unreadOnly,
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NewCorrespondenceScreen()),
                    );
                  },
                  backgroundColor: AppColors.purplePrimary,
                  heroTag: "new_correspondence_btn",
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
          bottomNavigationBar: const AppFooter(),
        );
      },
    );
  }
}

// --- PART 2: THE REUSABLE LIST WIDGET ---
class CorrespondenceList extends StatefulWidget {
  final String? studentId;
  final String searchQuery;
  final bool todayOnly;
  final bool unreadOnly;

  const CorrespondenceList(
      {super.key,
      required this.studentId,
      this.searchQuery = '',
      this.todayOnly = false,
      this.unreadOnly = false}); // ✅ Cleaned up constructor

  @override
  State<CorrespondenceList> createState() => _CorrespondenceListState();
}

class _CorrespondenceListState extends State<CorrespondenceList> {
  final ScrollController _scrollController = ScrollController();
  List<CorrespondenceModel> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _firstLimit = 25;
  final int _nextLimit = 25;
  StreamSubscription? _syncSubscription;
  bool _isFirstBuild = true;

  DashboardController? _dashCtrl; // ✅ 1. Add this controller reference

  @override
  void initState() {
    super.initState();
    _loadData(init: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.9) {
        _loadData();
      }
    });

    _syncSubscription = DataSyncService.instance.stateStream.listen((state) {
      if (state == SyncState.synced) {
        if (mounted) {
          // ✅ Background sync finished? Refresh the list silently without flickering the UI!
          _loadData(init: true, silent: true);
        }
      }
    });

    // ✅ 2. THE BULLETPROOF LISTENER
    _dashCtrl = Provider.of<DashboardController>(context, listen: false);
    _dashCtrl?.addListener(_onDashboardUpdated);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _isFirstBuild = false;
    });
  }

  // ✅ 3. THE TRIGGER METHOD
  void _onDashboardUpdated() {
    // Whenever Firebase updates the app's state, instantly fetch the latest SQLite data!
    if (mounted) {
      _loadData(init: true, silent: true);
    }
  }

  @override
  void didUpdateWidget(covariant CorrespondenceList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ 4. Cleaned up didUpdateWidget
    if (!_isFirstBuild &&
        (oldWidget.studentId != widget.studentId ||
            oldWidget.searchQuery != widget.searchQuery ||
            oldWidget.todayOnly != widget.todayOnly ||
            oldWidget.unreadOnly != widget.unreadOnly)) {
      _loadData(init: true);
    }
  }

  @override
  void dispose() {
    _dashCtrl
        ?.removeListener(_onDashboardUpdated); // ✅ 5. Prevent memory leaks!
    _syncSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ NEW (2026-11-13): same fix as Diary's pull-to-refresh - this used to
  // only reload from local SQLite, never touching the server. Now does a
  // real sync first (the same manualSync() the footer's Refresh button
  // uses), then reloads the local list. See diary.dart's identical
  // _refreshFromServer() for the full reasoning.
  //
  // ✅ NEW (2026-11-22, design-flaws-and-changes doc): scoped to just
  // FetchAction.correspondences + correspondencesMessages - matches
  // diary.dart's identical scoping. A thread's own preview/unread count
  // lives on the correspondences row while its messages live separately,
  // so both are needed; nothing else on this screen depends on diaries/
  // contacts/classes/report cards.
  Future<void> _refreshFromServer() async {
    final loginCtrl = Provider.of<LoginController>(context, listen: false);
    await loginCtrl.manualSync(context, onlyEntities: {
      FetchAction.correspondences,
      FetchAction.correspondencesMessages,
    });
    await _loadData(init: true);
  }

  Future<void> _loadData({bool init = false, bool silent = false}) async {
    // If we are already loading something heavy, ignore silent background requests
    if (_isLoading || (!_hasMore && !init)) return;

    if (init) {
      if (!silent) {
        // ✅ ONLY show the loading UI if it's a hard, visible refresh
        setState(() {
          _items.clear();
          _isLoading = true;
        });
      }
      _offset = 0;
      _hasMore = true;
    } else {
      if (!silent) setState(() => _isLoading = true);
    }

    try {
      final repo = Provider.of<LoginController>(context, listen: false)
          .getDataRepository();
      if (repo == null) return;

      final newItems = await repo.getCorrespondences(
        studentId: widget.studentId,
        searchQuery: widget.searchQuery,
        todayOnly: widget.todayOnly,
        unreadOnly: widget.unreadOnly,
        limit: init ? _firstLimit : _nextLimit,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          if (newItems.length < (init ? _firstLimit : _nextLimit)) {
            _hasMore = false;
          }

          if (init) {
            // ✅ If it was an init (even a silent one), completely replace the list
            _items = newItems;
          } else {
            // Otherwise, we are paginating, so append to the bottom
            _items.addAll(newItems);
          }

          _offset +=
              newItems.length; // ✅ FIX: Increment by the actual number fetched!
          if (!silent) _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted && !silent) setState(() => _isLoading = false);
      print("Error loading correspondences: $e, Stack: $stackTrace");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX (2026-11-22): see diary.dart's identical fix/comment - the
    // empty/loading states used to return a bare Center() completely
    // outside RefreshIndicator/ListView, leaving a parent with a genuinely
    // empty local correspondence list no way to pull-to-refresh at all.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      ),
      child: RefreshIndicator(
        onRefresh: _refreshFromServer,
        child: _items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text("No messages found."),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                // ✅ FIX (2026-11-22): RefreshIndicator needs the scrollable
                // it wraps to always allow a pull gesture, even when there
                // isn't enough content to overflow the viewport (e.g. a
                // parent with only a handful of short correspondence
                // threads) - without this, the list has nothing to
                // overscroll and pull-to-refresh silently never fires.
                // diary.dart's list has never hit this in practice only
                // because it typically has enough rows to already fill the
                // screen, not because it was deliberately exempted.
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                padding: const EdgeInsets.only(
                    left: 16, right: 16, top: 16, bottom: 80),
                itemCount: _items.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  if (index == _items.length) {
                    return const Center(
                        child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator()));
                  }
                  return _buildCorrespondenceItem(_items[index]);
                },
              ),
      ),
    );
  }

  // Extracts just "EEE, dd/MM/yyyy" from item.date, which may or may not
  // have a time portion trailing it depending on when/how the row was
  // saved - always keeping just the first two tokens handles both.
  String _dateOnly(String? date) {
    if (date == null || date.isEmpty) return "";
    final parts = date.trim().split(' ');
    return parts.take(2).join(' ');
  }

  // Same "Today" treatment as the Diary list - item.date is a display
  // string ("EEE, dd/MM/yyyy ...") that can't be compared directly, so this
  // checks the structured modifiedDate field instead.
  String _displayDate(CorrespondenceModel item) {
    final now = DateTime.now();
    final modDate = item.modDate;
    if (modDate.year == now.year &&
        modDate.month == now.month &&
        modDate.day == now.day) {
      return "Today";
    }
    return _dateOnly(item.date);
  }

  Widget _buildCorrespondenceItem(CorrespondenceModel item) {
    // Determine background highlight
    final bool isUnread = item.bRead == 0;
    final bool isClosed = item.isClosed;

    // Parse initials safely
    String initials = "??";
    if (item.senderName != null && item.senderName!.isNotEmpty) {
      initials = getInitials(item.studentName ?? item.senderName ?? "Unknown");
    }

    return InkWell(
      // ✅ A closed correspondence can't be opened at all - null disables
      // both the tap and InkWell's own ripple feedback, matching "cannot be
      // clicked to view its messages".
      onTap: isClosed
          ? null
          : () {
              if (isUnread) {
                final loginCtrl =
                    Provider.of<LoginController>(context, listen: false);
                final repo = loginCtrl.getDataRepository();
                repo
                    ?.markCorrespondenceAsRead(
                      item.id,
                      authService: loginCtrl.authService,
                      userId: loginCtrl.getUser?.id,
                    )
                    .catchError((e) {
                  print("Background read sync failed: $e");
                });
                if (context.mounted) {
                  Provider.of<DashboardController>(context, listen: false)
                      .refreshCounts();
                }
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CorrespondenceDetailsScreen(item: item),
                ),
              ).then((_) {
                // 🚀 THE SPEED FIX: Silently reload so the blue "unread" background
                // disappears instantly without flashing a loading spinner!
                _loadData(init: true, silent: true);
              });
            },
      child: Container(
        color: isClosed
            ? Colors.grey.shade100
            : (isUnread ? Colors.blue.shade50 : Colors.white),
        padding: const EdgeInsets.symmetric(
            vertical: 16, horizontal: 8), // Increased vertical padding slightly
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ STACK FOR THE TOP-LEFT BADGE
            Stack(
              clipBehavior: Clip
                  .none, // Allows the badge to sit outside the avatar bounds
              children: [
                CircleAvatar(
                  radius: 24, // Matched size to your screenshot
                  backgroundColor: Colors.grey.shade300,
                  child: Text(
                    initials,
                    style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                // Only show badge if unread messages exist
                if (item.numUnreadMessages != null &&
                    item.numUnreadMessages! > 0)
                  Positioned(
                    top: -6,
                    left: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF44336), // Material Red
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${item.numUnreadMessages}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.subject ?? "Message",
                          style: TextStyle(
                            color: isClosed
                                ? Colors.grey.shade500
                                : AppColors.purplePrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // ✅ Date only, no time - the full timestamp was
                      // crowding out the subject, truncating titles that
                      // didn't need to be cut off (e.g. "Concern regardi...").
                      // item.date is "EEE, dd/MM/yyyy hh:mm:ss a"; the first
                      // two space-separated tokens are the weekday+date
                      // regardless of whether a time portion follows.
                      if (isClosed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "CLOSED",
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      else
                        Text(
                          _displayDate(item),
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.studentName ?? item.senderName ?? "Unknown Sender",
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isClosed
                            ? Colors.grey.shade500
                            : Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isClosed
                            ? Colors.grey.shade400
                            : Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function
String getInitials(String name) {
  if (name.isEmpty) return "";
  List<String> nameParts = name.trim().split(RegExp(r'\s+'));
  if (nameParts.isEmpty) return "";
  String initials = nameParts[0][0];
  if (nameParts.length > 1) {
    initials += nameParts[nameParts.length - 1][0];
  }
  return initials.toUpperCase();
}
