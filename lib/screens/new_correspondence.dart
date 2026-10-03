import 'package:bla_flutter_app/components/app_header.dart';
import 'package:bla_flutter_app/components/app_footer.dart';
import 'package:bla_flutter_app/components/searchable_picker_sheet.dart';
import 'package:bla_flutter_app/constants/table_names_strings.dart';
import 'package:bla_flutter_app/controllers/dashboard_controller.dart';
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

  String? _currentStudentId;

  String? _selectedClassId;
  String? _selectedContactId; // The Parent ID / Teacher ID
  String? _selectedStudentId; // The Student ID

  bool _isLoading = true;
  bool _isSending = false;
  bool _isStaff = false;

  @override
  void initState() {
    super.initState();
    final dashCtrl = Provider.of<DashboardController>(context, listen: false);
    _currentStudentId = dashCtrl.selectedStudentId;
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
        final userStudents = loginCtrl.getUser?.studentList ?? [];
        _students = userStudents
            .map((s) => {'id': s.id, 'name': s.studentName})
            .toList();

        // 1. Map the global header selection to the local form state
        if (_currentStudentId != null && _currentStudentId != 'all') {
          _selectedStudentId = _currentStudentId;
        } else if (_students.isNotEmpty) {
          _selectedStudentId = _students.first['id'];
        }

        // 2. Apply the filter so the Teacher dropdown populates correctly
        _filterParentContacts();
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

  void _filterParentContacts() {
    if (_selectedStudentId == null) return;

    // Filter contacts where the studentId matches the local dropdown selection
    _filteredContacts = _allContacts
        .where((c) => c['studentId'] == _selectedStudentId)
        .toList();

    // Reset the teacher selection so they must actively pick a valid one
    _selectedContactId = null;
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
                      _buildPickerField(
                        selectedId: _selectedClassId,
                        items: _classes,
                        idKey: 'id',
                        labelKey: 'className',
                        placeholder: 'Select Class',
                        searchHint: 'Search classes...',
                        emptyText: 'No matching classes.',
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
                      // contacts maps one student to multiple entries (e.g.
                      // several subject-teachers, or multiple registered
                      // parents - see the "SQLite Relational Mapping" note
                      // in CLAUDE.md for this exact one-to-many pattern), so
                      // filtering by class alone produces duplicate
                      // studentId values here. Dedupe to one entry per
                      // student, keeping the first (same contact the
                      // onSelected lookup below would already pick via
                      // firstWhere).
                      _buildPickerField(
                        selectedId: _selectedStudentId,
                        items: {
                          for (final c in _filteredContacts) c['studentId']!: c
                        }.values.toList(),
                        idKey: 'studentId',
                        labelKey: 'name',
                        placeholder: 'Select Student',
                        searchHint: 'Search students...',
                        emptyText: 'No matching students.',
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
                      const Text("Select Student",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      _buildPickerField(
                        selectedId: _selectedStudentId,
                        items: _students,
                        idKey: 'id',
                        labelKey: 'name',
                        placeholder: 'Select Student',
                        searchHint: 'Search students...',
                        emptyText: 'No matching students.',
                        onSelected: (val) {
                          setState(() {
                            _selectedStudentId = val;
                            _filterParentContacts(); // Updates the teacher list!
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text("Select Contact (Teacher)",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      _buildPickerField(
                        selectedId: _selectedContactId,
                        items: _filteredContacts,
                        idKey: 'id',
                        labelKey: 'name',
                        placeholder: 'Select Contact',
                        searchHint: 'Search teachers...',
                        emptyText: 'No matching teachers.',
                        onSelected: (val) =>
                            setState(() => _selectedContactId = val),
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

  // ✅ Tap target that opens the shared searchable bottom-sheet picker,
  // styled to match the form's other fields. Replaces DropdownMenu
  // throughout this screen after hitting three separate bugs with it here:
  // a RangeError crash on a large class list (155 classes), the student
  // list silently narrowing to one entry because enableFilter treats
  // initialSelection's pre-filled text as an active search query, and the
  // same underlying issue making the contact field look like search wasn't
  // working at all.
  Widget _buildPickerField({
    required String? selectedId,
    required List<Map<String, String>> items,
    required String idKey,
    required String labelKey,
    required String placeholder,
    required String searchHint,
    required String emptyText,
    required ValueChanged<String> onSelected,
  }) {
    return InkWell(
      onTap: () => showSearchablePicker(
        context: context,
        items: items,
        idKey: idKey,
        labelKey: labelKey,
        selectedId: selectedId,
        searchHint: searchHint,
        emptyText: emptyText,
        onSelected: onSelected,
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey.shade400)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                selectedId != null
                    ? (items.firstWhere(
                          (i) => i[idKey] == selectedId,
                          orElse: () => {labelKey: placeholder},
                        )[labelKey] ??
                        placeholder)
                    : placeholder,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
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
