import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return MaterialApp(
      title: "Flutter App 2",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 40, 9, 87),
                Color.fromARGB(255, 53, 3, 146),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/quiz-logo.png',
                  width: 300,
                ),
                const Text(
                  'Learn Flutter the fun way!',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 193, 164, 204),
                  ),
                ),
                const ElevatedButton(
                  onPressed: null,
                  child: Text(
                    "Start Quiz!",
                    style: TextStyle(
                      color: Color.fromARGB(255, 193, 164, 204),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
