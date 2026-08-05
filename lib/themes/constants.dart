import 'package:flutter/material.dart';

const TextStyle kTitleStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
    fontFamily: "Verdana, Arial", // Replace if needed
    color: Color.fromARGB(221, 19, 124, 45));

const TextStyle kSubtitleStyle = TextStyle(
  fontSize: 16,
  color: Colors.grey,
);

const TextStyle kSubjectStyle = TextStyle(
  fontWeight: FontWeight.w600,
  color: Colors.blueGrey,
);

const Color bgDarkGreen = Color.fromARGB(255, 0, 114, 130);
const Color footerIconColor = Color.fromARGB(255, 192, 192, 192);

class AppTextStyles {
  // Classwork/Notices
  static const TextStyle subjectTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color.fromARGB(255, 8, 148, 5),
  );

  static const TextStyle message = TextStyle(
    fontSize: 16,
    color: AppColors.secondaryText,
  );

  static const TextStyle subTitle = TextStyle(
    fontSize: 16,
    color: Color.fromARGB(255, 62, 184, 66),
  );

  static const TextStyle classInfo = TextStyle(
    fontSize: 14,
    color: AppColors.greyText,
  );

  static const TextStyle date = TextStyle(
    fontSize: 14,
    color: AppColors.greyText,
  );

  static const TextStyle cardTitle = TextStyle(fontWeight: FontWeight.bold);
  static const TextStyle cardSubtitle = TextStyle(color: Colors.grey);
}

class AppColors {
  static const Color unreadHighlight = Color(0xFFE3F2FD); // Light blue
  static const Color primaryText = Color(0xFF212121);
  static const Color secondaryText = Color(0xFF424242);
  static const Color greyText = Color(0xFF757575);
  static const Color bgDarkGreen = Color(0xFF1A5F1A); // Reused everywhere
  static const Color tabBarGreen =
      Color.fromARGB(255, 77, 178, 82); // Slightly lighter for tabs
  static const Color purplePrimary = Color(0xFF6A1B9A); // Deep purple
}
