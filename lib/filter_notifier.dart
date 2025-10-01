import 'package:flutter/foundation.dart';

class FilterNotifier extends ChangeNotifier {
  static final FilterNotifier instance = FilterNotifier._internal();

  factory FilterNotifier() => instance;

  FilterNotifier._internal();

  final List<int> _pages = [];

  List<int> get pages => List.unmodifiable(_pages);

  void addPage(int page) {
    _pages.add(page);
    notifyListeners();
  }

  void removePage(int page) {
    _pages.remove(page);
    notifyListeners();
  }

  void clearPages() {
    _pages.clear();
    notifyListeners();
  }
}
