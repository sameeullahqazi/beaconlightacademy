import 'package:bla_flutter_app/components/app_header.dart';
import 'package:bla_flutter_app/controllers/dashboard_controller.dart';
import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/models/diary_model.dart';
import 'package:bla_flutter_app/models/diary_comments_model.dart';
import 'package:bla_flutter_app/themes/constants.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/api_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart'; // ✅ Using the modern package
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

// Matches diary.dart's navyBlue - duplicated locally rather than imported
// since diary.dart isn't otherwise a dependency of this screen.
const Color navyBlue = Color(0xFF041434);

// Swipeable wrapper around a single tab's already-loaded diary items.
// Scoped to whatever list the caller passed in (e.g. just CW/HW, or just
// Notices) - the caller (diary.dart) is responsible for only ever passing
// its own tab's items, so swiping never crosses into a different category.
// Only swipes within what's already been paginated into that list; reaching
// either end simply stops (no further auto-pagination while swiping).
class DiaryDetailsScreen extends StatefulWidget {
  final List<DiaryModel> items;
  final int initialIndex;

  const DiaryDetailsScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  State<DiaryDetailsScreen> createState() => _DiaryDetailsScreenState();
}

class _DiaryDetailsScreenState extends State<DiaryDetailsScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  final Set<String> _markedReadIds = {};
  // Swipe affordance: the prev/next arrows stay hidden until the page is
  // tapped, then show faintly over the content (not a fixed toolbar strip -
  // that read as clutter once the position pill was dropped). Resets to
  // hidden on every page change so it doesn't linger after a swipe.
  bool _showArrowOverlay = false;
  // ✅ FIX: a plain GestureDetector.onTap here only fired in genuinely empty
  // space below the content - each page's InteractiveViewer/SelectionArea
  // (for pan/zoom and text selection) wins the tap gesture arena anywhere
  // over actual content, so taps on/near text never reached this detector.
  // Listener bypasses the gesture arena entirely - it gets every raw pointer
  // event within its (translucent) hit-test bounds regardless of which
  // recognizer "wins" the tap - so tracking down/up position manually here
  // reliably detects a tap (small movement) vs. a scroll/swipe (large
  // movement) anywhere on the page.
  Offset? _pointerDownPosition;
  // ✅ FIX: onPageChanged fires for both a swipe and a _goToPage() arrow
  // tap, but only a swipe should hide the overlay - tapping the arrow to
  // navigate shouldn't force a re-reveal tap before the next arrow tap
  // works. Set right before requesting an arrow-driven page change, and
  // consumed (not reset) by the very next onPageChanged.
  bool _navigatingViaArrow = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // Mark the diary the user actually tapped as read immediately, same as
    // swiping to any other page does below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markReadIfNeeded(widget.items[widget.initialIndex]);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _markReadIfNeeded(DiaryModel item) {
    if (item.bRead == 1 || _markedReadIds.contains(item.id)) return;
    _markedReadIds.add(item.id);
    item.bRead = 1; // Instant local state so re-visiting this page via swipe
    // doesn't re-fire the mark-as-read call.

    final loginCtrl = Provider.of<LoginController>(context, listen: false);
    final repo = loginCtrl.getDataRepository();
    if (repo != null) {
      try {
        repo
            .markDiaryAsRead(item.diaryId,
                id: item.id, authService: loginCtrl.authService)
            .catchError((e) {
          print("Background read sync failed: $e");
        });
      } catch (_) {}
    }
    if (mounted) {
      Provider.of<DashboardController>(context, listen: false)
          .refreshCounts();
    }
  }

  void _goToPage(int index) {
    _navigatingViaArrow = true;
    // The same tap that hits an arrow also reaches the outer Listener
    // (it gets every pointer event regardless of what else handles it,
    // including this arrow's own InkWell), and Listener's onPointerUp
    // fires before this onTap does - so it may have just toggled the
    // overlay off. Force it back on rather than leaving that race in
    // charge of whether it's visible for the page that's about to show.
    setState(() => _showArrowOverlay = true);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    final downPos = _pointerDownPosition;
    _pointerDownPosition = null;
    if (downPos == null) return;
    // A real scroll/swipe moves well past this; a tap barely moves at all.
    if ((event.position - downPos).distance < 12) {
      setState(() => _showArrowOverlay = !_showArrowOverlay);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.items[_currentIndex];
    final bool hasMultiple = widget.items.length > 1;
    return Consumer<DashboardController>(
      builder: (context, dashboardCtrl, child) {
        return Scaffold(
          appBar: AppHeader(
            title: currentItem.subject != null
                ? "${currentItem.subject!}${currentItem.className != null && currentItem.className!.isNotEmpty ? " - ${currentItem.className!}" : "Assignment"}"
                : "Assignment",
            showBackButton: true,
            notificationCount: dashboardCtrl.totalUnread,
            // Switching the global student selector here didn't change the
            // diary being viewed, just the header's own highlight - a
            // confusing half-synced state. Disabled rather than made
            // reactive, to avoid jarring the user away from what they're
            // reading.
            showStudentSwitcher: false,
          ),
          body: Listener(
            // translucent so this still lets taps reach links/buttons in the
            // diary content underneath, anywhere on the page - see
            // _pointerDownPosition's comment for why Listener instead of
            // GestureDetector.onTap.
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePointerDown,
            onPointerUp: _handlePointerUp,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.items.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                      if (!_navigatingViaArrow) {
                        _showArrowOverlay = false;
                      }
                      _navigatingViaArrow = false;
                    });
                    _markReadIfNeeded(widget.items[index]);
                  },
                  itemBuilder: (context, index) {
                    return _DiaryDetailBody(item: widget.items[index]);
                  },
                ),
                if (hasMultiple && _showArrowOverlay && _currentIndex > 0)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Opacity(
                        opacity: 0.2,
                        child: _NavArrow(
                          icon: Icons.chevron_left,
                          onTap: () => _goToPage(_currentIndex - 1),
                        ),
                      ),
                    ),
                  ),
                if (hasMultiple &&
                    _showArrowOverlay &&
                    _currentIndex < widget.items.length - 1)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Opacity(
                        opacity: 0.2,
                        child: _NavArrow(
                          icon: Icons.chevron_right,
                          onTap: () => _goToPage(_currentIndex + 1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Small circular overlay button used for the prev/next swipe affordance.
class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: navyBlue,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// The actual per-diary content (details, attachments, comments) - one
// instance per PageView page, each owning its own full-details/comments
// fetch so swiping doesn't mix state between diaries.
class _DiaryDetailBody extends StatefulWidget {
  final DiaryModel item;

  const _DiaryDetailBody({required this.item});

  @override
  State<_DiaryDetailBody> createState() => _DiaryDetailBodyState();
}

class _DiaryDetailBodyState extends State<_DiaryDetailBody> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;

  List<DiaryCommentModel> _comments = [];
  bool _isLoadingComments = true;
  bool _isLoadingDetails = true;
  int _lastTotalUnread = -1;

  @override
  void initState() {
    super.initState();
    // ✅ Wait for screen transition to finish before hitting the database
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadComments();
      _loadFullDetails();
    });
  }

  // The list screen only passes a 300-char preview of `details` (see
  // getDiaries()), so fetch the full content once this diary is actually
  // opened.
  Future<void> _loadFullDetails() async {
    final repo = Provider.of<LoginController>(context, listen: false)
        .getDataRepository();
    if (repo != null) {
      final fullDetails = await repo.getDiaryDetailsById(widget.item.id);
      if (mounted) {
        setState(() {
          widget.item.details = fullDetails;
          _isLoadingDetails = false;
        });
      }
    } else if (mounted) {
      setState(() => _isLoadingDetails = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final repo = Provider.of<LoginController>(context, listen: false)
        .getDataRepository();
    if (repo != null) {
      final comments = await repo.getDiaryComments(widget.item.diaryId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardController>(
      builder: (context, dashboardCtrl, child) {
        // _saveDiaryCommentLocally() (push_notification_service.dart) calls
        // DashboardController.refreshCounts() after saving a new comment,
        // which calls notifyListeners() unconditionally - but totalUnread
        // itself (diary + correspondence unread counts) never includes
        // comments, so gating the reload on totalUnread actually changing
        // (as DiaryScreen does for its list, where every relevant event
        // does move that number) never fires for a comment-only event.
        // Reload on every rebuild after the first instead - this screen's
        // single-diary comment query is cheap enough that reloading on an
        // unrelated DashboardController update too is an acceptable cost
        // for actually catching comment arrivals reliably.
        if (_lastTotalUnread != -1) {
          Future.microtask(_loadComments);
        }
        _lastTotalUnread = dashboardCtrl.totalUnread;

        // ✅ WRAPPED IN INTERACTIVE VIEWER FOR ZOOM
        return (_isLoadingComments || _isLoadingDetails)
            ? const Center(
                child:
                    CircularProgressIndicator(color: AppColors.purplePrimary))
            : InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0, // Allow users to zoom in up to 4x
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(widget.item),
                      const SizedBox(height: 24),

                      // ✅ HTML WIDGET (Renders Bold, Italic, Breaks correctly)
                      // ✅ WRAPPED IN SELECTION AREA FOR COPY/PASTE
                      SelectionArea(
                        child: HtmlWidget(
                          widget.item.details ?? "",
                          textStyle: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: Colors.black87),
                          // ✅ MAKE LINKS AUTOMATICALLY CLICKABLE!
                          onTapUrl: (url) async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                              return true;
                            }
                            return false;
                          },
                          onErrorBuilder: (context, element, error) =>
                              Text('$element error: $error'),
                          onLoadingBuilder:
                              (context, element, loadingProgress) =>
                                  const CircularProgressIndicator(),
                        ),
                      ),

                      const SizedBox(height: 24),
                      if (widget.item.attachment != null ||
                          widget.item.attachment2 != null)
                        _buildAttachments(
                            widget.item.attachment, widget.item.attachment2),
                      // ✅ Diary comments temporarily disabled 2026-10-03
                      // (mutual staff decision - Samee + Andaleeb, school
                      // head) after reports of abusive/offensive parent
                      // comments, even with the staff-only-visibility
                      // restriction added 2026-10-02. Commented out rather
                      // than removed in case the decision is revisited -
                      // the loading/fetch logic above (_loadComments(),
                      // the live-refresh wiring in build()) is left intact
                      // so re-enabling this is just uncommenting the block
                      // below.
                      // const SizedBox(height: 32),
                      // const Divider(height: 1),
                      // const SizedBox(height: 16),
                      // _isLoadingComments
                      //     ? const Center(child: CircularProgressIndicator())
                      //     : _buildCommentsSection(_comments),
                    ],
                  ),
                ),
              );
      },
    );
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    final loginCtrl = Provider.of<LoginController>(context, listen: false);
    final repo = loginCtrl.getDataRepository();

    if (repo != null) {
      await repo.addDiaryComment(
        diaryId: widget.item.diaryId,
        comment: text,
        authService: loginCtrl.authService,
        senderName: Provider.of<LoginController>(context, listen: false)
                .getUser
                ?.firstname ??
            "Me", // ✅ Pass Name
      );

      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        _loadComments();
      }
    }

    if (mounted) setState(() => _isSending = false);
  }

  Widget _buildHeader(DiaryModel item) {
    String dateStr = item.createdDate;
    try {
      final date = DateTime.parse(item.createdDate);
      final now = DateTime.now();
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        dateStr = "Today";
      } else {
        dateStr = DateFormat('EEE, dd/MM/yyyy').format(date);
      }
    } catch (e) {
      dateStr = item.createdDate.split(' ').first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (item.subject != null && item.subject!.isNotEmpty)
              ? "${item.subject!.toUpperCase()}${item.className != null && item.className!.isNotEmpty ? " - ${item.className!}" : "Assignment"}"
              : "Notice",
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 1, 30, 124),
          ),
        ),
        const SizedBox(height: 8),
        if (item.title != null && item.title!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              item.title!,
              style: const TextStyle(
                color: Color.fromARGB(255, 27, 19, 139),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Text(
          dateStr,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAttachments(String? attachment1, String? attachment2) {
    List<String> attachments = [];
    if (attachment1 != null && attachment1.isNotEmpty)
      attachments.add(attachment1);
    if (attachment2 != null && attachment2.isNotEmpty)
      attachments.add(attachment2);

    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: attachments.asMap().entries.map((entry) {
            int index = entry.key + 1;
            String fileName = entry.value;
            return _buildDownloadButton(fileName, index);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDownloadButton(String fileName, int index) {
    return ElevatedButton.icon(
      onPressed: () {
        // ✅ Navigate to our custom in-app viewer instead of using URL Launcher!
        final urlString = "${APIStrings.s3BucketUrl}/diaries/$fileName";
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttachmentViewerScreen(
              url: urlString,
              fileName: fileName,
            ),
          ),
        );
      },
      icon: const Icon(Icons.remove_red_eye,
          color: Colors.white,
          size: 20), // Changed icon to an 'eye' for preview
      label: Text("VIEW FILE $index",
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 34, 63, 159),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 2,
      ),
    );
  }

  Widget _buildCommentsSection(List<DiaryCommentModel> comments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people_outline, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              '${comments.length} class comments',
              style: TextStyle(color: Colors.grey[700], fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, index) => _buildCommentItem(comments[index]),
        ),
        const SizedBox(height: 20),
        _buildCommentInput(),
      ],
    );
  }

  Widget _buildCommentItem(DiaryCommentModel comment) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          alignment: Alignment.topCenter,
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[200],
            child: Text(
              comment.senderName.isNotEmpty
                  ? comment.senderName[0].toUpperCase()
                  : "?",
              style: const TextStyle(
                  color: Colors.black54, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  children: [
                    TextSpan(
                        text: comment.senderName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(
                        text: "  ${comment.createdDate}",
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(comment.message,
                  style: const TextStyle(color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Row(
      children: [
        CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[300],
            child: const Text("ME")),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Add a class comment...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              maxLines: null,
              // ✅ FIX: without this, Android's autofill/keyboard can offer
              // the device owner's own saved username (e.g. their phone
              // number) as a one-tap suggestion on this plain-text field -
              // see correspondence_details.dart's reply field for the
              // confirmed 2026-10-10 incident this guards against. Empty
              // list explicitly opts the field out of autofill entirely.
              autofillHints: const [],
            ),
          ),
        ),
        IconButton(
          icon: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send, color: Color(0xFF7E57C2)),
          onPressed: _isSending ? null : _postComment,
        ),
      ],
    );
  }
}

// --- UPDATED IN-APP ATTACHMENT VIEWER ---
class AttachmentViewerScreen extends StatefulWidget {
  final String url;
  final String fileName;

  const AttachmentViewerScreen({
    super.key,
    required this.url,
    required this.fileName,
  });

  @override
  State<AttachmentViewerScreen> createState() => _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState extends State<AttachmentViewerScreen> {
  late final WebViewController _webViewController;
  bool _isOfficeDoc = false;
  bool _isLoadingWeb = true;
  // ✅ FIX: previously, a recognized type (PDF/Office doc/image) whose
  // in-app viewer failed to actually load the file (bad file, server
  // hiccup, wrong content-type, dropped connection) had no fallback at
  // all - only genuinely UNRECOGNIZED file types got the "open
  // externally" escape hatch. Now any load failure, regardless of type,
  // falls through to that same fallback.
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();

    final lowerName = widget.fileName.toLowerCase();
    _isOfficeDoc = lowerName.endsWith('.doc') ||
        lowerName.endsWith('.docx') ||
        lowerName.endsWith('.xls') ||
        lowerName.endsWith('.xlsx') ||
        lowerName.endsWith('.ppt') ||
        lowerName.endsWith('.pptx');

    if (_isOfficeDoc) {
      // 🚀 The Google Docs Viewer Magic Trick
      final encodedUrl = Uri.encodeComponent(widget.url);
      final googleDocsUrl =
          "https://docs.google.com/gview?embedded=true&url=$encodedUrl";

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              if (mounted) {
                setState(() => _isLoadingWeb = false);
              }
            },
            onWebResourceError: (WebResourceError error) {
              // Only the main frame failing matters - Google's gview page
              // itself can throw harmless errors for sub-resources (ads,
              // analytics, etc.) that shouldn't trigger our fallback.
              if (mounted && error.isForMainFrame != false) {
                setState(() {
                  _isLoadingWeb = false;
                  _hasLoadError = true;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(googleDocsUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowerName = widget.fileName.toLowerCase();
    final isPdf = lowerName.endsWith('.pdf');
    final isImage = lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, style: const TextStyle(fontSize: 16)),
        backgroundColor: AppColors.purplePrimary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(isPdf, isImage),
    );
  }

  Widget _buildBody(bool isPdf, bool isImage) {
    // A recognized type that failed to actually load falls through to the
    // exact same "open externally" fallback as a genuinely unknown type,
    // rather than being stuck on a blank/broken in-app viewer with no way
    // out.
    if (_hasLoadError) {
      return _buildFallback(
          "This file couldn't be loaded in-app. It may be a connection "
          "issue - try again, or open it externally below.");
    }

    if (isPdf) {
      return SfPdfViewer.network(
        widget.url,
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          if (mounted) setState(() => _hasLoadError = true);
        },
      );
    } else if (isImage) {
      return Center(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: Image.network(
            widget.url,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const CircularProgressIndicator(
                  color: AppColors.purplePrimary);
            },
            errorBuilder: (context, error, stackTrace) {
              // Scheduled for after this build completes, since
              // errorBuilder can run during a build and setState can't be
              // called synchronously from there.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _hasLoadError = true);
              });
              return const CircularProgressIndicator(
                  color: AppColors.purplePrimary);
            },
          ),
        ),
      );
    } else if (_isOfficeDoc) {
      // ✅ Render Office Docs via Google Web Viewer
      return Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoadingWeb)
            const Center(
                child:
                    CircularProgressIndicator(color: AppColors.purplePrimary)),
        ],
      );
    } else {
      // Genuinely unrecognized file type (.zip, etc.)
      return _buildFallback("This file type cannot be previewed in-app.");
    }
  }

  Widget _buildFallback(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse(widget.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.purplePrimary),
            child: const Text("Download External",
                style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
