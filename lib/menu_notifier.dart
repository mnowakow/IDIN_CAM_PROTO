import 'package:flutter/material.dart';

enum MenuAction { none, updateSelectedSymbol, menuTapped }

class MenuNotifier extends ChangeNotifier {
  String _selectedSymbolPath = '';
  Offset _selectedSymbolPosition = Offset.zero;
  MenuAction menuAction = MenuAction.none;
  final GlobalKey _spiralMenuKey = GlobalKey(debugLabel: 'spiralMenuKey');

  String get selectedSymbolPath => _selectedSymbolPath;
  Offset get selectedSymbolPosition => _selectedSymbolPosition;
  MenuAction get lastAction => menuAction;
  GlobalKey get spiralMenuKey => _spiralMenuKey;

  void updateSelectedSymbol(String selectedSymbolPath, Offset position) {
    if (selectedSymbolPath.isEmpty) return;
    _selectedSymbolPath = selectedSymbolPath;
    _selectedSymbolPosition = position;
    menuAction = MenuAction.updateSelectedSymbol;
    notifyListeners();
  }

  void menuTapped() {
    print("Menu tapped");
    menuAction = MenuAction.menuTapped;
    notifyListeners();
  }

  void resetAction() {
    menuAction = MenuAction.none;
  }
}
