import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:idin_cam_prototype/drawing.dart';
import 'package:idin_cam_prototype/scroll_notifier.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'annotation.dart';

class AnnotationNotifier extends ChangeNotifier {
  final List<Annotation> _annotations = [];
  static const String _fileName = 'annotations.json';
  ScrollNotifier sn = ScrollNotifier();
  ScrollController sc = ScrollController();

  List<Annotation> get annotations => List.unmodifiable(_annotations);
  ScrollNotifier get scrollNotifier => sn;
  ScrollController get scrollController => sc;

  set scrollNotifier(ScrollNotifier notifier) {
    sn = notifier;
    // Verzögere notifyListeners() bis nach dem Build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  set scrollController(ScrollController controller) {
    // Setze den ScrollController für alle bestehenden Annotations
    sc = controller;
    // Verzögere notifyListeners() bis nach dem Build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // Initialize and load saved annotations
  Future<void> initialize() async {
    await _loadAnnotations();
  }

  void addAnnotation(Annotation annotation) {
    _annotations.add(annotation);
    notifyListeners();
    _saveAnnotations(); // Auto-save when adding
  }

  void removeAnnotationByKey(GlobalKey key) {
    _annotations.removeWhere((annotation) => annotation.key == key);
    notifyListeners();
    _saveAnnotations(); // Auto-save when removing
  }

  void updateAnnotation(
    GlobalKey key, {
    Offset? newPosition,
    double? newScale,
    double? newWidth,
    double? newHeight,
  }) {
    final index = _annotations.indexWhere(
      (annotation) => annotation.key == key,
    );
    if (index != -1) {
      final oldAnnotation = _annotations[index];
      final newAnnotation = Annotation(
        key: oldAnnotation.key,
        annotationContent: oldAnnotation.annotationContent,
        position: newPosition ?? oldAnnotation.position,
        scale: newScale ?? oldAnnotation.scale,
        annotationNotifier: this,
        scrollNotifier: sn,
        scrollController: sc,
      );
      _annotations[index] = newAnnotation;
      notifyListeners();
      _saveAnnotations(); // Auto-save when updating
    }
  }

  String? _currentUser;

  // Set the current user (call this after login)
  void setCurrentUser(String? userName) {
    _currentUser = userName;
  }

  // Get filename based on current user
  String get _currentFileName {
    final user = _currentUser ?? 'default';
    return 'annotations_$user.json';
  }

  // Save annotations to local file
  Future<void> _saveAnnotations() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_currentFileName');

      // Convert annotations to JSON
      List<Map<String, dynamic>> annotationsJson =
          _annotations.map((annotation) {
            return {
              'position': {
                'dx': annotation.position.dx,
                'dy': annotation.position.dy,
              },
              'scale': annotation.scale,
              'content_type': _getContentType(annotation.annotationContent),
              'content_data': _serializeContent(annotation.annotationContent),
              'timestamp': DateTime.now().toIso8601String(),
            };
          }).toList();

      await file.writeAsString(json.encode(annotationsJson));
      print('Annotations saved: ${annotationsJson.length} items');
    } catch (e) {
      print('Error saving annotations: $e');
    }
  }

  // Load annotations from local file
  Future<void> _loadAnnotations() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_currentFileName');

      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> annotationsJson = json.decode(content);

        _annotations.clear();

        for (var annotationData in annotationsJson) {
          try {
            final position = Offset(
              annotationData['position']['dx'].toDouble(),
              annotationData['position']['dy'].toDouble(),
            );

            final scale = (annotationData['scale'] ?? 1.0).toDouble();

            final content = _deserializeContent(
              annotationData['content_type'],
              annotationData['content_data'],
            );

            if (content != null) {
              final annotation = Annotation(
                key: GlobalKey(),
                annotationContent: content,
                position: position,
                scale: scale,
                annotationNotifier: this,
                scrollNotifier: sn,
                scrollController: sc,
              );
              _annotations.add(annotation);
            }
          } catch (e) {
            print('Error loading annotation: $e');
          }
        }

        print('Annotations loaded: ${_annotations.length} items');
        notifyListeners();
      }
    } catch (e) {
      print('Error loading annotations: $e');
    }
  }

  // Helper method to identify content type
  String _getContentType(Widget content) {
    if (content is Text) return 'text';
    if (content is Icon) return 'icon';
    if (content is SvgPicture) return 'svg';
    if (content is SizedBox) {
      // Prüfe ob es ein DrawingWidget ist
      if (content.child is CustomPaint) {
        final customPaint = content.child as CustomPaint;
        if (customPaint.painter is DrawingPainter) {
          return 'drawing'; // ← Neuer Content-Typ für Zeichnungen
        }
      }
    }
    if (content is ClipRRect) {
      if (content.child is Image) return 'image';
      if (content.child is SizedBox) {
        final sizedBox = content.child as SizedBox;
        if (sizedBox.child is Stack) {
          final stack = sizedBox.child as Stack;
          bool hasVideoPlayer = stack.children.any(
            (child) => child.runtimeType.toString().contains('VideoPlayer'),
          );
          if (hasVideoPlayer) return 'video';
        }
      }
    }
    return 'unknown';
  }

  // Serialize widget content to JSON
  Map<String, dynamic> _serializeContent(Widget content) {
    if (content is Text) {
      return {
        'data': content.data ?? '',
        'style':
            content.style != null
                ? {
                  'fontSize': content.style?.fontSize,
                  'color': content.style?.color?.value,
                }
                : null,
      };
    }
    if (content is Icon) {
      return {
        'icon': content.icon?.codePoint,
        'size': content.size,
        'color': content.color?.value,
      };
    }
    if (content is SvgPicture) {
      SvgAssetLoader? contentLoader = content.bytesLoader as SvgAssetLoader?;
      return {
        'type': 'asset',
        'assetPath': contentLoader?.assetName ?? '',
        'width': content.width,
        'height': content.height,
      };
    }
    if (content is SizedBox) {
      // Serialisiere DrawingWidget
      if (content.child is CustomPaint) {
        final customPaint = content.child as CustomPaint;
        if (customPaint.painter is DrawingPainter) {
          final drawingPainter = customPaint.painter as DrawingPainter;
          return {
            'type': 'drawing',
            'width': content.width,
            'height': content.height,
            'points': _serializeDrawingPoints(drawingPainter.points),
            'strokeColor': Colors.black.value, // Standard-Farbe
            'strokeWidth': 3.0, // Standard-Strichstärke
          };
        }
      }
    }
    if (content is ClipRRect) {
      if (content.child is Image) {
        final image = content.child as Image;
        final fileImage = image.image as FileImage?;
        final file = fileImage?.file as File?;
        final path = file?.path;

        return {
          'type': 'image',
          'imagePath': path ?? "",
          'fit': image.fit?.toString(),
          'width': image.width,
          'height': image.height,
        };
      }
      // Für VideoPlayer Widget (verschachtelt in ClipRRect)
      if (content.child is SizedBox) {
        final sizedBox = content.child as SizedBox;

        if (sizedBox.child is Stack) {
          final stack = sizedBox.child as Stack;
          // Prüfe ob VideoPlayer im Stack ist
          VideoPlayer? vp;
          String? path;
          bool hasVideoPlayer = stack.children.any((child) {
            if (child.runtimeType.toString().contains('VideoPlayer')) {
              vp = child as VideoPlayer;
              return true;
            }
            return false;
          });

          if (vp != null) {
            path = vp?.controller.dataSource;
            path = path?.replaceFirst('file://', '');
          }

          if (hasVideoPlayer && path != null) {
            return {
              'type': 'video',
              'width': sizedBox.width,
              'height': sizedBox.height,
              'videoPath': path,
            };
          }
        }
      }
    }
    return {};
  }

  // Helper-Methode zum Serialisieren der Drawing-Points
  List<Map<String, dynamic>?> _serializeDrawingPoints(List<Offset?> points) {
    return points.map((point) {
      if (point == null) {
        return null; // Stroke-Ende
      } else {
        return {'dx': point.dx, 'dy': point.dy};
      }
    }).toList();
  }

  // Helper-Methode zum Deserialisieren der Drawing-Points
  List<Offset?> _deserializeDrawingPoints(List<dynamic> pointsData) {
    return pointsData.map((pointData) {
      if (pointData == null) {
        return null; // Stroke-Ende
      } else {
        return Offset(pointData['dx'].toDouble(), pointData['dy'].toDouble());
      }
    }).toList();
  }

  // Deserialize JSON back to widget
  Widget? _deserializeContent(String contentType, Map<String, dynamic> data) {
    switch (contentType) {
      case 'text':
        return Text(
          data['data'] ?? '',
          style:
              data['style'] != null
                  ? TextStyle(
                    fontSize: data['style']['fontSize']?.toDouble(),
                    color:
                        data['style']['color'] != null
                            ? Color(data['style']['color'])
                            : null,
                  )
                  : null,
        );
      case 'icon':
        return Icon(
          data['icon'] != null ? IconData(data['icon']) : Icons.help,
          size: data['size']?.toDouble(),
          color: data['color'] != null ? Color(data['color']) : null,
        );
      case 'svg':
        return SvgPicture.asset(
          data['assetPath'],
          width: data['width']?.toDouble(),
          height: data['height']?.toDouble(),
        );
      case 'drawing':
        // Deserialisiere DrawingWidget
        final points = _deserializeDrawingPoints(data['points'] ?? []);
        return SizedBox(
          width: data['width']?.toDouble(),
          height: data['height']?.toDouble(),
          child: CustomPaint(
            painter: DrawingPainter(
              points: points,
              isStylusActive: false, // ← Gespeicherte Zeichnung ist statisch
              isPaletteOpen: true,
            ),
            size: Size(
              data['width']?.toDouble() ?? 100,
              data['height']?.toDouble() ?? 100,
            ),
          ),
        );
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(data['imagePath']),
            fit: BoxFit.cover,
            width: data['width']?.toDouble(),
            height: data['height']?.toDouble(),
          ),
        );
      case 'video':
        // Create and initialize video controller
        final videoController = VideoPlayerController.file(
          File(data['videoPath']),
        );

        return FutureBuilder(
          future: videoController.initialize(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: data['width']?.toDouble(),
                  height: data['height']?.toDouble(),
                  child: Stack(
                    children: [
                      VideoPlayer(videoController),
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () {
                              if (videoController.value.isPlaying) {
                                videoController.pause();
                              } else {
                                videoController.play();
                              }
                            },
                            icon: Icon(
                              videoController.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              return SizedBox(
                width: data['width']?.toDouble(),
                height: data['height']?.toDouble(),
                child: const Center(child: CircularProgressIndicator()),
              );
            }
          },
        );
      default:
        return Text('Restored annotation'); // Fallback
    }
  }

  // Manual save method (optional)
  Future<void> saveToFile() async {
    await _saveAnnotations();
  }

  // Clear all annotations
  Future<void> clearAll() async {
    _annotations.clear();
    notifyListeners();
    await _saveAnnotations();
  }
}
