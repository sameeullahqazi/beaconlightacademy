import 'package:bla_flutter_app/controllers/dashboard_controller.dart';
import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/models/correspondence_model.dart';
import 'package:bla_flutter_app/models/user_model.dart';
import 'package:bla_flutter_app/themes/constants.dart';
import 'package:bla_flutter_app/components/app_header.dart';
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

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<LoginController>(context, listen: false).getUser;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    // Cleaned up the dbSubscription, no longer needed!
    _scrollController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final loginCtrl = Provider.of<LoginController>(context, listen: false);
    final repo = loginCtrl.getDataRepository();
    if (repo != null) {
      final msgs = await repo.getCorrespondenceMessages(widget.item.id);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
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
      await _loadMessages();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. WRAP IN CONSUMER
    return Consumer<DashboardController>(
      builder: (context, dashboardCtrl, child) {
        // Reload on every dashboard update, not just when the aggregate
        // total happens to change. numUnreadMessages/bRead can update
        // without moving the global total (e.g. this thread was already
        // unread), which previously meant messages after the first one
        // silently stopped appearing until the screen was reopened.
        Future.microtask(() async {
          await _loadMessages();

          // Auto-scroll to show the new message
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        });
        return Scaffold(
          appBar: AppHeader(
            title: "ConversationView",
            showBackButton: true,
            backgroundColor: AppColors.purplePrimary,
            // 2. PASS THE COUNT
            notificationCount: dashboardCtrl.totalUnread,
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
                                  // ✅ Bulletproof date fallback:
                                  date: msg['modifiedDate'] != null
                                      ? msg['modifiedDate']
                                      : msg['date'] ?? msg['createdDate'] ?? "",
                                  isMe: isMe,
                                );
                              },
                            ),
                    ),

                    // 3. Close Button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            // Add Close Logic Here
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppColors.purplePrimary),
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
            child: Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
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
