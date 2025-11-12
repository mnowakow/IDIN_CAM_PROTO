import 'package:flutter/material.dart';
import 'package:idin_cam_prototype/filter_notifier.dart';
import 'package:idin_cam_prototype/scroll_notifier.dart';
import 'package:idin_cam_prototype/simple_pdf_viewer.dart';

class FilteredView extends StatefulWidget {
  final bool isMiniView;
  final ScrollNotifier scrollNotifier;
  const FilteredView({
    super.key,
    this.isMiniView = false,
    required this.scrollNotifier,
  });

  @override
  State<FilteredView> createState() => _FilteredViewState();
}

class _FilteredViewState extends State<FilteredView> {
  late final FilterNotifier filterNotifier;

  @override
  void initState() {
    super.initState();
    filterNotifier = FilterNotifier.instance;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    filterNotifier.addListener(_onFilterChanged);
  }

  void _onFilterChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    filterNotifier.removeListener(_onFilterChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SimplePdfViewer(
      pdfAssetPath: "assets/pdfs/lafiamma.pdf",
      isMiniview: widget.isMiniView,
      filter: filterNotifier.pages,
      scrollNotifier: widget.scrollNotifier,
      pageName: "filteredView",
      onPageTap: (int page) {
        if (widget.isMiniView) return;
        Navigator.of(context).pop();
        widget.scrollNotifier.scrollToPage(page);
      },
    );
  }
}
