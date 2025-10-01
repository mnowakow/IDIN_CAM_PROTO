import 'package:flutter/material.dart';
import 'package:idin_cam_prototype/annotation.dart';
import 'package:idin_cam_prototype/annotation_notifier.dart';
import 'package:idin_cam_prototype/helper.dart';
import 'package:idin_cam_prototype/scroll_notifier.dart';
import 'package:idin_cam_prototype/sidebar_notifier.dart';
import "dart:ui";
import 'package:idin_cam_prototype/stylus_notifier.dart';

class DrawingWidget extends StatefulWidget {
  final Function(List<Offset>)? onAnnotationComplete;
  final AnnotationNotifier annotationNotifier;
  final ScrollNotifier scrollNotifier;
  final ScrollController scrollController;
  final TransformationController transformController;

  const DrawingWidget({
    Key? key,
    this.onAnnotationComplete,
    required this.annotationNotifier,
    required this.scrollNotifier,
    required this.scrollController,
    required this.transformController,
  }) : super(key: key);

  @override
  State<DrawingWidget> createState() => _DrawingWidgetState();
}

class _DrawingWidgetState extends State<DrawingWidget> {
  List<Offset?> points = [];
  bool isStylusActive = false;
  bool isPaletteOpen = false;

  bool getIsPaletteOpen() {
    return SidebarNotifier.instance.openSidebar == SideBarWidget.colorPalette;
  }

  @override
  void initState() {
    SidebarNotifier.instance.addListener(() {
      bool currentlyOpen = getIsPaletteOpen();
      if (currentlyOpen != isPaletteOpen) {
        setState(() {
          isPaletteOpen = currentlyOpen;
        });
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!isPaletteOpen) {
      return SizedBox.shrink(); // ← Leeres Widget, fängt keine Events ab
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Listener(
        // Behavior anpassen - nur verarbeiten wenn Stylus UND Palette offen
        behavior:
            HitTestBehavior
                .translucent, // ← Lässt Events durch wenn nicht verarbeitet
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.stylus && isPaletteOpen) {
            setState(() {
              isStylusActive = true;
              RenderBox renderBox = context.findRenderObject() as RenderBox;
              points.add(renderBox.globalToLocal(event.position));
            });
          }
        },
        onPointerMove: (event) {
          // Nur verarbeiten wenn Stylus aktiv ist UND Palette offen
          if (isStylusActive &&
              event.kind == PointerDeviceKind.stylus &&
              isPaletteOpen) {
            setState(() {
              RenderBox renderBox = context.findRenderObject() as RenderBox;
              points.add(renderBox.globalToLocal(event.position));
            });
          }
        },
        onPointerUp: (event) {
          if (isStylusActive && event.kind == PointerDeviceKind.stylus) {
            setState(() {
              isStylusActive = false;
              points.add(null);
            });
            _saveAnnotation();
          }
        },
        child: CustomPaint(
          painter: DrawingPainter(
            points: points,
            isStylusActive: isStylusActive,
            isPaletteOpen: isPaletteOpen,
          ),
          willChange: isStylusActive || points.isNotEmpty,
          size: Size.infinite,
          child: Container(),
        ),
      ),
    );
  }

  void _saveAnnotation() {
    if (points.isEmpty) return;

    List<Offset> validPoints =
        points.where((point) => point != null).cast<Offset>().toList();

    if (validPoints.isEmpty) return;

    // Berechne Bounding Box der Zeichnung
    final bounds = _calculateBounds(validPoints);
    Offset pos = Offset(bounds.left, bounds.top);
    pos = getTransformedOffset(
      pos,
      widget.transformController,
      widget.scrollController.offset,
    );

    // Erstelle CustomPaint Widget mit der Zeichnung
    final drawingWidget = SizedBox(
      width: bounds.width,
      height: bounds.height,
      child: CustomPaint(
        painter: DrawingPainter(
          points: _normalizePoints(validPoints, bounds),
          isStylusActive: isStylusActive,
          isPaletteOpen: isPaletteOpen,
        ),
        size: Size(bounds.width, bounds.height),
      ),
    );

    widget.annotationNotifier.addAnnotation(
      Annotation(
        key: GlobalKey(
          debugLabel: 'drawing_${DateTime.now().millisecondsSinceEpoch}',
        ),
        annotationContent: drawingWidget,
        position: pos,
        annotationNotifier: widget.annotationNotifier,
        scrollNotifier: widget.scrollNotifier,
        scrollController: widget.scrollController,
      ),
    );

    // Zeichnung nach dem Speichern löschen
    clearDrawing();

    widget.onAnnotationComplete?.call(validPoints);
  }

  Rect _calculateBounds(List<Offset> points) {
    if (points.isEmpty) return Rect.zero;

    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (final point in points) {
      minX = point.dx < minX ? point.dx : minX;
      maxX = point.dx > maxX ? point.dx : maxX;
      minY = point.dy < minY ? point.dy : minY;
      maxY = point.dy > maxY ? point.dy : maxY;
    }

    const padding = 10.0;
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  List<Offset?> _normalizePoints(List<Offset> points, Rect bounds) {
    return points
        .map((point) => Offset(point.dx - bounds.left, point.dy - bounds.top))
        .cast<Offset?>()
        .toList();
  }

  void clearDrawing() {
    setState(() {
      points.clear();
      isStylusActive = false;
    });
  }
}

class DrawingPainter extends CustomPainter {
  final List<Offset?> points;
  final bool? isStylusActive;
  final bool? isPaletteOpen;

  DrawingPainter({
    required this.points,
    this.isStylusActive,
    this.isPaletteOpen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    //print("Is Palette Open: $isPaletteOpen, Is Stylus Active: $isStylusActive");
    // Nur zeichnen wenn Palette offen ist
    if (!(isPaletteOpen == true)) return;

    Paint paint =
        Paint()
          ..color = Colors.redAccent
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 5.0
          ..style = PaintingStyle.stroke;

    // Path-basiertes Zeichnen für glattere Linien
    Path path = Path();
    bool pathStarted = false;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];

      if (point == null) {
        // Stroke-Ende
        if (pathStarted) {
          canvas.drawPath(path, paint);
          path = Path();
          pathStarted = false;
        }
      } else {
        if (!pathStarted) {
          path.moveTo(point.dx, point.dy);
          pathStarted = true;
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
    }

    // Letzten Path zeichnen
    if (pathStarted) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
