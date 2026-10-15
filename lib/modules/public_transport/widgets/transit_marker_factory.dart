import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../../../core/theme/bsl_design_system.dart';

abstract final class TransitMarkerFactory {
  static Future<ImageDescriptor> create({
    required bool vehicle,
    required bool tram,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final color = tram ? BslColors.cyan : BslColors.purple;
    const center = Offset(40, 40);
    canvas.drawCircle(center, 35, Paint()..color = BslColors.bgDark);
    canvas.drawCircle(
      center,
      35,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    final icon = vehicle
        ? (tram ? Icons.tram_rounded : Icons.directions_bus_rounded)
        : Icons.trip_origin;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: vehicle ? 40 : 24,
          color: color,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(80, 80);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (bytes == null) return ImageDescriptor.defaultImage;
    return registerBitmapImage(
      bitmap: bytes,
      width: vehicle ? 46 : 26,
      height: vehicle ? 46 : 26,
      imagePixelRatio: 1,
    );
  }
}
