import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show DiagnosticPropertiesBuilder, rootBundle;
import 'dart:convert';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:idin_cam_prototype/menu_notifier.dart';
import 'package:idin_cam_prototype/sidebar_notifier.dart';

class SpiralMenu extends StatefulWidget {
  final Offset initialPosition;
  static const double centerRadius = 30;
  static const double spiralElementRadius = 30;
  final MenuNotifier menuNotifier;

  Future<List<String>> loadSvgFiles() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    return manifestMap.keys
        .where(
          (String key) =>
              key.startsWith('assets/symbols/') && key.endsWith('.svg'),
        )
        .toList();
  }

  const SpiralMenu({
    super.key,
    required this.initialPosition,
    required this.menuNotifier,
  });

  @override
  State<SpiralMenu> createState() => _SpiralMenuState();
}

// Custom painter for the center circle with a crosshair
class CrosshairCirclePainter extends CustomPainter {
  final double radius;

  CrosshairCirclePainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint circlePaint =
        Paint()
          ..color = Colors.blueAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5;

    final Paint crosshairPaint =
        Paint()
          ..color = Colors.blueAccent
          ..strokeWidth = 5;

    // Draw the circle
    canvas.drawCircle(Offset(radius, radius), radius, circlePaint);

    // Draw crosshairs
    canvas.drawLine(
      Offset(radius, 0),
      Offset(radius, radius * 2),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(0, radius),
      Offset(radius * 2, radius),
      crosshairPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpiralMenuState extends State<SpiralMenu> {
  late Offset position;
  int circleNum = 0;
  List<SvgPicture> svgPictures = [];
  List<String> assetNames = [];

  @override
  void initState() {
    super.initState();
    position = widget.initialPosition;
    // Call loadSvgFiles and print the result for debugging
    widget.loadSvgFiles().then((svgFiles) {
      setState(() {
        svgPictures =
            svgFiles
                .map(
                  (file) => SvgPicture.asset(file, width: 40.0, height: 40.0),
                )
                .toList();
        assetNames = svgFiles;
        circleNum = svgFiles.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (SidebarNotifier.instance.openSidebar == SideBarWidget.colorPalette) {
      return Container(); // Return empty container if spiral menu is not open
    }
    final List<Widget> circleWidgets = [];

    double r = SpiralMenu.centerRadius + SpiralMenu.spiralElementRadius;
    double theta = 0;

    // Mittelpunkt-Kreis
    circleWidgets.add(
      Positioned(
        left: position.dx - SpiralMenu.centerRadius,
        top: position.dy - SpiralMenu.centerRadius,
        child: SizedBox(
          width: SpiralMenu.centerRadius * 2,
          height: SpiralMenu.centerRadius * 2,
          child: CustomPaint(
            painter: CrosshairCirclePainter(radius: SpiralMenu.centerRadius),
          ),
        ),
      ),
    );

    // Spiral-Kreise
    for (int i = 0; i < circleNum; i++) {
      double x = position.dx + r * cos(theta);
      double y = position.dy + r * sin(theta);

      circleWidgets.add(
        Positioned(
          left: x - SpiralMenu.spiralElementRadius,
          top: y - SpiralMenu.spiralElementRadius,
          child: SpiralCircle(
            radius: SpiralMenu.spiralElementRadius,
            color: Colors.amber.withAlpha(200),
            svg: svgPictures[i],
            assetName: assetNames[i],
            menuNotifier: widget.menuNotifier,
            targetPosition: position,
          ),
        ),
      );

      double deltaTheta = 2 * asin(SpiralMenu.spiralElementRadius / r);
      theta += deltaTheta;
      r =
          SpiralMenu.centerRadius +
          SpiralMenu.spiralElementRadius +
          (theta * SpiralMenu.spiralElementRadius / pi);
    }

    return GestureDetector(
      onTapDown: (details) {
        widget.menuNotifier.menuTapped();
      },
      onPanUpdate: (details) {
        if (widget.menuNotifier.lastAction == MenuAction.menuTapped) {
          setState(() {
            position += details.delta;
          });
        }
      },
      child: Stack(children: circleWidgets),
    );
  }
}

class SpiralCircle extends StatefulWidget {
  final double radius;
  final Color color;
  final SvgPicture? svg;
  final String? assetName;
  final MenuNotifier menuNotifier;
  final Offset targetPosition;

  const SpiralCircle({
    super.key,
    required this.radius,
    required this.color,
    this.svg,
    this.assetName,
    required this.menuNotifier,
    required this.targetPosition,
  });

  @override
  State<SpiralCircle> createState() => _SpiralCircleState();
}

class _SpiralCircleState extends State<SpiralCircle> {
  late Color currentColor;

  @override
  void initState() {
    super.initState();
    currentColor = widget.color;
  }

  void tapAnimation() {
    print("Tapped on ${widget.assetName}");
    setState(() {
      currentColor = Color.lerp(widget.color, Colors.white, 0.5)!;
      if (widget.assetName != null && widget.svg != null) {
        widget.menuNotifier.updateSelectedSymbol(
          widget.assetName!,
          widget.targetPosition,
        );
      }
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          currentColor = widget.color;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => {tapAnimation()},
      child: Container(
        width: widget.radius * 2,
        height: widget.radius * 2,
        decoration: BoxDecoration(
          color: currentColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: widget.svg != null ? Center(child: widget.svg) : null,
      ),
    );
  }
}
