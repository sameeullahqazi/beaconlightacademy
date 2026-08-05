import 'package:flutter/material.dart';

class MyCustomUserState with ChangeNotifier {
  String _username = "";
  String get username => _username;
  set username(String pUsername) {
    _username = pUsername;
    notifyListeners();
  }
}
