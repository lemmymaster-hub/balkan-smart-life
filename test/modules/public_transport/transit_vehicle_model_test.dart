import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bsl_app/modules/public_transport/widgets/transit_vehicle_model.dart';

void main() {
  test('atlas heading wraps continuously across north', () {
    expect(TransitVehicleModel.viewIndex(0), 0);
    expect(TransitVehicleModel.viewIndex(360), 0);
    expect(TransitVehicleModel.viewIndex(-10), 35);
  });
  testWidgets(
    'render yellow tram and trolleybus mesh previews for visual review',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xFF0C1525), BlendMode.src);
        for (var row = 0; row < 2; row++) {
          for (var col = 0; col < 3; col++) {
            canvas.save();
            canvas.translate(col * 240.0, row * 240.0);
            TransitVehicleModel.paint(
              canvas,
              const Size(240, 240),
              tram: row == 0,
              bearing: [25.0, 90.0, 220.0][col],
            );
            canvas.restore();
          }
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(720, 480);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        expect(bytes, isNotNull);
        final directory = Directory('build/transit-preview')
          ..createSync(recursive: true);
        File(
          '${directory.path}/yellow-transit-models.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
    },
  );
}
