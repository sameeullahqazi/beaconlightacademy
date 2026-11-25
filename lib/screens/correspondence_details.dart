import 'package:bla_flutter_app/controllers/dashboard_controller.dart';
import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/models/correspondence_model.dart';
import 'package:bla_flutter_app/models/user_model.dart';
import 'package:bla_flutter_app/themes/constants.dart';
import 'package:bla_flutter_app/components/app_header.dart';
import 'package:bla_flutter_app/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class CorrespondenceDetailsScreen extends StatefulWidget {
  final CorrespondenceModel item;
  const CorrespondenceDetailsScreen({super.key, required this.item});

  @override
  State<CorrespondenceDetailsScreen> createState() =>
      _CorrespondenceDetailsScreenState();
}

class _CorrespondenceDetailsScreenState
    extends State<CorrespondenceDetailsScreen> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  UserModel? _currentUser;
  DashboardController? _dashCtrl;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<LoginController>(context, listen: false).getUser;

    // ✅ FIX (2026-11-19): was reloading messages (and auto-scrolling to the
    // bottom) as a side effect inside build()'s Consumer<DashboardController>
    // builder - which reruns on EVERY DashboardController notification
    // (badge updates, unrelated syncs, any push arrival), not just a new
    // message in THIS thread. That meant any time the user scrolled up to
    // read an earlier message, the next unrelated notification yanked them
    // straight back to the bottom within ~100ms - confirmed live via a real
    // parent's own message in this exact feature, weeks old: "miss, could
    // you please send the message in two parts? I'm unable to scroll up and
    // read the complete message on the app." Listening directly (same
    // pattern already used in correspondence.dart's _onDashboardUpdated)
    // decouples the reload from build() entirely - it now only ever fires
    // on a real DashboardController update, and _loadMessages() itself only
    // auto-scrolls on the very first load or when the message count
    // actually increased, never on an unrelated refresh of the same data.
    _dashCtrl = Provider.of<DashboardController>(context, listen: false);
    _dashCtrl?.addListener(_onDashboardUpdated);

    // ✅ FIX (2026-11-19): was wrapped in addPostFrameCallback, which waits
    // until after the FIRST frame renders before loading - confirmed live
    // that this leaves the screen blank (title/buttons render, but the
    // message list stays empty) until any tap forces a repaint, on a fresh
    // app launch straight into this screen. The old code never hit this
    // because its (now-removed) redundant build()-time microtask fired via
    // Future.microtask(), which resolves within the SAME event loop turn -
    // well before the first frame even finishes - landing its setState()
    // inside the normal pre-first-frame pipeline instead of after it.
    // Calling this directly matches the already-working pattern used by
    // correspondence.dart's list screen and diary.dart's list tab, neither
    // of which wrap their own initial load in addPostFrameCallback.
    _loadMessages(isInitialLoad: true);
  }

  void _onDashboardUpdated() {
    if (mounted) _loadMessages();
  }

  @override
  void dispose() {
    _dashCtrl?.removeListener(_onDashboardUpdated);
    _scrollController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool isInitialLoad = false}) async {
    final loginCtrl = Provider.of<LoginController>(context, listen: false);
    final repo = loginCtrl.getDataRepository();
    if (repo != null) {
      final msgs = await repo.getCorrespondenceMessages(widget.item.id);
      final hasNewMessages = msgs.length > _messages.length;
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
        // ✅ FIX (2026-11-19): confirmed live that setState() here can mark
        // the Element dirty without an actual frame getting pumped to the
        // screen - the data was correct and already in _messages, but the
        // list stayed visually blank until some unrelated gesture (any tap)
        // forced a frame. Reproduced specifically on a fresh cold start
        // straight into this screen (Dashboard -> Correspondence list ->
        // this detail screen) - this async setState() lands right as the
        // push-route transition animation has just gone fully idle.
        // ensureVisualUpdate() explicitly requests a frame instead of
        // relying on that implicit scheduling.
        WidgetsBinding.instance.ensureVisualUpdate();
      }

      // ✅ FIX (2026-11-19): only auto-scroll on the first load or when a
      // genuinely new message arrived - see the comment on initState()
      // above for the full reasoning. A silent refresh that didn't add any
      // message (e.g. an unrelated badge-count update) no longer moves the
      // scroll position at all.
      if ((isInitialLoad || hasNewMessages) && mounted) {
        // ✅ FIX (2026-11-19): was a raw 100ms Future.delayed() before
        // reading maxScrollExtent - confirmed live this can fire before the
        // lazy ListView.builder has actually laid out its newly-added items,
        // so maxScrollExtent reports a smaller-than-true value: only the
        // last message ended up visible, with the rest of the (correctly
        // loaded) conversation rendering as blank space above it.
        // addPostFrameCallback guarantees a real frame has already been
        // laid out with the new _messages before this reads the scroll
        // position, so maxScrollExtent is accurate.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }

      // A message arriving while this exact conversation is open still gets
      // marked unread by the push handler, which has no way of knowing the
      // user is already looking right at it. Re-mark it read on every load
      // (including live updates) so it doesn't pile up an unread count
      // behind the user's back while this screen is open.
      //
      // Wrapped: this runs on every load/live-refresh of this screen (not
      // just once), so a transient network hiccup here was an unhandled
      // exception on a fairly hot path - the messages themselves already
      // loaded and displayed above regardless of whether this call succeeds.
      try {
        await repo.markCorrespondenceAsRead(
          widget.item.id,
          authService: loginCtrl.authService,
          userId: _currentUser?.id,
        );
      } catch (e) {
        print("Background read sync failed: $e");
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();

    final loginCtrl = Provider.of<LoginController>(context, listen: false);
    final repo = loginCtrl.getDataRepository();

    if (repo != null) {
      try {
        final res = await repo.sendCorrespondenceReply(
          correspondenceId: widget.item.id,
          message: text,
          authService: loginCtrl.authService,
          userId: _currentUser?.id ?? "",
        );

        if (res['success'] != true) {
          throw Exception(res['message'] ?? 'Send failed');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Failed to send message. Check your connection and try again.'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: _sendMessage,
              ),
            ),
          );
        }
        // Keep the typed text in the field so nothing is lost on failure.
        return;
      }

      _replyController.clear();
      // ✅ FIX (2026-11-19): removed the explicit auto-scroll that used to
      // be here - _loadMessages() now already scrolls to the bottom
      // whenever the message count increases (which sending one always
      // does), so this was just firing a second, redundant animateTo to
      // the same position right after the one _loadMessages() already
      // triggers.
      await _loadMessages();
    }
  }

  Future<void> _closeConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Close Conversation"),
        content: const Text(
            "Are you sure you want to close this conversation? Neither side will be able to send or view further messages here."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text("Close Conversation",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final loginCtrl = Provider.of<LoginController>(context, listen: false);
    final repo = loginCtrl.getDataRepository();
    if (repo == null) return;

    try {
      await repo.closeCorrespondence(
        widget.item.id,
        authService: loginCtrl.authService,
      );
      widget.item.dateEnded =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation closed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Failed to close conversation. Check your connection and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kept only to read dashboardCtrl.totalUnread for the header badge -
    // reloading messages is now handled by the _dashCtrl listener in
    // initState()/_onDashboardUpdated(), not as a side effect of build().
    return Consumer<DashboardController>(
      builder: (context, dashboardCtrl, child) {
        return Scaffold(
          appBar: AppHeader(
            // Title-cased: subjects are often typed in all-caps by senders,
            // which takes up more header width at the same font size and
            // was getting truncated - title case still reads properly
            // (unlike all-lowercase) while taking noticeably less width
            // than the original all-caps.
            title: widget.item.subject != null
                ? toTitleCase(widget.item.subject!)
                : "Conversation",
            showBackButton: true,
            backgroundColor: AppColors.purplePrimary,
            // 2. PASS THE COUNT
            notificationCount: dashboardCtrl.totalUnread,
            // Switching the global student selector here didn't change the
            // thread being viewed, just the header's own highlight - a
            // confusing half-synced state. Disabled rather than made
            // reactive, to avoid jarring the user away from what they're
            // reading.
            showStudentSwitcher: false,
          ),
          // ... (keep rest of body)
          body: _isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.purplePrimary))
              : Column(
                  children: [
                    // 1. Correspondence Title (Purple)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.item.subject ?? "Conversation",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.purplePrimary,
                          ),
                        ),
                      ),
                    ),

                    // 2. Chat List
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              controller: _scrollController, // ✅ Attach here
                              // ✅ FIX (2026-11-19): ListView.builder normally
                              // only lays out items near the current
                              // viewport, so right after loading a long
                              // thread's messages, maxScrollExtent is just an
                              // estimate from whatever few items happen to be
                              // built - confirmed live that animateTo() using
                              // that estimate can jump past everything that's
                              // actually been laid out, leaving the screen
                              // blank except for whichever single item
                              // happened to already be built. A correspondence
                              // thread is at most a few dozen short text
                              // bubbles, so building all of them eagerly
                              // (rather than Flutter's default lazy ~250px
                              // cache window) is cheap and guarantees an
                              // accurate scroll extent the first time it's
                              // read, instead of chasing the estimate across
                              // multiple frames.
                              cacheExtent: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _messages.length,
                              itemBuilder: (ctx, index) {
                                final msg = _messages[index];
                                // Logic: If senderId is SAME as current user, it's a "Reply" (Right side)
                                // Note: You might need to adjust this check based on your actual DB data
                                // For now, assuming if it's NOT the teacher/sender of the original item, it's me.
                                bool isMe = msg['senderId'].toString() ==
                                    _currentUser?.id;

                                // Fallback Logic: In some systems, teacher replies are also messages.
                                // Let's assume right side is Parent, Left side is Teacher.

                                return _buildMessageTile(
                                  message: msg['message'] ?? "",
                                  // ✅ FIX (2026-11-22): was preferring
                                  // modifiedDate - that field's only real
                                  // purpose is the sync cursor (see
                                  // DataRepository.getLatestModifiedDateString()),
                                  // and until today it happened to display
                                  // correctly only because the model used to
                                  // (wrongly) local-convert it before storing
                                  // it, which also silently broke the cursor
                                  // (see correspondence_message_model.dart's
                                  // fix). Now that it's correctly raw/UTC,
                                  // preferring it here would show message
                                  // times ~5h behind. `date`/`createdDate`
                                  // are already server-formatted for display
                                  // and were never part of that bug.
                                  date: msg['date'] ?? msg['createdDate'] ?? "",
                                  isMe: isMe,
                                );
                              },
                            ),
                    ),

                    // 3. Close Button - hidden once the conversation is
                    // already closed, since there's no reopen affordance in
                    // this UI yet.
                    if (!widget.item.isClosed)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _closeConversation,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.purplePrimary),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                            child: const Text("CLOSE CONVERSATION",
                                style: TextStyle(
                                    color: AppColors.purplePrimary,
                                    letterSpacing: 1.2)),
                          ),
                        ),
                      ),

                    // 4. Input Area
                    _buildReplyInput(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMessageTile(
      {required String message, required String date, required bool isMe}) {
    String dateStr = date;
    try {
      if (date.isNotEmpty) {
        final dt = DateTime.parse(date);
        dateStr = DateFormat('EEE, dd/MM/yyyy hh:mm:ss a').format(dt);
      }
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0), // Space between messages
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Date Label
          if (dateStr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                dateStr,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors
                        .grey.shade800), // Darker grey to match screenshot
              ),
            ),

          // Message Bubble
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFF7E57C2)
                  : const Color(0xFFEEEEEE), // Purple vs Grey
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text.rich(
              linkifyPlainText(
                message,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
                // Default blue reads poorly on the purple "isMe" bubble.
                linkColor: isMe ? Colors.yellow.shade100 : Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    if (widget.item.isClosed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.grey.shade600, size: 18),
            const SizedBox(width: 8),
            Text("This conversation is closed",
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _replyController,
                decoration: const InputDecoration(
                  hintText: 'Aa...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                minLines: 1,
                maxLines: 3,
                // ✅ FIX: no dedicated newline key without this - Enter
                // either did nothing or acted as a submit/done action, so a
                // reply could never be intentionally split across lines and
                // always posted as one merged paragraph.
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                // ✅ FIX: without this, Android's autofill/keyboard can offer
                // the device owner's own saved username (e.g. their phone
                // number) as a one-tap suggestion on this plain-text field,
                // which if tapped/accepted and sent leaks it into the
                // conversation - confirmed 2026-10-10 when a parent's own
                // username was sent as message content to 4 different
                // correspondence threads. Empty list explicitly opts the
                // field out of autofill entirely.
                autofillHints: const [],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Send Button (Pill Shape)
          ElevatedButton(
            onPressed: _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E57C2), // Purple
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("SEND",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
