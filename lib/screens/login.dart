import 'package:bla_flutter_app/controllers/login_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // UI State Variables
  bool _isPasswordVisible = false;
  String? _errorMessage;
  bool _isLoading = false;

  // ✅ NEW COLOR THEME (From Mockup)
  final Color navyBlue = const Color(0xFF041434);
  final Color goldAccent = const Color(0xFFFFC107);

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginController = Provider.of<LoginController>(context);

    return Scaffold(
      appBar: null,
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ✅ FIX 1: New Navy Header with Gold Border & Larger Logo
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: navyBlue,
              border: Border(
                bottom: BorderSide(color: goldAccent, width: 4.0),
              ),
            ),
            padding: const EdgeInsets.only(
                top: 60, bottom: 20), // Added top padding for notch/status bar
            child: Center(
              child: Image.asset(
                'assets/images/logo.png',
                color: Colors.white,
                height: 160, // 🚀 Significantly larger logo size
              ),
            ),
          ),

          // Scrollable login form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Title styling matching mockup
                  Text(
                    "LOG IN",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: navyBlue,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 45,
                    height: 3,
                    color: goldAccent, // 🚀 Gold underline beneath 'LOG'
                  ),
                  const SizedBox(height: 30),

                  // Username Field
                  TextField(
                    controller: _usernameController,
                    onChanged: (_) => setState(() => _errorMessage = null),
                    decoration: InputDecoration(
                      labelText: "Username",
                      helperText:
                          "Enter your username", // ✅ FIX 2: Helper text below field
                      helperStyle:
                          const TextStyle(color: Colors.grey, fontSize: 12),
                      prefixIcon: Icon(Icons.person, color: navyBlue),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.0),
                        borderSide:
                            const BorderSide(color: Colors.grey, width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.0),
                        borderSide: BorderSide(color: navyBlue, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 12),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    onChanged: (_) => setState(() => _errorMessage = null),
                    decoration: InputDecoration(
                      labelText: "Password",
                      helperText:
                          "Enter your password", // ✅ FIX 2: Helper text below field
                      helperStyle:
                          const TextStyle(color: Colors.grey, fontSize: 12),
                      prefixIcon: Icon(Icons.lock, color: navyBlue),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: navyBlue.withOpacity(0.8),
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.0),
                        borderSide: BorderSide(
                            color: _errorMessage != null
                                ? Colors.red
                                : Colors.grey,
                            width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.0),
                        borderSide: BorderSide(
                            color:
                                _errorMessage != null ? Colors.red : navyBlue,
                            width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 12),
                    ),
                  ),

                  // INLINE ERROR MESSAGE
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 40),

                  // Login Button
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            // 1. Validate Input
                            loginController.username =
                                _usernameController.text.trim();
                            loginController.password =
                                _passwordController.text.trim();

                            if (loginController.username.isEmpty ||
                                loginController.password.isEmpty) {
                              setState(() {
                                _errorMessage =
                                    "Please enter username and password";
                              });
                              return;
                            }

                            // 2. Start Loading
                            setState(() {
                              _errorMessage = null;
                              _isLoading = true;
                            });

                            // 3. Perform Login
                            await loginController.login(context: context);

                            // 4. Handle Failure
                            if (mounted) {
                              if (loginController.getUser == null) {
                                setState(() {
                                  _isLoading = false;
                                  _errorMessage =
                                      "Invalid credentials, missing students, or inactive user. Please check your details and try again.";
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navyBlue, // 🚀 Mockup Navy Button
                      disabledBackgroundColor: navyBlue.withOpacity(0.6),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            "LOG IN",
                            style: TextStyle(
                              fontSize: 16,
                              color: goldAccent, // 🚀 Mockup Gold Text
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),

                  const SizedBox(height: 40),

                  // ✅ FIX 3: Secure Login Visual Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: goldAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Secure login to ensure your data is protected",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ✅ Mockup Bottom Border styling
          Container(
            height: 20,
            decoration: BoxDecoration(
              color: navyBlue,
              border: Border(
                top: BorderSide(color: goldAccent, width: 3.0),
              ),
            ),
          )
        ],
      ),
    );
  }
}
