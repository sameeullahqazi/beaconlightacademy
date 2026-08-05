import 'package:bla_flutter_app/components/app_header.dart';
import 'package:bla_flutter_app/components/app_footer.dart';
import 'package:bla_flutter_app/constants/table_names_strings.dart';
import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/models/correspondence_model.dart';
import 'package:bla_flutter_app/screens/correspondence_details.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class NewCorrespondenceScreen extends StatefulWidget {
  const NewCorrespondenceScreen({super.key});

  @override
  State<NewCorrespondenceScreen> createState() =>
      _NewCorrespondenceScreenState();
}

class _NewCorrespondenceScreenState extends State<NewCorrespondenceScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  List<Map<String, String>> _allContacts = [];
  List<Map<String, String>> _filteredContacts = []; // Used by Staff
  List<Map<String, String>> _classes = [];
  List<Map<String, String>> _students = []; // Parent's own kids

  String? _selectedClassId;
  String? _selectedContactId; // The Parent ID / Teacher ID
  String? _selectedStudentId; // The Student ID

  bool _isLoading = true;
  bool _isSending = false;
  bool _isStaff = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final loginCtrl = Provider.of<LoginController>(context, listen: false);
    _isStaff = loginCtrl.getUser?.role != 'parent';
    final repo = loginCtrl.getDataRepository();

    if (repo != null) {
      _allContacts = await repo.getContacts();

      if (_isStaff) {
        // --- STAFF FLOW ---
        _classes = await repo.getClasses();
      } else {
        // --- PARENT FLOW ---
        _filteredContacts = _allContacts;
        final userStudents = loginCtrl.getUser?.studentList ?? [];
        _students = userStudents
            .map((s) => {'id': s.id, 'name': s.studentName})
            .toList();

        if (_students.isNotEmpty) _selectedStudentId = _students.first['id'];
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _filterContactsByClass() {
    _filteredContacts =
        _allContacts.where((c) => c['classId'] == _selectedClassId).toList();
    _selectedContactId = null;
    _selectedStudentId = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: "New Message",
        showBackButton: true,
        backgroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        "Start a new message thread by selecting a contact",
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 16),

                    // --- STAFF FLOW ---
                    if (_isStaff) ...[
                      const Text("Select Class",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownMenu<String>(
                        expandedInsets: EdgeInsets.zero,
                        enableFilter: true,
                        enableSearch: true,
                        requestFocusOnTap:
                            true, // ✅ POPS THE KEYBOARD SO YOU CAN TYPE!
                        hintText: "Type to search class...",
                        inputDecorationTheme: _dropdownDecorTheme(),
                        // initialSelection removed so it starts empty
                        dropdownMenuEntries: _classes
                            .map((c) => DropdownMenuEntry(
                                value: c['id']!, label: c['className']!))
                            .toList(),
                        onSelected: (val) {
                          setState(() {
                            _selectedClassId = val;
                            _filterContactsByClass();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text("Select Student",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownMenu<String>(
                        key: ValueKey(
                            _selectedClassId), // Forces reset when class changes
                        expandedInsets: EdgeInsets.zero,
                        enableFilter: true,
                        enableSearch: true,
                        requestFocusOnTap:
                            true, // ✅ POPS THE KEYBOARD HERE TOO!
                        hintText: "Type to search student...",
                        inputDecorationTheme: _dropdownDecorTheme(),
                        dropdownMenuEntries: _filteredContacts
                            .map((c) => DropdownMenuEntry(
                                value: c['studentId']!, label: c['name']!))
                            .toList(),
                        onSelected: (val) {
                          setState(() {
                            _selectedStudentId = val;
                            try {
                              final contact = _filteredContacts
                                  .firstWhere((c) => c['studentId'] == val);
                              _selectedContactId = contact['id'];
                            } catch (_) {}
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ]

                    // --- PARENT FLOW ---
                    else ...[
                      const Text("Select Contact (Teacher)",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownMenu<String>(
                        expandedInsets: EdgeInsets.zero,
                        enableFilter: true,
                        enableSearch: true,
                        hintText: "Type to search teacher...",
                        inputDecorationTheme: _dropdownDecorTheme(),
                        dropdownMenuEntries: _filteredContacts
                            .map((c) => DropdownMenuEntry(
                                value: c['id']!, label: c['name']!))
                            .toList(),
                        onSelected: (val) =>
                            setState(() => _selectedContactId = val),
                      ),
                      const SizedBox(height: 16),
                      const Text("Select Student",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownMenu<String>(
                        expandedInsets: EdgeInsets.zero,
                        enableFilter: false, // Small list, no search needed
                        hintText: "Select your student...",
                        inputDecorationTheme: _dropdownDecorTheme(),
                        initialSelection: _selectedStudentId,
                        dropdownMenuEntries: _students
                            .map((s) => DropdownMenuEntry(
                                value: s['id']!, label: s['name']!))
                            .toList(),
                        onSelected: (val) =>
                            setState(() => _selectedStudentId = val),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // --- COMMON FIELDS ---
                    const Text("Subject",
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    _buildTextField(_subjectController, "Subject..."),
                    const SizedBox(height: 16),

                    const Text("Your Message...",
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    _buildTextField(
                        _messageController, "Type your message here...",
                        maxLines: 8),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("CANCEL",
                              style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isSending ? null : _handleSend,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E57C2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text("SEND",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const AppFooter(),
    );
  }

  // Consistent styling for the new DropdownMenu
  InputDecorationTheme _dropdownDecorTheme() {
    return InputDecorationTheme(
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey.shade400)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade400)),
        contentPadding: const EdgeInsets.all(12),
      ),
      validator: (val) => val == null || val.isEmpty ? "Required" : null,
    );
  }

  Future<void> _handleSend() async {
    // 1. Manual Validation for Dropdowns
    if (_selectedContactId == null || _selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please select a required contact/student."),
          backgroundColor: Colors.orange));
      return;
    }

    // 2. Standard Form Validation
    if (_formKey.currentState!.validate()) {
      setState(() => _isSending = true);

      final loginCtrl = Provider.of<LoginController>(context, listen: false);
      final repo = loginCtrl.getDataRepository();

      if (repo != null) {
        String finalStudentName = "";

        if (_isStaff) {
          try {
            final contact = _filteredContacts
                .firstWhere((c) => c['studentId'] == _selectedStudentId);
            finalStudentName = contact['name'] ?? "Unknown";
          } catch (_) {}
        } else {
          try {
            final st =
                _students.firstWhere((s) => s['id'] == _selectedStudentId);
            finalStudentName = st['name'] ?? "";
          } catch (_) {}
        }

        // 🚨 DIAGNOSTIC 1: Check the Payload

        final res = await repo.addNewCorrespondence(
          subject: _subjectController.text,
          message: _messageController.text,
          recipientIds: [_selectedContactId!],
          studentId: _selectedStudentId!,
          studentName: finalStudentName,
          authService: loginCtrl.authService,
          senderName: loginCtrl.getUser?.firstname ?? "Me",
        );

        // 🚨 DIAGNOSTIC 2: Check the Server Response
        // print("🌍 SERVER RESPONSE: $res");

        if (res['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Message sent!"), backgroundColor: Colors.green));
          }
          int newId = int.parse(res['data']['appCorrespondenceId'].toString());
          var dbRows = await repo.rawQuery(
              "SELECT * FROM ${TableNames.correspondences} WHERE id = $newId");
          print("💾 SQLITE FETCH: Found ${dbRows.length} rows for ID $newId");

          if (dbRows.isNotEmpty) {
            var newThread = CorrespondenceModel.fromSQLLiteMap(dbRows.first);
            Get.off(() => CorrespondenceDetailsScreen(item: newThread));
            return;
          } else {
            print(
                "❌ ERROR: Server succeeded, but SQLite could not find the inserted row!");
          }
        } else {
          print("❌ ERROR: Server returned success: false or empty response.");
        }
      }

      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Failed to send message."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ));
      }
    }
  }
}
