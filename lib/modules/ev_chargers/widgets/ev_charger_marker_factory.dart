import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/bsl_design_system.dart';
import '../models/ev_charger.dart';

abstract final class EvChargerMarkerFactory {
  static const double _canvasWidth = 184;
  static const double _canvasHeight = 226;

  static Future<BitmapDescriptor> create({
    required EvChargingFee fee,
    String? label,
    bool isSelected = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, _canvasWidth, _canvasHeight),
    );
    final statusColor = _colorForFee(fee);
    final markerCenter = const Offset(_canvasWidth / 2, 147);
    final bubbleLabel = _shortLabel(label);

    _drawGlow(
      canvas,
      center: markerCenter,
      color: statusColor,
      selected: isSelected,
    );

    if (bubbleLabel != null) {
      _drawBubble(canvas, label: bubbleLabel, color: statusColor);
    }

    final outerPaint = Paint()
      ..color = const Color(0xFF07111F)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = statusColor.withValues(alpha: 0.98)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 8 : 6;

    canvas.drawCircle(markerCenter, isSelected ? 52 : 48, outerPaint);
    canvas.drawCircle(markerCenter, isSelected ? 52 : 48, borderPaint);

    canvas.drawCircle(
      markerCenter - const Offset(10, 12),
      30,
      Paint()
        ..shader = ui.Gradient.radial(markerCenter - const Offset(10, 12), 34, [
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
        ]),
    );

    _drawEvIcon(canvas, center: markerCenter);

    final pointerPath = Path()
      ..moveTo(markerCenter.dx - 14, markerCenter.dy + 43)
      ..lineTo(markerCenter.dx, 218)
      ..lineTo(markerCenter.dx + 14, markerCenter.dy + 43)
      ..close();
    canvas.drawPath(pointerPath, outerPaint);
    canvas.drawPath(
      pointerPath,
      Paint()
        ..color = statusColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      _canvasWidth.toInt(),
      _canvasHeight.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    if (data == null) {
      return BitmapDescriptor.defaultMarkerWithHue(_hueForFee(fee));
    }

    return BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      width: 72,
      height: 88,
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
      selected ? 68 : 62,
      Paint()
        ..color = color.withValues(alpha: selected ? 0.62 : 0.46)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawCircle(
      center,
      selected ? 59 : 55,
      Paint()
        ..color = color.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );
  }

  static void _drawBubble(
    Canvas canvas, {
    required String label,
    required Color color,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 25,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 140);
    final bubbleWidth = (textPainter.width + 32).clamp(70.0, 154.0);
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(_canvasWidth / 2, 42),
        width: bubbleWidth,
        height: 48,
      ),
      const Radius.circular(24),
    );

    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..color = const Color(0xED07111F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final cloudTail = Path()
      ..moveTo(_canvasWidth / 2 - 10, 65)
      ..lineTo(_canvasWidth / 2, 78)
      ..lineTo(_canvasWidth / 2 + 10, 65)
      ..close();
    canvas.drawPath(cloudTail, Paint()..color = const Color(0xED07111F));

    textPainter.paint(
      canvas,
      Offset(
        (_canvasWidth - textPainter.width) / 2,
        42 - textPainter.height / 2,
      ),
    );
  }

  static void _drawEvIcon(Canvas canvas, {required Offset center}) {
    final icon = Icons.ev_station_rounded;
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: 65,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          shadows: [
            Shadow(
              color: BslColors.cyan.withValues(alpha: 0.28),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  static String? _shortLabel(String? rawLabel) {
    final normalized = rawLabel?.trim() ?? '';
    if (normalized.isEmpty) return null;
    if (normalized.length <= 12) return normalized;
    return '${normalized.substring(0, 11)}…';
  }

  static Color _colorForFee(EvChargingFee fee) {
    switch (fee) {
      case EvChargingFee.free:
        return BslColors.success;
      case EvChargingFee.paid:
        return BslColors.danger;
      case EvChargingFee.unknown:
        return BslColors.warning;
    }
  }

  static double _hueForFee(EvChargingFee fee) {
    switch (fee) {
      case EvChargingFee.free:
        return BitmapDescriptor.hueGreen;
      case EvChargingFee.paid:
        return BitmapDescriptor.hueRed;
      case EvChargingFee.unknown:
        return BitmapDescriptor.hueYellow;
    }
  }
}
