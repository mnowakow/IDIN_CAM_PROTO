import 'package:flutter/material.dart';

class LoginPageNotifier extends ChangeNotifier {
  String _username = "";

  String get username => _username;

  void loggedIn(String username){
    _username = username;
    notifyListeners();
  }
}