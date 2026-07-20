import 'package:bsl_app/modules/wallet/screens/wallet_demo_capture_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NFC demo prikazuje prislanjanje i prepoznati zahtjev', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WalletDemoCaptureScreen(mode: WalletDemoCaptureMode.nfc),
      ),
    );

    expect(find.byKey(const ValueKey('wallet-nfc-target')), findsOneWidget);
    expect(find.text('PRISLONI TELEFON'), findsOneWidget);
    expect(
      find.textContaining('nema komunikacije s pravim terminalom'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('wallet-simulate-capture')));
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey('wallet-capture-detected')),
      findsOneWidget,
    );
    expect(find.text('BSL Urban Market'), findsOneWidget);
    expect(find.text('24.90 KM'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wallet-capture-continue')),
      findsOneWidget,
    );
  });
}
