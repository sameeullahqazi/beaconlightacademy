import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:bla_flutter_app/components/app_header.dart'; // Assuming you use your custom header
import 'package:bla_flutter_app/themes/constants.dart';

class UserManualScreen extends StatelessWidget {
  const UserManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: "USER MANUAL",
        showBackButton: true,
        backgroundColor: AppColors.purplePrimary, // Adjust to match your theme
      ),
      // ✅ This single widget handles rendering, zooming, and scrolling the PDF!
      body: SfPdfViewer.asset(
        'assets/user-manual.pdf',
        canShowScrollHead: false,
        canShowScrollStatus: false,
      ),
    );
  }
}
