import 'package:flutter/material.dart';

class OvalClipper extends CustomClipper<Path> {
  final Rect? _ovalRect;

  OvalClipper(this._ovalRect);

  @override
  Path getClip(Size size) {
    return Path()
      ..addOval(_ovalRect!)
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}