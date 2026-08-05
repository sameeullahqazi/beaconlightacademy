import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/screens/user_manual.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const Color navyBlue = Color(0xFF041434);
const Color goldAccent = Color(0xFFFFC107);

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: navyBlue,
      child: SizedBox(
        height: 65, // Slightly taller to accommodate larger icons
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildFooterButton(
              Icons.settings,
              "Settings",
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
            Consumer<LoginController>(
              builder: (context, loginCtrl, child) {
                final isCooldown = loginCtrl.isSyncCooldown;

                return _buildFooterButton(
                  Icons.refresh,
                  isCooldown ? "Wait..." : "Refresh",
                  iconColor:
                      isCooldown ? goldAccent.withOpacity(0.4) : goldAccent,
                  // Dim the white text slightly if in cooldown
                  textColor:
                      isCooldown ? Colors.white.withOpacity(0.5) : Colors.white,
                  onTap: () {
                    loginCtrl.manualSync(context);
                  },
                );
              },
            ),
            _buildFooterButton(
              Icons.help,
              "Help",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserManualScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ UPDATED: Separated iconColor and textColor logic, increased sizes
  Widget _buildFooterButton(IconData icon, String text,
      {VoidCallback? onTap, Color? iconColor, Color? textColor}) {
    final finalIconColor = iconColor ?? goldAccent;
    final finalTextColor = textColor ?? Colors.white;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: finalIconColor,
            size: 28, // 🚀 Increased icon size!
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              color: finalTextColor, // 🚀 Forced to White
              fontSize: 13, // Slightly larger font
              fontWeight: FontWeight.bold, // 🚀 Made it prominent!
            ),
          ),
        ],
      ),
    );
  }
}
