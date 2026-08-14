import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../../../core/theme/bsl_design_system.dart';

abstract final class AtmMarkerFactory {
  static const double _canvasWidth = 164;
  static const double _canvasHeight = 206;

  static Future<ImageDescriptor> create({
    required Color accentColor,
    bool isSelected = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, _canvasWidth, _canvasHeight),
    );
    final center = const Offset(_canvasWidth / 2, 126);

    _drawGlow(canvas, center: center, color: accentColor, selected: isSelected);

    final outerPaint = Paint()
      ..color = const Color(0xF2070B18)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.98)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 8 : 6;

    canvas.drawCircle(center, isSelected ? 52 : 47, outerPaint);
    canvas.drawCircle(center, isSelected ? 52 : 47, borderPaint);

    canvas.drawCircle(
      center - const Offset(11, 13),
      31,
      Paint()
        ..shader = ui.Gradient.radial(center - const Offset(11, 13), 34, [
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
        ]),
    );

    _drawAtmIcon(canvas, center: center, accentColor: accentColor);

    final pointerPath = Path()
      ..moveTo(center.dx - 14, center.dy + 42)
      ..lineTo(center.dx, 201)
      ..lineTo(center.dx + 14, center.dy + 42)
      ..close();
    canvas.drawPath(pointerPath, outerPaint);
    canvas.drawPath(
      pointerPath,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      _canvasWidth.toInt(),
      _canvasHeight.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    if (data == null) return ImageDescriptor.defaultImage;

    return registerBitmapImage(
      bitmap: data,
      width: isSelected ? 72 : 66,
      height: isSelected ? 90 : 82,
      imagePixelRatio: 1,
    );
  }

  static void _drawGlow(
    Canvas canvas, {
    required Offset center,
    required Color color,
    required bool selected,
  }) {
    canvas.drawCircle(
      center,
      selected ? 68 : 60,
      Paint()
        ..color = color.withValues(alpha: selected ? 0.62 : 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawCircle(
      center,
      selected ? 59 : 53,
      Paint()
        ..color = BslColors.cyan.withValues(alpha: selected ? 0.25 : 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );
  }

  static void _drawAtmIcon(
    Canvas canvas, {
    required Offset center,
    required Color accentColor,
  }) {
    final icon = Icons.atm_rounded;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: 65,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          shadows: [
            Shadow(color: accentColor.withValues(alpha: 0.55), blurRadius: 10),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }
}
