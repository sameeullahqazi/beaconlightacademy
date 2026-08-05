import 'dart:math';
import 'package:flutter/material.dart';

var randomizer = Random();
class DiceRoller extends StatefulWidget {
  const DiceRoller({super.key});

  @override
  State<DiceRoller> createState() {
    return _DiceRollerState();
  }
}

class _DiceRollerState extends State<DiceRoller> {
  var diceRoll = 1;
  void rollDice() {
    setState(() {
      diceRoll = randomizer.nextInt(6) + 1;
    });
  }

  @override
  Widget build(context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/dice-$diceRoll.png',
          width: 200,
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: rollDice,
          child: const Text("Roll!"),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: TextStyle(
              fontSize: 28,
            ),
          ),
        )
      ],
    );
  }
}
