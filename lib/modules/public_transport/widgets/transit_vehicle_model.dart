import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

/// A small geometric 3D renderer. Google Navigation accepts bitmap markers,
/// so depth-sorted perspective views of these meshes form a rotation atlas.
/// No Arrivo artwork, GLB assets or external rendering dependency is used.
class TransitVehicleModel {
  static const yellow = Color(0xFFFFCF18);
  static const views = 36;

  static int viewIndex(double bearing) =>
      (((bearing % 360 + 360) % 360) / 360 * views).round() % views;

  static Future<Map<int, ImageDescriptor>> atlas({required bool tram}) async {
    final result = <int, ImageDescriptor>{};
    try {
      for (var i = 0; i < views; i++) {
        final recorder = ui.PictureRecorder();
        paint(
          Canvas(recorder),
          const Size(240, 240),
          tram: tram,
          bearing: i * 360 / views,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(240, 240);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        if (data == null) throw StateError('Vehicle render unavailable');
        result[i] = await registerBitmapImage(
          bitmap: data,
          width: 88,
          height: 88,
          imagePixelRatio: 1,
        );
      }
      return result;
    } catch (_) {
      for (final image in result.values) {
        await unregisterImage(image);
      }
      rethrow;
    }
  }

  static void paint(
    Canvas canvas,
    Size size, {
    required bool tram,
    double bearing = 35,
  }) {
    final faces = <_Face>[];
    void polygon(List<_V> points, Color color) =>
        faces.add(_Face(points, color));
    void box(
      double x,
      double y,
      double z,
      double width,
      double length,
      double height,
      Color color,
    ) {
      final a = _V(x - width / 2, y - length / 2, z),
          b = _V(x + width / 2, y - length / 2, z);
      final c = _V(x + width / 2, y + length / 2, z),
          d = _V(x - width / 2, y + length / 2, z);
      final aa = _V(a.x, a.y, z + height), bb = _V(b.x, b.y, z + height);
      final cc = _V(c.x, c.y, z + height), dd = _V(d.x, d.y, z + height);
      polygon([a, b, bb, aa], color);
      polygon([b, c, cc, bb], color);
      polygon([c, d, dd, cc], color);
      polygon([d, a, aa, dd], color);
      polygon([aa, bb, cc, dd], color);
    }

    final centers = tram ? [-5.2, 0.0, 5.2] : [-3.2, 3.2];
    final segmentLength = tram ? 4.8 : 6.0;
    final halfLength = tram ? 7.6 : 6.2;
    const dark = Color(0xFF17232D),
        roof = Color(0xFFFFD653),
        glass = Color(0xFF18323D);
    for (final y in centers) {
      box(0, y, .42, 2.45, segmentLength, 2.3, yellow);
      box(0, y, 2.72, 2.38, segmentLength - .12, .19, roof);
      box(0, y, .42, 2.49, segmentLength, .28, const Color(0xFFD4A409));
      // Large dark side glazing and narrow yellow window pillars.
      for (final side in [-1, 1]) {
        for (var j = 0; j < 5; j++) {
          final cy = y - segmentLength / 2 + .58 + j * (segmentLength - .7) / 5;
          final len = (segmentLength - .9) / 5;
          final x = side * 1.232;
          polygon([
            _V(x, cy - len / 2, 1.4),
            _V(x, cy + len / 2, 1.4),
            _V(x, cy + len / 2, 2.47),
            _V(x, cy - len / 2, 2.47),
          ], glass);
          polygon([
            _V(x * 1.001, cy - len / 2, 2.15),
            _V(x * 1.001, cy + len / 2, 2.38),
            _V(x * 1.001, cy + len / 2, 2.47),
            _V(x * 1.001, cy - len / 2, 2.47),
          ], const Color(0xFF6B9DA9));
        }
      }
      // Doors on the boarding side, low floor, thin yellow centre mullion.
      final doorY = y + segmentLength * .2;
      polygon([
        _V(1.24, doorY - .48, .57),
        _V(1.24, doorY + .48, .57),
        _V(1.24, doorY + .48, 2.46),
        _V(1.24, doorY - .48, 2.46),
      ], dark);
      box(1.25, doorY, .6, .025, .065, 1.85, yellow);
      box(0, y, 2.92, 1.3, 1.45, .25, const Color(0xFFAFB6B3));
      // Three-dimensional wheel cylinders with shaded sidewalls and hubs.
      for (final wy in [y - segmentLength * .30, y + segmentLength * .30]) {
        for (final side in [-1, 1]) {
          final x = side * 1.24;
          for (var i = 0; i < 12; i++) {
            final a = i * math.pi / 6, b = (i + 1) * math.pi / 6;
            final p = _V(x, wy + math.cos(a) * .36, .43 + math.sin(a) * .36);
            final q = _V(x, wy + math.cos(b) * .36, .43 + math.sin(b) * .36);
            polygon([_V(x, wy, .43), p, q], const Color(0xFF1A1F23));
            polygon([
              _V(x + side * .02, wy, .43),
              _V(
                x + side * .02,
                wy + math.cos(a) * .16,
                .43 + math.sin(a) * .16,
              ),
              _V(
                x + side * .02,
                wy + math.cos(b) * .16,
                .43 + math.sin(b) * .16,
              ),
            ], const Color(0xFF8B9396));
          }
        }
      }
    }
    final joints = tram ? [-2.6, 2.6] : [0.0];
    for (final y in joints) {
      box(0, y, .5, 2.29, .5, 2.2, const Color(0xFF454B4E));
      for (var i = 0; i < 4; i++) {
        box(
          0,
          y - .2 + i * .12,
          .55,
          2.34,
          .035,
          2.12,
          const Color(0xFF242D32),
        );
      }
    }
    // Sloping front and rear windscreens, lamps and dark destination panel.
    for (final front in [-1, 1]) {
      final y = halfLength * front;
      polygon([
        _V(-1.13, y, 1.4),
        _V(1.13, y, 1.4),
        _V(1.04, y - front * .08, 2.52),
        _V(-1.04, y - front * .08, 2.52),
      ], glass);
      polygon([
        _V(-.8, y + front * .01, 2.35),
        _V(.8, y + front * .01, 2.35),
        _V(.8, y + front * .01, 2.54),
        _V(-.8, y + front * .01, 2.54),
      ], dark);
      for (final side in [-1, 1]) {
        box(
          side * .85,
          y + front * .02,
          .9,
          .38,
          .045,
          .13,
          front == 1 ? const Color(0xFFFFF9D1) : const Color(0xFFCF4035),
        );
      }
    }
    if (tram) {
      // Pantograph as thin solid mesh beams, not a painted map symbol.
      for (final side in [-.55, .55]) {
        polygon([
          _V(side, -1, 3.17),
          _V(side, -.92, 3.17),
          _V(side, .08, 3.94),
          _V(side, 0, 3.99),
        ], dark);
        polygon([
          _V(side, 0, 3.99),
          _V(side, .08, 3.94),
          _V(side, 1, 3.17),
          _V(side, .92, 3.17),
        ], dark);
      }
      box(0, 0, 3.98, 2.0, .13, .12, const Color(0xFF666D70));
    } else {
      // Twin trolley poles extending from the roof towards the rear.
      for (final side in [-.5, .5]) {
        polygon([
          _V(side, -.2, 3.1),
          _V(side + .07, -.2, 3.1),
          _V(side + .07, -5.7, 4.1),
          _V(side, -5.7, 4.1),
        ], const Color(0xFF394449));
        box(side, -5.7, 4.08, .18, .35, .10, dark);
      }
    }
    final yaw = bearing * math.pi / 180;
    const elevation = .96;
    _V rotate(_V p) => _V(
      p.x * math.cos(yaw) + p.y * math.sin(yaw),
      p.y * math.cos(yaw) - p.x * math.sin(yaw),
      p.z,
    );
    double depth(_V p) {
      final r = rotate(p);
      return r.y * math.cos(elevation) - r.z * math.sin(elevation);
    }

    Offset project(_V p) {
      final r = rotate(p);
      final perspective = 28 / (28 + depth(p));
      final scale = size.width / (tram ? 20 : 17);
      return Offset(
        size.width / 2 + r.x * scale * perspective,
        size.height * .57 +
            (-r.y * math.sin(elevation) - r.z * math.cos(elevation)) *
                scale *
                perspective,
      );
    }

    final shadow = Path()
      ..addPolygon([
        project(_V(-1.4, -halfLength, .01)),
        project(_V(1.4, -halfLength, .01)),
        project(_V(1.4, halfLength, .01)),
        project(_V(-1.4, halfLength, .01)),
      ], true);
    canvas.drawPath(
      shadow.shift(const Offset(4, 5)),
      Paint()
        ..color = const Color(0x88000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    double faceDepth(_Face f) =>
        f.vertices.map(depth).reduce((a, b) => a + b) / f.vertices.length;
    faces.sort((a, b) => faceDepth(b).compareTo(faceDepth(a)));
    for (final face in faces) {
      final a = face.vertices[0], b = face.vertices[1], c = face.vertices[2];
      final ux = b.x - a.x,
          uy = b.y - a.y,
          uz = b.z - a.z,
          vx = c.x - a.x,
          vy = c.y - a.y,
          vz = c.z - a.z;
      final nx = uy * vz - uz * vy,
          ny = uz * vx - ux * vz,
          nz = ux * vy - uy * vx;
      final norm = math.sqrt(nx * nx + ny * ny + nz * nz);
      final light = norm < 1e-9
          ? .8
          : (.75 + .22 * (nz.abs() / norm) + .13 * nx / norm).clamp(.60, 1.0);
      final color = face.color;
      final shaded = Color.fromARGB(
        255,
        (color.r * 255 * light).round(),
        (color.g * 255 * light).round(),
        (color.b * 255 * light).round(),
      );
      final shape = Path()
        ..addPolygon(face.vertices.map(project).toList(), true);
      canvas.drawPath(
        shape,
        Paint()
          ..color = shaded
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        shape,
        Paint()
          ..color = const Color(0x25101A21)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .45,
      );
    }
  }
}

class _V {
  final double x, y, z;
  const _V(this.x, this.y, this.z);
}

class _Face {
  final List<_V> vertices;
  final Color color;
  const _Face(this.vertices, this.color);
}
