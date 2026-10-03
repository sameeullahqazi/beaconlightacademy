import 'package:bla_flutter_app/constants/table_names_strings.dart';
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

// --- PART 1: THE MAIN SCREEN SHELL ---
class CorrespondenceScreen extends StatefulWidget {
  const CorrespondenceScreen({super.key});

  @override
  State<CorrespondenceScreen> createState() => _CorrespondenceScreenState();
}

class _CorrespondenceScreenState extends State<CorrespondenceScreen> {
  String? _currentStudentId;

  @override
  void initState() {
    super.initState();
    final dashCtrl = Provider.of<DashboardController>(context, listen: false);
    _currentStudentId = dashCtrl.selectedStudentId;
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
            title: "CORRESPONDENCES",
            showBackButton: true,
            backgroundColor: AppColors.purplePrimary,
            notificationCount: dashboardCtrl.totalUnread,
          ),
          body: Stack(
            children: [
              CorrespondenceList(
                studentId: _currentStudentId, // ✅ Removed the totalUnread trap!
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

  const CorrespondenceList(
      {super.key, required this.studentId}); // ✅ Cleaned up constructor

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
  StreamSubscription? _dbSubscription;
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

    final repo = Provider.of<LoginController>(context, listen: false)
        .getDataRepository();
    if (repo != null) {
      _dbSubscription =
          repo.listenTableChanges(TableNames.correspondences).listen((_) {
        if (mounted) {
          // ✅ SQLite table changed? Refresh the list silently!
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _loadData(init: true, silent: true);
          });
        }
      });
    }

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
    if (!_isFirstBuild && oldWidget.studentId != widget.studentId) {
      _loadData(init: true);
    }
  }

  @override
  void dispose() {
    _dashCtrl
        ?.removeListener(_onDashboardUpdated); // ✅ 5. Prevent memory leaks!
    _syncSubscription?.cancel();
    _dbSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
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
    if (_items.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty && !_isLoading) {
      return const Center(child: Text("No messages found."));
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadData(init: true);
        },
        child: ListView.separated(
          controller: _scrollController,
          padding:
              const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
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

  Widget _buildCorrespondenceItem(CorrespondenceModel item) {
    // Determine background highlight
    final bool isUnread = item.bRead == 0;

    // Parse initials safely
    String initials = "??";
    if (item.senderName != null && item.senderName!.isNotEmpty) {
      initials = getInitials(item.studentName ?? item.senderName ?? "Unknown");
    }

    return InkWell(
      onTap: () {
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
        color: isUnread ? Colors.blue.shade50 : Colors.white,
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
                          style: const TextStyle(
                            color: AppColors.purplePrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        item.date ?? "",
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.studentName ?? item.senderName ?? "Unknown Sender",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600),
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
