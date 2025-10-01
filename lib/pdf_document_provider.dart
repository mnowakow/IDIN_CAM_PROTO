import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfDocumentProvider extends ChangeNotifier {
  PdfDocument? _document;

  PdfDocument? get document => _document;

  Future<PdfDocument?> load(String assetPath) async {
    if (_document != null) {
      return _document;
    }
    _document = await PdfDocument.openAsset(assetPath);
    notifyListeners();
    return _document;
  }
}
