import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bsl_app/core/context/bsl_location_context.dart';
import 'package:bsl_app/modules/public_transport/controllers/transit_controller.dart';
import 'package:bsl_app/modules/public_transport/screens/public_transport_screen.dart';
import 'transit_controller_test.dart' show FakeTransitGateway;

void main() {
  testWidgets(
    'small phone shows actual line selection and stop search without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = TransitController(
        gateway: FakeTransitGateway(),
        now: () => DateTime.utc(2026, 10, 15, 20),
      );
      final location = BslLocationContext();
      var controllerDisposed = false;
      addTearDown(() {
        if (!controllerDisposed) c.dispose();
      });
      addTearDown(location.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: location,
          child: MaterialApp(
            home: PublicTransportScreen(
              city: 'Sarajevo',
              controller: c,
              mapBuilder: (_) => const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gradski prevoz'), findsOneWidget);
      expect(find.text('Trolejbus 106'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Tramvaj 3'));
      await tester.pumpAndSettle();
      expect(c.line.id, 130);
      await tester.enterText(find.byType(TextField), 'nepostojeća');
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('Nema stanica za ovu pretragu.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
      controllerDisposed = true;
    },
  );
}
