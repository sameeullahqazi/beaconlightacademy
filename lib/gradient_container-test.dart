import 'package:bla_flutter_app/dice_roller-test.dart';
import 'package:flutter/material.dart';

class GradientContainer extends StatelessWidget {
  const GradientContainer(
      this.startAlignment, this.endAlignment, this.gradientColors,
      {super.key});

  final Alignment startAlignment;
  final Alignment endAlignment;
  final List<Color> gradientColors;

  @override
  Widget build(context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: startAlignment,
          end: endAlignment,
        ),
      ),
      child: Center(
        child: DiceRoller(),
      ),
    );
  }
}
