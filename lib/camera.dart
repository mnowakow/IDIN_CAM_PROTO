import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:idin_cam_prototype/annotation.dart';
import 'package:idin_cam_prototype/annotation_notifier.dart';
import 'package:idin_cam_prototype/helper.dart';
import 'package:idin_cam_prototype/scroll_notifier.dart';
import 'package:idin_cam_prototype/sidebar_notifier.dart';
import 'package:video_player/video_player.dart';

List<CameraDescription> _cameras = [];

class CameraWindow extends StatefulWidget {
  final AnnotationNotifier annotationNotifier;
  final TransformationController transformationController;
  final ScrollController scrollController;
  const CameraWindow({
    super.key,
    required this.annotationNotifier,
    required this.transformationController,
    required this.scrollController,
  });

  @override
  State<CameraWindow> createState() => _CameraWindowState();
}

class _CameraWindowState extends State<CameraWindow> {
  CameraController? _controller;
  SideBarWidget currentWidget = SideBarWidget.none;
  bool _isInitialized = false;
  bool _isInitializing = false;
  Offset _position = Offset(50, 100);
  double _width = 200 * 3;
  double _height = 150 * 3;
  GlobalKey _cameraKey = GlobalKey(debugLabel: "_cameraKey");
  bool _isRecording = false;
  Color _recordButtonColor = Colors.transparent;
  bool _disposed = false; // ← Neues Flag hinzufügen

  @override
  void initState() {
    super.initState();
    _initializeCameras();

    SidebarNotifier.instance.addListener(_handleSidebarChange);
  }

  void _handleSidebarChange() {
    if (_disposed) return; // ← Schutz vor disposed Widget

    final previousWidget = currentWidget;
    currentWidget = SidebarNotifier.instance.openSidebar;

    if (mounted) {
      setState(() {});
    }

    // Kamera-Logik nur wenn Widget noch mounted ist
    if (mounted) {
      if (currentWidget == SideBarWidget.camera &&
          previousWidget != SideBarWidget.camera) {
        // Kamera wird geöffnet - Initialisierung mit Verzögerung
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted && !_disposed) {
            _ensureCameraInitialized();
          }
        });
      } else if (currentWidget != SideBarWidget.camera &&
          previousWidget == SideBarWidget.camera) {
        // Kamera wird geschlossen - sanft disposen
        _disposeCamera();
      }
    }
  }

  Future<void> _initializeCameras() async {
    if (_disposed) return;

    try {
      _cameras = await availableCameras();
      print('Available cameras: ${_cameras.length}');
    } catch (e) {
      debugPrint('Error initializing cameras: $e');
    }
  }

  // Robuste Kamera-Initialisierung
  Future<void> _ensureCameraInitialized() async {
    if (_disposed || !mounted) return;

    if (_isInitializing || _isInitialized) {
      return; // Bereits initialisiert oder gerade dabei
    }

    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_disposed || !mounted) return;

    if (_cameras.isEmpty) {
      print('No cameras available');
      return;
    }

    if (_isInitializing) {
      print('Camera initialization already in progress');
      return;
    }

    _isInitializing = true;

    try {
      // Dispose alten Controller falls vorhanden
      if (!_disposed && mounted) {
        await _disposeCamera();
      }

      if (_disposed || !mounted) {
        return; // ← Prüfung nach dispose
      }

      print('Initializing camera...');
      _controller = CameraController(
        _cameras[0],
        ResolutionPreset.high, // ← Niedrigere Auflösung für schnellere Init
      );

      // Initialisierung mit Timeout
      await _controller!.initialize().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
            'Camera initialization timeout',
            Duration(seconds: 10),
          );
        },
      );

      if (_disposed || !mounted) {
        // Widget wurde während Initialisierung disposed
        await _controller?.dispose();
        _controller = null;
        return;
      }

      // Sichere setState-Ausführung
      if (mounted && !_disposed) {
        setState(() {
          _isInitialized = true;
          _position = Offset(
            MediaQuery.of(context).size.width / 2 - _width / 2,
            MediaQuery.of(context).size.height / 2 - _height / 2,
          );
        });
      }

      print('Camera initialized successfully');
    } catch (e) {
      debugPrint('Error initializing camera: $e');

      if (mounted && !_disposed) {
        setState(() {
          _isInitialized = false;
        });
      }

      // Controller cleanup bei Fehler
      try {
        await _controller?.dispose();
      } catch (disposeError) {
        debugPrint(
          'Error disposing controller after init failure: $disposeError',
        );
      }
      _controller = null;
    } finally {
      if (mounted && !_disposed) {
        setState(() {
          _isInitializing = false;
        });
      } else {
        _isInitializing = false;
      }
    }
  }

  Future<void> _disposeCamera() async {
    if (_controller != null) {
      try {
        await _controller!.dispose();
        print('Camera disposed');
      } catch (e) {
        debugPrint('Error disposing camera: $e');
      }
      _controller = null;

      if (mounted && !_disposed) {
        setState(() {
          _isInitialized = false;
        });
      } else {
        _isInitialized = false;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true; // ← Flag setzen

    // Listener entfernen
    SidebarNotifier.instance.removeListener(_handleSidebarChange);

    // Kamera disposen
    _disposeCamera();

    super.dispose();
  }

  // Sichere setState-Methode
  void _safeSetState(VoidCallback fn) {
    if (mounted && !_disposed) {
      setState(fn);
    }
  }

  Future<void> _takePicture() async {
    if (_disposed || _controller == null || !_controller!.value.isInitialized)
      return;

    try {
      final XFile image = await _controller!.takePicture();

      if (_disposed || !mounted) return;

      final imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(image.path),
          fit: BoxFit.cover,
          width: _width,
          height: _height,
        ),
      );

      Offset imgPos = getTransformedOffset(
        _position,
        widget.transformationController,
        widget.scrollController.offset,
      );

      widget.annotationNotifier.addAnnotation(
        Annotation(
          key: GlobalKey(
            debugLabel: "img_${DateTime.now().millisecondsSinceEpoch}",
          ),
          annotationContent: imageWidget,
          position: imgPos,
          annotationNotifier: widget.annotationNotifier,
          scrollNotifier: ScrollNotifier(),
          scrollController: widget.scrollController,
        ),
      );
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isRecording)
      return;

    try {
      await _controller!.startVideoRecording();
      _isRecording = true;

      Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!_isRecording) {
          timer.cancel();
          setState(() => _recordButtonColor = Colors.transparent);
          return;
        }
        setState(() {
          _recordButtonColor =
              _recordButtonColor == Colors.red.withOpacity(0.8)
                  ? Colors.red.withOpacity(0.2)
                  : Colors.red.withOpacity(0.8);
        });
      });

      setState(() {});
    } catch (e) {
      debugPrint('Error starting video recording: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        !_isRecording)
      return;

    try {
      final XFile video = await _controller!.stopVideoRecording();
      _isRecording = false;
      _recordButtonColor = Colors.transparent;
      setState(() {});

      final videoController = VideoPlayerController.file(File(video.path));
      await videoController.initialize();
      await videoController.seekTo(Duration.zero);

      final videoWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: _width,
          height: _height,
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
                      setState(() {
                        if (videoController.value.isPlaying) {
                          videoController.pause();
                        } else {
                          videoController.play();
                        }
                      });
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

      Offset vidPos = getTransformedOffset(
        _position,
        widget.transformationController,
        widget.scrollController.offset,
      );

      widget.annotationNotifier.addAnnotation(
        Annotation(
          key: GlobalKey(
            debugLabel: "vid_${DateTime.now().millisecondsSinceEpoch}",
          ),
          annotationContent: videoWidget,
          position: vidPos,
          annotationNotifier: widget.annotationNotifier,
          scrollNotifier: ScrollNotifier(),
          scrollController: widget.scrollController,
        ),
      );
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_disposed) {
      return Container(); // ← Schutz für disposed Widget
    }

    // Loading-Indikator während Initialisierung
    if (currentWidget == SideBarWidget.camera && _isInitializing) {
      return Positioned(
        left: 50,
        top: 100,
        child: Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 10),
                Text(
                  'Kamera wird initialisiert...',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized ||
        _controller == null ||
        !_controller!.value.isInitialized ||
        currentWidget != SideBarWidget.camera) {
      return Container();
    }

    // Rest der build-Methode bleibt gleich...
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Row(
        children: [
          GestureDetector(
            onPanUpdate: (details) {
              _safeSetState(() => _position += details.delta);
            },
            child: Stack(
              children: [
                Container(
                  key: _cameraKey,
                  width: _width,
                  height: _height,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CameraPreview(_controller!),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      double delta =
                          (details.delta.dx.abs() > details.delta.dy.abs())
                              ? details.delta.dx
                              : details.delta.dy;
                      setState(() {
                        _width += delta;
                        _height = _width * 150 / 200; // fixed aspect ratio
                        if (_width < 150) _width = 150;
                        if (_height < 100) _height = 100;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.zoom_out_map_outlined, size: 40),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: _height,
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: _takePicture,
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  iconSize: 20,
                ),
                Container(
                  decoration: BoxDecoration(
                    color:
                        _isRecording ? _recordButtonColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    onPressed: () {
                      if (_isRecording) {
                        _stopVideoRecording();
                      } else {
                        _startVideoRecording();
                      }
                    },
                    icon: const Icon(Icons.videocam, color: Colors.white),
                    iconSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
