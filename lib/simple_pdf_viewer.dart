import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:idin_cam_prototype/annotation.dart';
import 'package:idin_cam_prototype/annotation_notifier.dart';
import 'package:idin_cam_prototype/camera.dart';
import 'package:idin_cam_prototype/drawing.dart';
import 'package:idin_cam_prototype/filter_notifier.dart';
import 'package:idin_cam_prototype/helper.dart';
import 'package:idin_cam_prototype/menu_notifier.dart';
import 'package:idin_cam_prototype/pdf_document_provider.dart';
import 'package:idin_cam_prototype/spiral_menu.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:provider/provider.dart';
import 'package:svg_path_parser/svg_path_parser.dart';
import 'package:xml/xml.dart';
import 'package:vector_math/vector_math_64.dart' as vec;

import 'scroll_notifier.dart';

class SimplePdfViewer extends StatefulWidget {
  final String pdfAssetPath;
  final bool isMiniview;
  final List<int>? filter;
  final ValueChanged<int>? onPageTap;
  ScrollNotifier? scrollNotifier;

  SimplePdfViewer({
    super.key,
    required this.pdfAssetPath,
    required this.isMiniview,
    this.filter,
    this.onPageTap,
    this.scrollNotifier,
  });

  @override
  State<SimplePdfViewer> createState() => _SimplePdfViewerState();
}

class _SimplePdfViewerState extends State<SimplePdfViewer> {
  final GlobalKey _scrollViewKey = GlobalKey(debugLabel: "_scrollViewKey");
  final GlobalKey _cameraWindowKey = GlobalKey(debugLabel: "_cameraWindowKey");
  final GlobalKey pageKeyLeft = GlobalKey();
  final GlobalKey pageKeyRight = GlobalKey();
  late final MenuNotifier menuNotifier;
  bool spiralVisible = false;
  List<double> spiralPositions = [0, 0];
  Overlay symbolOverlay = Overlay();
  late final TransformationController _internalTfController;
  late final ScrollController _internalScrollController;
  double ownPageSize = 0.0;

  // Listener-Referenzen hinzufügen
  bool _disposed = false;
  VoidCallback? _menuListener;
  VoidCallback? _scrollListener;
  int _keyCounter = 0; // ← Eindeutige Keys

  @override
  void initState() {
    super.initState();
    _internalTfController = TransformationController();
    _internalScrollController = ScrollController();
    menuNotifier = MenuNotifier();
    context.read<PdfDocumentProvider>().load(widget.pdfAssetPath);

    final annotationNotifier = context.read<AnnotationNotifier>();
    annotationNotifier.scrollNotifier =
        widget.scrollNotifier ?? ScrollNotifier();
    annotationNotifier.scrollController = _internalScrollController;

    _scrollListener = () {
      if (_disposed || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.scrollNotifier?.scrollMode != ScrollMode.pageJump) return;
        final RenderBox? renderBoxLeft =
            pageKeyLeft.currentContext?.findRenderObject() as RenderBox?;
        final RenderBox? renderBoxRight =
            pageKeyRight.currentContext?.findRenderObject() as RenderBox?;
        if (renderBoxLeft != null) {
          ownPageSize = renderBoxLeft.size.height;
        } else if (renderBoxRight != null) {
          ownPageSize = renderBoxRight.size.height;
        } else {
          return;
        }
        _internalScrollController.jumpTo(
          ownPageSize * (widget.scrollNotifier?.targetPage ?? 0),
        );
      });
    };

    widget.scrollNotifier?.addListener(_scrollListener!);

    // Menu Listener SICHER hinzufügen
    _menuListener = () async {
      if (_disposed || !mounted) return;

      if (menuNotifier.lastAction == MenuAction.updateSelectedSymbol) {
        double svgWidth = 40.0;
        double svgHeight = 40.0;
        final svgString = await rootBundle.loadString(
          menuNotifier.selectedSymbolPath,
        );

        // Parse SVG XML um den Path zu extrahieren
        try {
          final document = XmlDocument.parse(svgString);
          final pathElements = document.findAllElements('path');

          if (pathElements.isNotEmpty) {
            final pathElement = pathElements.first;
            final pathData = pathElement.getAttribute('d');

            if (pathData != null) {
              final path = parseSvgPath(pathData);
              final bounds = path.getBounds();
              svgWidth = bounds.width;
              svgHeight = bounds.height;
            }
          }
        } catch (e) {
          print("Fehler beim Parsen der SVG: $e");
        }

        final svg = SvgPicture.asset(
          menuNotifier.selectedSymbolPath,
          width: svgWidth,
          height: svgHeight,
        );

        Offset svgPos = getTransformedOffset(
          menuNotifier.selectedSymbolPosition,
          _internalTfController,
          _internalScrollController.offset,
        );

        if (_disposed || !mounted) return;

        setState(() {
          spiralVisible = false;
          annotationNotifier.addAnnotation(
            Annotation(
              key: GlobalKey(debugLabel: 'svg_${_keyCounter++}'),
              annotationContent: svg,
              position: svgPos,
              annotationNotifier: annotationNotifier,
              scrollNotifier: widget.scrollNotifier!,
              scrollController: _internalScrollController,
            ),
          );
        });
      }
    };
    menuNotifier.addListener(_menuListener!);

    if (!widget.isMiniview) return;
  }

  @override
  void dispose() {
    _disposed = true;

    // ALLE Listener entfernen
    if (_menuListener != null) {
      menuNotifier.removeListener(_menuListener!);
    }

    if (_scrollListener != null) {
      widget.scrollNotifier?.removeListener(_scrollListener!);
    }

    _internalTfController.dispose();
    super.dispose();
  }

  Widget spiralMenu() {
    Offset o = Offset(spiralPositions[0], spiralPositions[1]);
    return Visibility(
      visible: spiralVisible,
      child: SpiralMenu(
        key: menuNotifier.spiralMenuKey,
        initialPosition: o,
        menuNotifier: menuNotifier,
      ),
    );
  }

  Widget view(
    itemCount,
    document,
    pageCount,
    annotations,
    transformationController,
  ) {
    return InteractiveViewer(
      transformationController: transformationController,
      panEnabled: true,
      scaleEnabled: true,
      minScale: 0.5,
      maxScale: 5.0,
      child: PdfView(
        key: _scrollViewKey,
        widget: widget,
        itemCount: itemCount,
        document: document,
        pageCount: pageCount,
        annotations: annotations,
        scrollController: _internalScrollController,
        pageKeyLeft: pageKeyLeft,
        pageKeyRight: pageKeyRight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pdfProvider = context.watch<PdfDocumentProvider>();
    final annotationNotifier = context.watch<AnnotationNotifier>();
    final document = pdfProvider.document;

    if (document == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pageCount = document.pages.length;
    final itemCount = (pageCount + 1) ~/ 2;

    return Scaffold(
      body: Listener(
        onPointerDown: (event) {
          final result = HitTestResult();
          final view = View.of(context);
          WidgetsBinding.instance.hitTestInView(
            result,
            event.position,
            view.viewId,
          );

          bool hitSpiral = result.path.any(
            (hit) =>
                hit.target ==
                menuNotifier.spiralMenuKey.currentContext?.findRenderObject(),
          );
          //print("Hit spiral: $hitSpiral");

          bool hitAnnot = false;
          for (final annot in annotationNotifier.annotations) {
            if (result.path.any((hit) {
              if (hit.target == annot.key?.currentContext?.findRenderObject()) {
                // Use a logging framework or handle as needed in production
                // print(
                //   "Hit annot: ${annot.annotationContent} at ${annot.position}; key ${annot.key}",
                // );
                return true;
              }
              return false;
            })) {
              hitAnnot = true;
              break;
            }
          }

          bool hitCamera = result.path.any(
            (hit) =>
                hit.target ==
                _cameraWindowKey.currentContext?.findRenderObject(),
          );
          //print("Hit camera: $hitCamera");

          if (event.kind == PointerDeviceKind.stylus) {
            if (hitAnnot || hitCamera) {
              setState(() {
                spiralVisible = false;
              });
              return;
            }
            setState(() {
              spiralVisible = spiralVisible && !hitSpiral ? false : true;
              if (spiralVisible) {
                spiralPositions = [event.position.dx, event.position.dy];
              }
            });
          }
        },
        child: GestureDetector(
          child: Stack(
            children: [
              view(
                itemCount,
                document,
                pageCount,
                annotationNotifier.annotations,
                _internalTfController,
              ),
              spiralMenu(),
              DrawingWidget(
                annotationNotifier: annotationNotifier,
                scrollNotifier: widget.scrollNotifier!,
                scrollController: _internalScrollController,
                transformController: _internalTfController,
              ),
              CameraWindow(
                key: _cameraWindowKey,
                annotationNotifier: annotationNotifier,
                transformationController: _internalTfController,
                scrollController: _internalScrollController,
              ),
            ],
          ),
        ),
      ),
      //),
    );
  }
}

class PdfView extends StatelessWidget {
  final SimplePdfViewer widget;
  final int itemCount;
  final pdfrx.PdfDocument? document;
  final int pageCount;
  final List<Annotation> annotations;
  final ScrollController scrollController;
  final GlobalKey pageKeyLeft;
  final GlobalKey pageKeyRight;

  const PdfView({
    super.key,
    required this.widget,
    required this.itemCount,
    required this.document,
    required this.pageCount,
    required this.annotations,
    required this.scrollController,
    required this.pageKeyLeft,
    required this.pageKeyRight,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        // Disable scrolling when using stylus
        if (scrollNotification is ScrollStartNotification) {
          final dragDetails = scrollNotification.dragDetails;
          if (dragDetails != null &&
              dragDetails.kind == PointerDeviceKind.stylus) {
            return true; // Consume the notification to prevent scrolling
          }
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: scrollController,
        child: Stack(
          children: [
            Column(
              children: List.generate(itemCount, (index) {
                int currentDoublePage = index + 1;
                if (widget.filter != null &&
                    !widget.filter!.contains(currentDoublePage)) {
                  return SizedBox.shrink(); // Skip this item if filtered
                }
                final leftPage = index * 2 + 1;
                final rightPage = index * 2 + 2;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  child: Stack(
                    children: [
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              key: leftPage == 1 ? pageKeyLeft : null,
                              child: GestureDetector(
                                onTap: () {
                                  if (widget.onPageTap != null) {
                                    widget.onPageTap!(leftPage);
                                  }
                                  if (widget.isMiniview) {
                                    widget.scrollNotifier?.scrollToPage(
                                      leftPage,
                                    );
                                  }
                                },
                                child: Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    pdfrx.PdfPageView(
                                      document: document,
                                      pageNumber: leftPage,
                                    ),
                                    if (widget.isMiniview)
                                      PageNumberBadge(pageNumber: leftPage),
                                  ],
                                ),
                              ),
                            ),
                            if (rightPage <= pageCount)
                              Expanded(
                                key: rightPage == 1 ? pageKeyRight : null,
                                child: GestureDetector(
                                  onTap: () {
                                    if (widget.onPageTap != null) {
                                      widget.onPageTap!(rightPage);
                                    }
                                    if (widget.isMiniview) {
                                      widget.scrollNotifier?.scrollToPage(
                                        rightPage,
                                      );
                                    }
                                  },
                                  child: Stack(
                                    alignment: Alignment.topCenter,
                                    children: [
                                      pdfrx.PdfPageView(
                                        document: document,
                                        pageNumber: rightPage,
                                      ),
                                      if (widget.isMiniview)
                                        PageNumberBadge(pageNumber: rightPage),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // if (!widget.isMiniview && widget.filter == null) ...[
                      //   BookmarkBadge(pageNumber: currentDoublePage),
                      // ],
                    ],
                  ),
                );
              }),
            ),
            if (!widget
                .isMiniview) // only keep instances of annotations in the main view. Miniview would add annotations to widget tree, with diplicate globalkeys
              Positioned.fill(child: Stack(children: annotations)),
          ],
        ),
      ),
    );
  }
}

class PageNumberBadge extends StatelessWidget {
  final int pageNumber;

  const PageNumberBadge({super.key, required this.pageNumber});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$pageNumber',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class BookmarkBadge extends StatefulWidget {
  final int pageNumber;

  const BookmarkBadge({super.key, required this.pageNumber});

  @override
  State<StatefulWidget> createState() => _BookmarkState();
}

class _BookmarkState extends State<BookmarkBadge> {
  bool isBookmarked = false;
  final FilterNotifier filterNotifier = FilterNotifier.instance;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: FloatingActionButton(
          backgroundColor: isBookmarked ? Colors.red : Colors.black54,
          onPressed: () {
            setState(() {
              isBookmarked = !isBookmarked;
              if (isBookmarked) {
                filterNotifier.addPage(widget.pageNumber);
              } else {
                filterNotifier.removePage(widget.pageNumber);
              }
            });
          },
          child: Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
