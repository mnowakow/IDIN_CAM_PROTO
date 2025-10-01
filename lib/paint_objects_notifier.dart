import 'package:flutter/material.dart';

class PaintObjectsNotifier extends ChangeNotifier{
  String _state = '';

  String get state => _state;

  void addObject(){
    _state = 'ADDING';
    notifyListeners();
  }

  void deleteObject(){
    _state = 'DELETING';
    notifyListeners();
  }

  void scalingObject(){
    _state = 'SCALING';
    notifyListeners();
  }

  void movingObject(){
    _state = 'MOVING';
    notifyListeners();
  }
}