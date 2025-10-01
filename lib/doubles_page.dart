import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

class DoublesPage extends StatelessWidget {
  //final ScrollController scrollController;
  final Offset offset;
  final PageController scrollController;

  const DoublesPage(this.scrollController, this.offset, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pdfrx.PdfDocumentViewBuilder.asset(
        'assets/pdfs/lafiamma.pdf',
        builder: (context, document) {
          final pageCount = document?.pages.length ?? 0;
          // Jede Zeile zeigt 2 Seiten, also itemCount = (pageCount + 1) ~/ 2
          final itemCount = (pageCount + 1) ~/ 2;
          return ListView.builder(
            controller: scrollController,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              return Container(
                child: _pageLayout(context, document, index, pageCount),
              );
            },
            hitTestBehavior: HitTestBehavior.translucent,
          );
        },
      ),
    );
  }

  Widget _pageLayout(
    BuildContext context,
    var document,
    int index,
    int pageCount,
  ) {
    // Berechne die Seitenzahlen für die aktuelle Zeile
    final leftPage = index * 2 + 1;
    final rightPage = index * 2 + 2;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child:
                  leftPage <= pageCount
                      ? pdfrx.PdfPageView(
                        document: document,
                        pageNumber: leftPage,
                      )
                      : Container(),
            ),
            Expanded(
              child:
                  rightPage <= pageCount
                      ? pdfrx.PdfPageView(
                        document: document,
                        pageNumber: rightPage,
                      )
                      : Container(),
            ),
          ],
        ),
      ],
    );
  }
}
