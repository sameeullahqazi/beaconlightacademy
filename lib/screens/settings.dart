import 'package:bla_flutter_app/components/app_header.dart';
import 'package:bla_flutter_app/components/app_footer.dart';
import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:bla_flutter_app/services/sercure_storage_service.dart';
import 'package:bla_flutter_app/themes/constants.dart';
import 'package:bla_flutter_app/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isObscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: "Settings",
        showBackButton: true,
        backgroundColor: AppColors.purplePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Save your user settings",
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),

            // --- Change Password Card ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Change Password",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 16),
                    _buildPasswordField("New Password", _newPassController),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                        "Confirm Password", _confirmPassController),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _handleSavePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.purplePrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text("SAVE",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),

            // --- Danger Zone (Reset Data) ---
            const Text("Troubleshooting",
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    "Experiencing issues? Resetting data will clear local storage and download fresh content.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _showResetConfirmation(context),
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text("RESET APP DATA",
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: _isObscure,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey),
          onPressed: () => setState(() => _isObscure = !_isObscure),
        ),
      ),
    );
  }

  void _handleSavePassword() async {
    // TODO: Implement Change Password API call
    if (_newPassController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Passwords do not match"),
          backgroundColor: Colors.red));
      return;
    }
    final loginCtrl = Provider.of<LoginController>(context, listen: false);
    final repo = loginCtrl.getDataRepository();

    if (repo != null) {
      // 1. Send to Repo (Queues + Network)
      var res = await repo.savePassword(
        password: _newPassController.text,
        authService: loginCtrl.authService,
        id: Provider.of<LoginController>(context, listen: false).getUser?.id ??
            loginCtrl.authService.userId,
      );
      // print("Save password response: $res");
      String username = (Provider.of<LoginController>(context, listen: false)
              .getUser
              ?.username ??
          await getLoggedInTopUser()
              .then((user) => user.username ?? "unknown"));
      // print("Attempting to save password for username: $username");
      if (res['success'] == true) {
        await SecureStorageService.instance.write(
          key: username,
          value: _newPassController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Password updated successfully"),
            backgroundColor: Colors.green));
        _newPassController.clear();
        _confirmPassController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Failed to update password: ${res['message']}"),
            backgroundColor: Colors.red));
      }
    }
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset All Data?"),
        content: const Text(
            "This will log you out and delete all local data. You will need to log in again.\n\nAre you sure?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close Dialog
              Provider.of<LoginController>(context, listen: false)
                  .clearAllData(context);
            },
            child: const Text("RESET",
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
