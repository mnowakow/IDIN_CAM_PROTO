import 'package:flutter/foundation.dart';

enum SideBarWidget { none, miniView, bookmarks, colorPalette, camera, trash }

class SidebarNotifier extends ChangeNotifier {
  static final SidebarNotifier instance = SidebarNotifier._internal();

  factory SidebarNotifier() => instance;

  SidebarNotifier._internal();

  SideBarWidget _openSidebar = SideBarWidget.none;

  SideBarWidget get openSidebar => _openSidebar;

  set openSidebar(SideBarWidget value) {
    if (_openSidebar != value) {
      _openSidebar = value;
      notifyListeners();
    }
  }
}
