import 'package:flutter/material.dart';
import 'package:idin_cam_prototype/scroll_notifier.dart';
import 'package:idin_cam_prototype/simple_pdf_viewer.dart';

class MiniView extends StatelessWidget {
  final String pdfAssetPath;
  final ScrollNotifier scrollNotifier;

  const MiniView({
    super.key,
    required this.pdfAssetPath,
    required this.scrollNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return SimplePdfViewer(
      pdfAssetPath: pdfAssetPath,
      isMiniview: true,
      filter: null,
      scrollNotifier: scrollNotifier,
    );
  }
}
