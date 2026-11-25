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
    // Scrollable: the un-scrolled Column here previously assumed its content
    // always fit the available body height, which held while there were
    // only 2 cards (1 row) - adding the Report Cards row pushed total
    // content height past what fits on some screen sizes/densities,
    // overflowing at the bottom ("Bottom overflowed by 55 pixels").
    return SingleChildScrollView(
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
          const SizedBox(height: 16),
          Row(
            children: [
              // Own row below Diary, half-width, empty space on the right
              // under Correspondence - matches the approved mockup layout.
              _buildMenuCard(
                title: "Report Cards",
                subtitle: "View grades",
                // TODO: still a placeholder (a hand-drawn graph-with-axes,
                // not the hand-illustrated artwork Diary/Correspondence use
                // - gradients, shading, a 3D pen) - swap for a real
                // illustrated asset matching the other two before this
                // ships. Custom-painted rather than a built-in Material
                // icon so it actually shows axis lines, per Samee's
                // explicit ask (2026-11-25) after Icons.leaderboard's bars
                // read as floating with no axes.
                customIcon: const _ReportCardsGraphIcon(),
                routeName: '/report-cards',
                badgeCount: ctrl.unreadReportCards,
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox.shrink()),
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
    String? imgPath,
    IconData? icon,
    Widget? customIcon,
    required String routeName,
    int badgeCount = 0,
  }) {
    assert(imgPath != null || icon != null || customIcon != null,
        '_buildMenuCard needs an imgPath, icon, or customIcon');
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
                    child: customIcon ??
                        (icon != null
                            ? Icon(icon, color: goldAccent, size: 56)
                            : Image.asset(imgPath!, fit: BoxFit.contain)),
                  ),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 20.0, horizontal: 8.0),
                    child: Column(
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          style: TextStyle(
                            color: navyBlue,
                            fontSize: 15,
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

// ✅ Report Cards dashboard icon (2026-11-25) - a real axes+bars graph,
// custom-painted rather than a built-in Material icon (Icons.leaderboard's
// bars read as floating with no axes, which didn't match what Samee asked
// for specifically). Still a placeholder relative to Diary/Correspondence's
// hand-illustrated artwork - see the TODO at this widget's call site.
class _ReportCardsGraphIcon extends StatelessWidget {
  const _ReportCardsGraphIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 56,
        height: 56,
        child: CustomPaint(painter: _GraphIconPainter()),
      ),
    );
  }
}

class _GraphIconPainter extends CustomPainter {
  const _GraphIconPainter();

  static const Color goldAccent = Color(0xFFFFC107);

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = goldAccent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final barPaint = Paint()..color = goldAccent;

    const double originX = 7;
    const double originY = 48;
    const double axisTopY = 4;
    const double axisRightX = 52;

    // Axis lines (the "L" the bars sit inside).
    canvas.drawLine(
        const Offset(originX, axisTopY), const Offset(originX, originY), axisPaint);
    canvas.drawLine(
        const Offset(originX, originY), const Offset(axisRightX, originY), axisPaint);

    // Three ascending bars, left to right.
    const double barWidth = 9;
    const double gap = 5;
    final heights = [14.0, 24.0, 34.0];
    double x = originX + gap;
    for (final barHeight in heights) {
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, originY - barHeight, barWidth, barHeight),
        topLeft: const Radius.circular(1.5),
        topRight: const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, barPaint);
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _GraphIconPainter oldDelegate) => false;
}
