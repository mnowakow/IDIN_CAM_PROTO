import 'package:flutter/foundation.dart';

class StylusNotifier extends ChangeNotifier {
  static final StylusNotifier instance = StylusNotifier._internal();

  factory StylusNotifier() => instance;

  StylusNotifier._internal();

  bool _isStylusActive = false;

  bool get isStylusActive => _isStylusActive;

  set isStylusActive(bool value) {
    if (_isStylusActive != value) {
      _isStylusActive = value;
      notifyListeners();
    }
  }
}
