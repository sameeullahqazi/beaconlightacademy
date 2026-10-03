import 'package:bla_flutter_app/controllers/dashboard_controller.dart';
import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/models/student_model.dart';
// import 'package:bla_flutter_app/themes/constants.dart'; // No longer strictly needed if colors are localized
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ✅ NEW COLOR THEME
const Color navyBlue = Color(0xFF041434);
const Color goldAccent = Color(0xFFFFC107);

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final int notificationCount;
  // ✅ Opt-in search support, used by the Diary and Correspondence list
  // screens in place of the bell icon (which has never done anything -
  // onPressed was always a no-op). Left false/null everywhere else so
  // every other screen using this header is unaffected.
  final bool showSearch;
  final bool isSearching;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchToggle;

  const AppHeader({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.notificationCount = 0,
    Color backgroundColor = navyBlue, // ✅ Default to Navy Blue
    this.showSearch = false,
    this.isSearching = false,
    this.searchController,
    this.onSearchChanged,
    this.onSearchToggle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // 1. Listen to Controllers
    final loginCtrl = Provider.of<LoginController>(context);
    final dashboardCtrl = Provider.of<DashboardController>(context);

    // Get current user and active student ID
    final user = loginCtrl.getUser;
    final selectedStudentId = dashboardCtrl.selectedStudentId;

    // Default Name if null
    final displayName = user != null
        ? "${user.firstname ?? ''} ${user.lastname ?? ''}".trim()
        : "Guest";

    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: navyBlue, // ✅ Updated to Navy Blue
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.home, color: Colors.white),
                onPressed: () => Navigator.pushNamed(context, '/dashboard'),
              ),
        title: (showSearch && isSearching)
            ? TextField(
                controller: searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: "Search...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: onSearchChanged,
              )
            : Text(title, style: const TextStyle(color: Colors.white)),
        actions: [
          if (showSearch)
            IconButton(
              icon: Icon(isSearching ? Icons.close : Icons.search,
                  color: Colors.white),
              onPressed: onSearchToggle,
            )
          else
            // Bell Icon with Global Count (Badge defaults to Red)
            IconButton(
              icon: Badge(
                isLabelVisible: notificationCount > 0,
                label: Text(notificationCount.toString()),
                child: const Icon(Icons.notifications, color: Colors.white),
              ),
              onPressed: () {},
            ),

          // 2. DYNAMIC DROPDOWN
          _buildStudentDropdown(
              context, displayName, user?.studentList ?? [], selectedStudentId),

          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset('assets/images/logo.png', width: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDropdown(BuildContext context, String userName,
      List<StudentModel> students, String? selectedId) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.person, color: Colors.white),
      offset: const Offset(0, 50),
      onSelected: (value) => _handleSelection(value, context),
      itemBuilder: (context) {
        List<PopupMenuEntry<String>> items = [];

        // Header (User Name)
        items.add(_buildMenuHeader(userName));
        items.add(const PopupMenuDivider());

        // "Show All" Option
        items.add(_buildMenuItem(
            id: "all",
            text: "Show All",
            icon: Icons.all_inclusive,
            isSelected: selectedId == null));

        // Dynamic Student List
        for (var student in students) {
          items.add(_buildMenuItem(
              id: student.id,
              text: student.studentName,
              icon: Icons.school,
              isSelected: selectedId == student.id));
        }

        // Footer (Logout)
        items.add(const PopupMenuDivider());
        items.add(_buildMenuItem(
            id: "logout",
            text: "Log Out",
            icon: Icons.logout,
            isDestructive: true));

        return items;
      },
    );
  }

  PopupMenuItem<String> _buildMenuHeader(String title) {
    return PopupMenuItem<String>(
      enabled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87),
          ),
          const Text(
            'Select a student to filter data.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem({
    required String id,
    required String text,
    required IconData icon,
    bool isSelected = false,
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: id,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3F2FD) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Icon(icon,
                size: 20, color: isDestructive ? Colors.red : Colors.grey[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isDestructive ? Colors.red : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 18, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  void _handleSelection(String value, BuildContext context) {
    if (value == 'logout') {
      _confirmLogout(context);
    } else {
      final dashboardCtrl =
          Provider.of<DashboardController>(context, listen: false);

      if (value == "all") {
        dashboardCtrl.selectStudent(null);
      } else {
        dashboardCtrl.selectStudent(value);
      }
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<LoginController>(context, listen: false)
                  .logoutOrExit();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
            },
            child: const Text("Log Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
