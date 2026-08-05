import 'package:flutter/material.dart';
import 'package:bla_flutter_app/utils/breakpoints.dart';

InputDecoration cc2InputDecoration(context, label, errorText) {
  Size screenSize = MediaQuery.of(context).size;

  if (errorText != null) {
    return InputDecoration(
      border: const UnderlineInputBorder(),
      labelText: label,
      floatingLabelStyle: (screenSize.width > mobileWidthLowerLimit)
          ? const TextStyle()
          : const TextStyle(fontSize: 20),
      labelStyle: (screenSize.width > mobileWidthLowerLimit)
          ? const TextStyle()
          : const TextStyle(fontSize: 20),
      counterText: '',
      errorText: errorText,
    );
  } else {
    return InputDecoration(
      border: const UnderlineInputBorder(),
      labelText: label,
      floatingLabelStyle: (screenSize.width > mobileWidthLowerLimit)
          ? const TextStyle()
          : const TextStyle(fontSize: 20),
      labelStyle: (screenSize.width > mobileWidthLowerLimit)
          ? const TextStyle()
          : const TextStyle(fontSize: 20),
      counterText: '',
    );
  }
}

TextStyle cc2Heading1(context) {
  ColorScheme cc2Colors = Theme.of(context).colorScheme;
  Size screenSize = MediaQuery.of(context).size;

  return TextStyle(
    fontFamily: 'Montserrat',
    fontSize: (screenSize.width > mobileWidthLowerLimit) ? 32 : 28,
    fontWeight: FontWeight.w700,
    color: cc2Colors.onSurfaceVariant,
  );
}

TextStyle cc2Heading2(context) {
  ColorScheme cc2Colors = Theme.of(context).colorScheme;
  Size screenSize = MediaQuery.of(context).size;

  return TextStyle(
    fontFamily: 'Montserrat',
    fontSize: (screenSize.width > mobileWidthLowerLimit) ? 24 : 20,
    fontWeight: FontWeight.w700,
    color: cc2Colors.onSurfaceVariant,
  );
}

TextStyle cc2Heading3(context, {Color? color}) {
  ColorScheme cc2Colors = Theme.of(context).colorScheme;
  Color textColor = color ?? cc2Colors.onSurfaceVariant;

  return TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: textColor,
  );
}

TextStyle tableHeading(context, {Color? color}) {
  ColorScheme cc2Colors = Theme.of(context).colorScheme;
  Color textColor = color ?? cc2Colors.primary;

  return TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: textColor,
  );
}

TextStyle bodyText(context, {Color? color}) {
  ColorScheme cc2Colors = Theme.of(context).colorScheme;
  Size screenSize = MediaQuery.of(context).size;
  Color textColor = color ?? cc2Colors.onSurfaceVariant;

  return TextStyle(
    fontFamily: 'Roboto',
    fontSize: (screenSize.width > mobileWidthLowerLimit) ? 14 : 16,
    fontWeight: FontWeight.w400,
    color: textColor,
  );
}

TextStyle buttonText(context, {Color? color}) {
  ColorScheme cc2Colors = Theme.of(context).colorScheme;
  Color textColor = color ?? cc2Colors.onPrimary;

  return TextStyle(
    fontSize: 16,
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w600,
    color: textColor,
  );
}

TextStyle hyperlinkText(context, {int? bLocal}) {
  ColorScheme cc2Colors = Theme.of(context).colorScheme;

  return TextStyle(
    fontSize: 16,
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w600,
    color: bLocal == 1 ? cc2Colors.error : cc2Colors.surfaceTint,
    decoration: TextDecoration.underline,
  );
}

TextStyle labelText(context) {
  ColorScheme cc2Colors = Theme.of(context).colorScheme;

  return TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: cc2Colors.onSurfaceVariant,
  );
}

TextStyle infoText(context) {
  return const TextStyle(
    fontFamily: 'Roboto',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.blueAccent,
    // color: infoBlue,
  );
}

TextStyle navigationRailLink(context) {
  return const TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
}

TextStyle radioCheckboxLabel(context) {
  ColorScheme cc2Colors = Theme.of(context).colorScheme;

  return TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: cc2Colors.onSurface,
  );
}

TextStyle appBarTitleStyle(context) {
  Size screenSize = MediaQuery.of(context).size;

  if (screenSize.width > mobileWidthLowerLimit) {
    return const TextStyle(
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.w700,
      fontSize: 28,
    );
  } else {
    return const TextStyle(
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.w700,
    );
  }

  // return TextStyle(
  //   fontFamily: 'Montserrat',
  //   fontSize: 16,
  //   fontWeight: FontWeight.w600,
  //   color: cc2Colors.onSurface,
  // );
}
