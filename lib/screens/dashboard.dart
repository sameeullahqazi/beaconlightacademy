import 'package:bla_flutter_app/controllers/dashboard_controller.dart';
import 'package:bla_flutter_app/components/app_header.dart';
import 'package:bla_flutter_app/components/app_footer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardState();
}

class _DashboardState extends State<DashboardScreen> {
  // Use a flag to ensure we only fetch once on mount
  bool _isInit = true;

  // ✅ NEW COLOR THEME
  final Color navyBlue = const Color(0xFF041434);
  final Color goldAccent = const Color(0xFFFFC107);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      Provider.of<DashboardController>(context, listen: false).refreshCounts();
      _isInit = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardController>(
      builder: (context, dashboardCtrl, child) {
        return Scaffold(
          // ✅ Slight off-white background to make the white cards pop
          backgroundColor: Colors.grey[100],
          appBar: AppHeader(
            title: "Dashboard",
            notificationCount: dashboardCtrl.totalUnread,
          ),
          body: _buildBody(dashboardCtrl),
          bottomNavigationBar: const AppFooter(),
        );
      },
    );
  }

  Widget _buildBody(DashboardController ctrl) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              _buildMenuCard(
                title: "Diary",
                subtitle: "Classwork/Notices",
                imgPath: "assets/images/diary3.png",
                routeName: '/diary',
                badgeCount: ctrl.unreadDiaries,
              ),
              const SizedBox(width: 16),
              _buildMenuCard(
                title: "Correspondence",
                subtitle: "Talk to teachers",
                imgPath: "assets/images/correspondence3.png",
                routeName: '/correspondence',
                badgeCount: ctrl.unreadCorrespondences,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required String imgPath,
    required String routeName,
    int badgeCount = 0,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, routeName),
        // ✅ FIX 1: The Stack is now OUTSIDE the Card so the badge can float!
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Card(
              elevation: 4,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: navyBlue,
                      border: Border(
                        bottom: BorderSide(color: goldAccent, width: 4.0),
                      ),
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Image.asset(
                      imgPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 20.0, horizontal: 8.0),
                    child: Column(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: navyBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ✅ FIX 2: Pushed the badge up and right to hang off the edge
            if (badgeCount > 0)
              Positioned(
                right: -6, // Pushes it past the right edge
                top: -6, // Pushes it past the top edge
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    // ✅ Added a white border to make it pop against the navy
                    border: Border.all(color: Colors.white, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount > 99 ? "99+" : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
