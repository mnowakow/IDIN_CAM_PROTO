import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:idin_cam_prototype/scroll_notifier.dart';
import 'package:vector_graphics/vector_graphics.dart' as vg;
import 'package:idin_cam_prototype/annotation_notifier.dart';
import 'package:idin_cam_prototype/sidebar_notifier.dart';

class Annotation extends StatefulWidget {
  final Widget annotationContent;
  final Offset position;
  final double scale;
  @override
  final GlobalKey key;
  final AnnotationNotifier annotationNotifier;
  final ScrollNotifier scrollNotifier;
  final ScrollController scrollController;

  const Annotation({
    required this.key,
    required this.annotationContent,
    required this.position,
    required this.annotationNotifier,
    required this.scrollNotifier,
    required this.scrollController,
    this.scale = 1.0,
  });

  @override
  _AnnotationState createState() => _AnnotationState();
}

class _AnnotationState extends State<Annotation> {
  late Offset _position;
  late double _width;
  late double _height;
  bool _isTapped = false;
  bool _isDragging = false;

  bool _disposed = false;
  VoidCallback? _sidebarListener;

  double _getAnnotationWidth() {
    if (widget.annotationContent is SvgPicture) {
      return (widget.annotationContent as SvgPicture).width! / 10;
    } else if (widget.annotationContent is Image) {
      return (widget.annotationContent as Image).width?.toDouble() ?? 200;
    } else if (widget.annotationContent is SizedBox) {
      final sizedBox = widget.annotationContent as SizedBox;
      return sizedBox.width?.toDouble() ?? 200;
    } else if (widget.annotationContent is ClipRRect) {
      final clipRRect = widget.annotationContent as ClipRRect;
      if (clipRRect.child is SizedBox) {
        final sizedBox = clipRRect.child as SizedBox;
        return sizedBox.width?.toDouble() ?? 200;
      }
      if (clipRRect.child is Image) {
        final image = clipRRect.child as Image;
        return image.width?.toDouble() ?? 200;
      }
    }
    return 200;
  }

  double _getAnnotationHeight() {
    if (widget.annotationContent is SvgPicture) {
      return (widget.annotationContent as SvgPicture).height! / 10;
    } else if (widget.annotationContent is Image) {
      return (widget.annotationContent as Image).height?.toDouble() ?? 200;
    } else if (widget.annotationContent is SizedBox) {
      final sizedBox = widget.annotationContent as SizedBox;
      return sizedBox.height?.toDouble() ?? 200;
    } else if (widget.annotationContent is ClipRRect) {
      final clipRRect = widget.annotationContent as ClipRRect;
      if (clipRRect.child is SizedBox) {
        final sizedBox = clipRRect.child as SizedBox;
        return sizedBox.height?.toDouble() ?? 200;
      }
      if (clipRRect.child is Image) {
        final image = clipRRect.child as Image;
        return image.height?.toDouble() ?? 200;
      }
    }
    return 200;
  }

  @override
  void initState() {
    super.initState();
    _position = widget.position;
    _width = _getAnnotationWidth();
    _height = _getAnnotationHeight();

    // Listener SICHER hinzufügen
    _sidebarListener = () {
      if (_disposed || !mounted) return;

      if (SidebarNotifier.instance.openSidebar == SideBarWidget.trash) {
        widget.annotationNotifier.clearAll();
      }

      if (_disposed || !mounted) return;
      setState(() {
        // Rebuild to show/hide resize handle
      });
    };
    SidebarNotifier.instance.addListener(_sidebarListener!);

    // SVG Position anpassen
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_disposed || !mounted) return;

      if (widget.annotationContent is SvgPicture) {
        setState(() {
          _position = widget.position - Offset(_width / 2, _height / 2);
        });
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;

    // Listener ENTFERNEN
    if (_sidebarListener != null) {
      SidebarNotifier.instance.removeListener(_sidebarListener!);
    }

    super.dispose();
  }

  // Sichere setState Methode
  void _safeSetState(VoidCallback fn) {
    if (_disposed || !mounted) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          _safeSetState(() {
            _isDragging = true;

            // Auto-scroll when near screen edges
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final scrollThreshold =
                200.0; // Distance from edge to trigger scroll

            // Calculate distances from edges
            final distanceFromTop = details.globalPosition.dy;
            final distanceFromBottom = screenHeight - details.globalPosition.dy;
            final distanceFromLeft = details.globalPosition.dx;
            final distanceFromRight = screenWidth - details.globalPosition.dx;

            // Calculate scroll speeds for both axes
            final verticalScrollSpeed =
                distanceFromTop < scrollThreshold
                    ? (scrollThreshold - distanceFromTop) /
                            scrollThreshold *
                            20.0 +
                        2.0
                    : distanceFromBottom < scrollThreshold
                    ? (scrollThreshold - distanceFromBottom) /
                            scrollThreshold *
                            20.0 +
                        2.0
                    : 0.0;

            final horizontalScrollSpeed =
                distanceFromLeft < scrollThreshold
                    ? (scrollThreshold - distanceFromLeft) /
                            scrollThreshold *
                            20.0 +
                        2.0
                    : distanceFromRight < scrollThreshold
                    ? (scrollThreshold - distanceFromRight) /
                            scrollThreshold *
                            20.0 +
                        2.0
                    : 0.0;

            double verticalOffset = 0.0;
            double horizontalOffset = 0.0;

            // Handle vertical scrolling
            if (distanceFromTop < scrollThreshold) {
              // Near top edge - scroll up
              widget.scrollNotifier.scrollBy(
                -verticalScrollSpeed,
                widget.scrollController,
              );
              verticalOffset = -verticalScrollSpeed;
            } else if (distanceFromBottom < scrollThreshold) {
              // Near bottom edge - scroll down
              widget.scrollNotifier.scrollBy(
                verticalScrollSpeed,
                widget.scrollController,
              );
              verticalOffset = verticalScrollSpeed;
            }

            // Handle horizontal scrolling (if your scroll notifier supports it)
            if (distanceFromLeft < scrollThreshold) {
              // Near left edge - scroll left
              // widget.notifier.scrollNotifier.scrollHorizontallyBy(-horizontalScrollSpeed);
              horizontalOffset = -horizontalScrollSpeed;
            } else if (distanceFromRight < scrollThreshold) {
              // Near right edge - scroll right
              // widget.notifier.scrollNotifier.scrollHorizontallyBy(horizontalScrollSpeed);
              horizontalOffset = horizontalScrollSpeed;
            }

            _position +=
                details.delta + Offset(horizontalOffset, verticalOffset);

            // Prevent position from going above the top edge or left edge
            if (_position.dy < 0) {
              _position = Offset(_position.dx, 0);
            }
            if (_position.dx < 0) {
              _position = Offset(0, _position.dy);
            }
          });
        },
        onPanCancel: () => print("Pan cancelled"),
        onPanEnd: (details) {
          _safeSetState(() => _isDragging = false);
          widget.annotationNotifier.updateAnnotation(
            widget.key,
            newPosition: _position,
          );
        },
        onTap: () => _safeSetState(() => _isTapped = !_isTapped),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: _width,
              height: _height,
              decoration:
                  _isTapped || _isDragging
                      ? BoxDecoration(
                        border: Border.all(
                          color: Colors.blueGrey.shade100,
                          width: 5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.blueGrey.shade50.withOpacity(0.3),
                      )
                      : null,
              child: FittedBox(
                fit: BoxFit.fill,
                child: widget.annotationContent,
              ),
            ),
            if (_isTapped) ...[
              // Positioned(
              //   // Resize handle
              //   right: 0,
              //   bottom: 0,
              //   child: GestureDetector(
              //     onPanUpdate: (details) {
              //       setState(() {
              //         _width += details.delta.dx;
              //         _height += details.delta.dy;
              //         if (_width < 20) _width = 20;
              //         if (_height < 20) _height = 20;
              //       });
              //     },
              //     onPanEnd:
              //         (details) => {
              //           widget.annotationNotifier.updateAnnotation(
              //             widget.key,
              //             newWidth: _width,
              //             newHeight: _height,
              //           ),
              //         },
              //     onTap: () => {print('Resize tapped')},
              //     child: Container(
              //       width: 40,
              //       height: 40,
              //       decoration: BoxDecoration(
              //         color: Colors.amber,
              //         border: Border.all(color: Colors.black),
              //         borderRadius: BorderRadius.circular(8),
              //       ),
              //       child: const Center(
              //         child: Icon(Icons.zoom_out_map_outlined, size: 40),
              //       ),
              //     ),
              //   ),
              // ),
              // Positioned(
              //   // Delete button
              //   top: 0,
              //   right: 0,
              //   child: GestureDetector(
              //     onTapUp:
              //         (details) => {
              //           widget.annotationNotifier.removeAnnotationByKey(
              //             widget.key,
              //           ),
              //         },
              //     child: Container(
              //       width: 40,
              //       height: 40,
              //       decoration: BoxDecoration(
              //         color: Colors.grey.shade300,
              //         border: Border.all(color: Colors.black),
              //         borderRadius: BorderRadius.circular(8),
              //       ),
              //       child: const Center(child: Icon(Icons.delete, size: 40)),
              //     ),
              //   ),
              // ),
            ],
          ],
        ),
      ),
    );
  }
}
