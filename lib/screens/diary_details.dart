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

class DiaryDetailsScreen extends StatefulWidget {
  final DiaryModel item;

  const DiaryDetailsScreen({super.key, required this.item});

  @override
  State<DiaryDetailsScreen> createState() => _DiaryDetailsScreenState();
}

class _DiaryDetailsScreenState extends State<DiaryDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;

  List<DiaryCommentModel> _comments = [];
  bool _isLoadingComments = true;

  @override
  void initState() {
    super.initState();
    // ✅ Wait for screen transition to finish before hitting the database
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadComments();
    });
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
        return Scaffold(
          appBar: AppHeader(
            title: widget.item.subject != null
                ? "${widget.item.subject!}${widget.item.className != null && widget.item.className!.isNotEmpty ? " - ${widget.item.className!}" : "Assignment"}"
                : "Assignment",
            showBackButton: true,
            notificationCount: dashboardCtrl.totalUnread,
          ),
          // ✅ 1. WRAPPED IN INTERACTIVE VIEWER FOR ZOOM
          body: _isLoadingComments
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

                        // ✅ 2. HTML WIDGET (Renders Bold, Italic, Breaks correctly)
                        // ✅ 2. WRAPPED IN SELECTION AREA FOR COPY/PASTE
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
                        const SizedBox(height: 32),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        _isLoadingComments
                            ? const Center(child: CircularProgressIndicator())
                            : _buildCommentsSection(_comments),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  // ... (Rest of your methods: _postComment, _buildHeader, etc. remain exactly the same) ...

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
      dateStr = DateFormat('EEE, dd/MM/yyyy').format(date);
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
    if (isPdf) {
      return SfPdfViewer.network(widget.url);
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
            errorBuilder: (context, error, stackTrace) =>
                const Text("Could not load image"),
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
      // Fallback for completely unknown files (.zip, etc.)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("This file type cannot be previewed in-app."),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(widget.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purplePrimary),
              child: const Text("Download External",
                  style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      );
    }
  }
}
