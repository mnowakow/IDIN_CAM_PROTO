import 'package:flutter/material.dart';

enum ScrollMode { pageJump, smoothScroll, none }

class ScrollNotifier extends ChangeNotifier {
  final ScrollController sc = ScrollController();

  int page = 0;
  int get targetPage => (page / 2).ceil() - 1; // adjusted for double page
  ScrollMode mode = ScrollMode.none;
  ScrollMode get scrollMode => mode;

  void scrollToPage(int index) {
    page = index;
    mode = ScrollMode.pageJump;
    notifyListeners();
  }

  void scrollBy(double offset, ScrollController scrollController) {
    scrollController.jumpTo(scrollController.offset + offset);
    mode = ScrollMode.smoothScroll;
    notifyListeners();
  }
}
