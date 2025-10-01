import 'dart:ui';
import 'package:vector_math/vector_math_64.dart' as vec;

import 'package:flutter/material.dart';

Offset getTransformedOffset(
  Offset screenPos,
  TransformationController controller,
  double scrollOffset,
) {
  final matrix = controller.value;
  Offset svgPos = screenPos;
  if (matrix != null) {
    final Matrix4 inverse = Matrix4.inverted(matrix);
    final vec.Vector3 local = inverse.transform3(
      vec.Vector3(svgPos.dx, svgPos.dy, 0),
    );
    // Add scroll offset to svgPos
    svgPos = Offset(local.x, local.y + scrollOffset);
  }
  return svgPos;
}
