import 'package:bla_flutter_app/controllers/dashboard_controller.dart';
import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/data/repositories/data_repository.dart';
import 'package:bla_flutter_app/screens/diary_details.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bla_flutter_app/components/app_header.dart';
import 'package:bla_flutter_app/components/app_footer.dart';
import 'package:bla_flutter_app/components/searchable_picker_sheet.dart';
import 'package:bla_flutter_app/models/diary_model.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:bla_flutter_app/services/data_sync_service.dart';
import 'package:bla_flutter_app/constants/table_names_strings.dart';

const Color navyBlue = Color(0xFF041434);
const Color goldAccent = Color(0xFFFFC107);
const Color unreadBgColor = Color(0xFFFFF9E6);

// --- MAIN SCREEN ---
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  List<Map<String, String>> _classes = [];
  String? _selectedClassId;
  bool _isStaff = false;
  String? _currentStudentId;

  int _unreadCwHw = 0;
  int _unreadNotices = 0;
  int _unreadTimetables = 0;

  int _lastTotalUnread = -1;
  int _refreshTrigger = 0;
  StreamSubscription? _dbSubscription;

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final dashCtrl = Provider.of<DashboardController>(context, listen: false);
    _currentStudentId = dashCtrl.selectedStudentId;
    _lastTotalUnread = dashCtrl.totalUnread;

    _loadClasses();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loginCtrl = Provider.of<LoginController>(context, listen: false);
      final repo = loginCtrl.getDataRepository();
      if (repo != null) {
        _dbSubscription =
            repo.listenTableChanges(TableNames.diaries).listen((_) {
          if (mounted) _updateBadgeCounts();
        });
      }
    });
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        // Closing: clear so the list resets back to the unfiltered view.
        _isSearching = false;
        _searchQuery = '';
        _searchController.clear();
      } else {
        _isSearching = true;
      }
    });
  }

  // Debounced so each DiaryListTab doesn't re-query on every keystroke -
  // didUpdateWidget below already treats a searchQuery change like a
  // classId change (a full reload), which would otherwise fire that often.
  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _searchQuery = val);
    });
  }

  Future<void> _loadClasses() async {
    final loginCtrl = Provider.of<LoginController>(context, listen: false);
    _isStaff = loginCtrl.getUser?.role != 'parent';

    if (_isStaff) {
      final repo = loginCtrl.getDataRepository();
      if (repo != null) {
        final classes = await repo.getClasses();
        if (mounted) {
          setState(() {
            _classes = classes;
            if (_classes.isNotEmpty) {
              _selectedClassId = _classes.first['id'];
            }
          });
          _updateBadgeCounts();
        }
      }
    } else {
      _updateBadgeCounts();
    }
  }

  void _showClassPicker() {
    showSearchablePicker(
      context: context,
      items: _classes,
      idKey: 'id',
      labelKey: 'className',
      selectedId: _selectedClassId,
      searchHint: 'Search classes...',
      emptyText: 'No matching classes.',
      onSelected: (classId) {
        setState(() {
          _selectedClassId = classId;
        });
        _updateBadgeCounts();
      },
    );
  }

  Future<void> _updateBadgeCounts() async {
    final loginCtrl = Provider.of<LoginController>(context, listen: false);
    final dashCtrl = Provider.of<DashboardController>(context, listen: false);
    final repo = loginCtrl.getDataRepository();
    if (repo == null) return;

    try {
      final studentId = _isStaff ? null : dashCtrl.selectedStudentId;
      final classId = _isStaff ? _selectedClassId : null;

      // ✅ Pass the new isTimetable flags to the repository
      final results = await Future.wait([
        repo.getUnreadDiaryCount(
            studentId: studentId, classId: classId, types: const ['cw', 'hw']),
        repo.getUnreadDiaryCount(
            studentId: studentId,
            classId: classId,
            types: const ['gn', 'fd', 'ch'],
            isTimetable: false), // 🚀 Exclude TTs from Notices
        repo.getUnreadDiaryCount(
            studentId: studentId,
            classId: classId,
            types: const ['gn'],
            isTimetable: true) // 🚀 Fetch ONLY TTs
      ]);

      if (mounted) {
        setState(() {
          _unreadCwHw = results[0];
          _unreadNotices = results[1];
          _unreadTimetables = results[2];
        });
      }
    } catch (e) {
      print("Error updating badge counts: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardController>(
      builder: (context, dashboardCtrl, child) {
        final loginCtrl = Provider.of<LoginController>(context, listen: false);
        final repo = loginCtrl.getDataRepository();

        if (repo == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (!_isStaff && _currentStudentId != dashboardCtrl.selectedStudentId) {
          _currentStudentId = dashboardCtrl.selectedStudentId;
          Future.microtask(() => _updateBadgeCounts());
        }

        if (_lastTotalUnread != -1 &&
            dashboardCtrl.totalUnread > _lastTotalUnread) {
          _refreshTrigger++;
        }

        if (_lastTotalUnread != dashboardCtrl.totalUnread) {
          _lastTotalUnread = dashboardCtrl.totalUnread;
          Future.microtask(() => _updateBadgeCounts());
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppHeader(
            title: "Diary",
            showBackButton: true,
            notificationCount: dashboardCtrl.totalUnread,
            showSearch: true,
            isSearching: _isSearching,
            searchController: _searchController,
            onSearchToggle: _toggleSearch,
            onSearchChanged: _onSearchChanged,
          ),
          body: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  color: navyBlue,
                  child: TabBar(
                    tabs: [
                      Tab(
                        child: Badge(
                          isLabelVisible: _unreadCwHw > 0,
                          label: Text(_unreadCwHw.toString()),
                          offset: const Offset(16, -4),
                          child: const Text("CW / HW"),
                        ),
                      ),
                      Tab(
                        child: Badge(
                          isLabelVisible: _unreadNotices > 0,
                          label: Text(_unreadNotices.toString()),
                          offset: const Offset(16, -4),
                          child: const Text("NOTICES"),
                        ),
                      ),
                      Tab(
                        child: Badge(
                          isLabelVisible: _unreadTimetables > 0,
                          label: Text(_unreadTimetables.toString()),
                          offset: const Offset(18, -4),
                          child: const Text("TIMETABLE"),
                        ),
                      ),
                    ],
                    indicatorColor: goldAccent,
                    labelColor: goldAccent,
                    unselectedLabelColor: Colors.grey.shade400,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: 0.5),
                    indicatorWeight: 4,
                  ),
                ),
                if (_isStaff && _classes.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.white,
                    child: InkWell(
                      onTap: _showClassPicker,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedClassId != null
                                    ? (_classes.firstWhere(
                                        (c) => c['id'] == _selectedClassId,
                                        orElse: () =>
                                            {'className': 'Select Class'},
                                      )['className'] ??
                                        'Select Class')
                                    : 'Select Class',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down,
                                color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      DiaryListTab(
                        repo: repo,
                        studentId:
                            _isStaff ? null : dashboardCtrl.selectedStudentId,
                        classId: _isStaff ? _selectedClassId : null,
                        types: const ['cw', 'hw'],
                        refreshTrigger: _refreshTrigger,
                        searchQuery: _searchQuery,
                      ),
                      DiaryListTab(
                        repo: repo,
                        studentId:
                            _isStaff ? null : dashboardCtrl.selectedStudentId,
                        classId: _isStaff ? _selectedClassId : null,
                        types: const ['gn', 'fd', 'ch'],
                        isTimetable: false, // 🚀 Explicitly exclude timetables
                        refreshTrigger: _refreshTrigger,
                        searchQuery: _searchQuery,
                      ),
                      DiaryListTab(
                        repo: repo,
                        studentId:
                            _isStaff ? null : dashboardCtrl.selectedStudentId,
                        classId: _isStaff ? _selectedClassId : null,
                        types: const ['gn'],
                        isTimetable:
                            true, // 🚀 Explicitly fetch ONLY timetables
                        refreshTrigger: _refreshTrigger,
                        searchQuery: _searchQuery,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const AppFooter(),
        );
      },
    );
  }
}

// --- PAGINATED LIST TAB ---
class DiaryListTab extends StatefulWidget {
  final DataRepository repo;
  final String? studentId;
  final String? classId;
  final List<String> types;
  final int refreshTrigger;
  final bool? isTimetable; // ✅ 1. NEW PROPERTY
  final String searchQuery;

  const DiaryListTab({
    super.key,
    required this.repo,
    required this.studentId,
    this.classId,
    required this.types,
    this.refreshTrigger = 0,
    this.isTimetable, // ✅ Initialize
    this.searchQuery = '',
  });

  @override
  State<DiaryListTab> createState() => _DiaryListTabState();
}

class _DiaryListTabState extends State<DiaryListTab> {
  final ScrollController _scrollController = ScrollController();

  List<DiaryModel> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _firstLimit = 25;
  final int _nextLimit = 10;
  StreamSubscription? _syncSubscription;
  StreamSubscription? _dbSubscription;

  // _loadData() and _silentReload() both read/write the same _items/_offset
  // state, with nothing to stop them racing - e.g. initState() firing
  // _loadData(classId: null) before the class dropdown resolves, immediately
  // followed by didUpdateWidget firing another _loadData with the real
  // classId once it does. Whichever call's async query happened to resolve
  // last would win regardless of which one was actually "fresher", able to
  // append results from a stale/wrong class filter on top of (or instead
  // of) the correct ones. Each load call captures the current generation
  // and checks it's still current before applying its result.
  int _loadGeneration = 0;

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
      if (state == SyncState.synced && mounted) {
        _loadData(init: true);
      }
    });

    _dbSubscription =
        widget.repo.listenTableChanges(TableNames.diaries).listen((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 300), () async {
          if (mounted) await _loadData(init: true);
        });
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _dbSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DiaryListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId ||
        oldWidget.classId != widget.classId ||
        oldWidget.searchQuery != widget.searchQuery) {
      _loadData(init: true);
    } else if (oldWidget.refreshTrigger != widget.refreshTrigger) {
      _silentReload();
    }
  }

  Future<void> _silentReload() async {
    final myGeneration = ++_loadGeneration;
    try {
      int fetchLimit = _offset > _firstLimit ? _offset : _firstLimit;
      final newItems = await widget.repo.getDiaries(
        studentId: widget.studentId,
        classId: widget.classId,
        types: widget.types,
        isTimetable: widget.isTimetable, // ✅ Pass to repository
        searchQuery: widget.searchQuery,
        limit: fetchLimit,
        offset: 0,
      );
      // A newer load (triggered by a classId/studentId change, or another
      // reload) started after this one - discard this now-stale result
      // instead of letting it clobber or mix with the fresher one.
      if (!mounted || myGeneration != _loadGeneration) return;
      setState(() {
        _items = newItems;
      });
    } catch (e) {
      print("Error silently reloading: $e");
    }
  }

  Future<void> _loadData({bool init = false}) async {
    // The _isLoading check only makes sense for pagination (init=false,
    // scroll-triggered): no reason to fire an identical extra fetch while
    // one's already in flight. For init=true (a genuine filter change, e.g.
    // classId resolving from null to a real class once the dropdown loads),
    // skipping because a now-stale load happens to still be in flight
    // silently drops the one call that would have corrected it - observed:
    // initState()'s classId=null load took 6s (unfiltered - much slower),
    // and didUpdateWidget's classId=287 reload fired on top of it, triggered
    // by the class resolving, then got silently swallowed, leaving the list
    // stuck on wrong-class results indefinitely. init=true must always
    // proceed and supersede any in-flight load via the generation check
    // below instead of being gated by it.
    if ((!init && _isLoading) || (!_hasMore && !init)) return;
    final myGeneration = ++_loadGeneration;

    if (init) {
      setState(() {
        _items.clear();
        _offset = 0;
        _hasMore = true;
        _isLoading = true;
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final newItems = await widget.repo.getDiaries(
        studentId: widget.studentId,
        classId: widget.classId,
        types: widget.types,
        isTimetable: widget.isTimetable, // ✅ Pass to repository
        searchQuery: widget.searchQuery,
        limit: init ? _firstLimit : _nextLimit,
        offset: _offset,
      );

      // See _silentReload(): discard a stale result superseded by a newer
      // load, rather than appending it onto (or clearing out from under) the
      // fresher one's results.
      if (!mounted || myGeneration != _loadGeneration) return;

      setState(() {
        if (newItems.length < (init ? _firstLimit : _nextLimit)) {
          _hasMore = false;
        }

        _items.addAll(newItems);
        _offset += newItems.length;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error loading diaries: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _isLoading)
      return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && !_isLoading)
      return const Center(child: Text("No entries found."));

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      ),
      child: RefreshIndicator(
        onRefresh: () async => await _loadData(init: true),
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _items.length + (_hasMore ? 1 : 0),
          itemBuilder: (ctx, index) {
            if (index == _items.length) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator()));
            }
            return Column(
              children: [
                _buildItem(_items[index]),
                Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildItem(DiaryModel item) {
    final subject = item.subject != null && item.subject!.isNotEmpty
        ? "${item.subject!}${item.className != null && item.className!.isNotEmpty ? " - ${item.className!}" : ""}"
        : "Notice";
    final subtitleHeader = item.title ?? "";
    final rawDetails = item.details
            // getDiaries() truncates `details` via SQL substr() for
            // performance, which can cut a tag off mid-attribute (e.g.
            // `<strong style="bac`) - that unclosed fragment has no `>` for
            // the main tag-stripping regex to match, so strip it separately.
            ?.replaceAll(RegExp(r'<[^>]*$'), '')
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll('&nbsp;', ' ') ??
        "";
    final previewText = rawDetails.trim();

    String dateStr = item.createdDate;
    try {
      final date = DateTime.parse(item.createdDate);
      final now = DateTime.now();

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        dateStr = "TODAY";
      } else {
        dateStr = DateFormat('EEE, dd/MM/yyyy').format(date);
      }
    } catch (e) {
      dateStr = item.createdDate.split(' ').first;
    }

    final bool isRead = item.bRead == 1;

    return InkWell(
      onTap: () {
        if (!isRead) {
          final loginCtrl =
              Provider.of<LoginController>(context, listen: false);
          try {
            widget.repo
                .markDiaryAsRead(item.diaryId,
                    id: item.id, authService: loginCtrl.authService)
                .catchError((e) {
              print("Background read sync failed: $e");
            });
          } catch (_) {}
          if (context.mounted) {
            Provider.of<DashboardController>(context, listen: false)
                .refreshCounts();
          }
        }

        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DiaryDetailsScreen(item: item))).then((_) {
          if (!isRead) _loadData(init: true);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : unreadBgColor,
          border: isRead
              ? null
              : const Border(left: BorderSide(color: goldAccent, width: 4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject.toUpperCase(),
                      style: const TextStyle(
                          color: navyBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 18)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (subtitleHeader.isNotEmpty)
                        Expanded(
                          child: Text(subtitleHeader,
                              style: TextStyle(
                                  color: Colors.blue.shade700, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      Text(dateStr,
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: dateStr == "TODAY"
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(previewText,
                      style: const TextStyle(
                          color: Colors.black87, fontSize: 15, height: 1.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.chevron_right, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
