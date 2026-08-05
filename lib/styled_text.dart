import 'package:flutter/material.dart';

class StyledText extends StatelessWidget {
  const StyledText(this.text, this.fontSize, this.fontStyle, this.color, {super.key});
  final String text;
  final double fontSize;
  final FontStyle fontStyle;
  final Color color;
  @override
  Widget build(context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontStyle: fontStyle,
        color: color,
      ),
    );
  }
}
