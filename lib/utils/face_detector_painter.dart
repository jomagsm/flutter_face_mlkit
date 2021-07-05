import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_ml_vision/google_ml_vision.dart';
import 'package:path_drawing/path_drawing.dart';

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.absoluteImageSize, this.faces, this.oval);

  final Size absoluteImageSize;
  final Face? faces;
  final Rect? oval;

  @override
  void paint(Canvas canvas, Size size) {
    if (faces == null) return;
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    print(size);

    var faceRect = Rect.fromLTRB(
      faces!.boundingBox.left * scaleX,
      faces!.boundingBox.top * scaleY,
      faces!.boundingBox.right * scaleX,
      faces!.boundingBox.bottom * scaleY,
    );

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..color = Colors.white;

    Path _path = Path()..addOval(oval!);

    

    if (faceRect.left > oval!.left &&
        faceRect.top > oval!.top &&
        faceRect.bottom < oval!.bottom &&
        faceRect.right < oval!.right) {
      paint.color = Colors.transparent;
    } else {
      _path = dashPath(_path,
          dashArray: CircularIntervalList<double>(<double>[7.0, 8.5]));
    }

    canvas.drawPath(_path, paint);

  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.faces != faces;
  }
}