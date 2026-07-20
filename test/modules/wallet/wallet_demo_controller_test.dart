import 'dart:convert';

import 'package:bsl_app/modules/wallet/controllers/wallet_demo_controller.dart';
import 'package:bsl_app/modules/wallet/models/wallet_demo_models.dart';
import 'package:bsl_app/modules/wallet/services/wallet_demo_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryWalletDemoStore store;
  late WalletDemoController controller;

  setUp(() {
    store = _MemoryWalletDemoStore();
    controller = WalletDemoController(
      store: store,
      now: () => DateTime.utc(2026, 7, 20, 12),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('prvo pokretanje kreira početni demo', () async {
    await controller.initialize(userId: 'investor-1');

    expect(controller.isInitialized, isTrue);
    expect(controller.cards, hasLength(1));
    expect(controller.defaultCard?.last4, '4242');
    expect(controller.transactions, hasLength(3));
    expect(store.snapshots['investor-1'], isNotNull);
  });

  test('čuva samo maskirane podatke dodane demo kartice', () async {
    await controller.initialize(userId: 'investor-1');
    await controller.addCard(
      const WalletDemoCardDraft(
        nickname: 'Poslovna',
        holderName: 'Demo Korisnik',
        last4: '4444',
        brand: WalletCardBrand.mastercard,
        expiryMonth: 12,
        expiryYear: 2030,
      ),
    );

    final addedCard = controller.cards.last;
    expect(addedCard.nickname, 'Poslovna');
    expect(addedCard.holderName, 'DEMO KORISNIK');
    expect(addedCard.maskedNumber, contains('4444'));

    final persisted = jsonEncode(store.snapshots['investor-1']!.toMap());
    expect(persisted, isNot(contains('5555555555554444')));
    expect(persisted, isNot(contains('"cvv"')));
    expect(persisted, contains('4444'));
  });

  test('bira karticu i bilježi simulirano NFC plaćanje', () async {
    await controller.initialize(userId: 'investor-1');
    await controller.addCard(
      const WalletDemoCardDraft(
        nickname: 'Druga kartica',
        holderName: 'BSL Demo',
        last4: '4444',
        brand: WalletCardBrand.mastercard,
        expiryMonth: 12,
        expiryYear: 2030,
      ),
    );

    final secondCard = controller.cards.last;
    await controller.setDefaultCard(secondCard.id);
    final transaction = await controller.recordPayment(
      request: const WalletDemoPaymentRequest(
        id: 'nfc-demo',
        title: 'BSL Urban Market',
        subtitle: 'NFC terminal • Sarajevo',
        amount: 24.90,
        category: WalletTransactionCategory.merchant,
      ),
      cardId: secondCard.id,
    );

    expect(controller.defaultCard?.id, secondCard.id);
    expect(transaction.cardLast4, '4444');
    expect(transaction.amount, 24.90);
    expect(controller.transactions.first.id, transaction.id);
  });

  test('odbija neispravan maskirani zapis kartice', () async {
    await controller.initialize(userId: 'investor-1');

    expect(
      () => controller.addCard(
        const WalletDemoCardDraft(
          nickname: 'Neispravna',
          holderName: 'BSL Demo',
          last4: '44',
          brand: WalletCardBrand.other,
          expiryMonth: 13,
          expiryYear: 1999,
        ),
      ),
      throwsA(isA<WalletDemoException>()),
    );
  });
}

class _MemoryWalletDemoStore implements WalletDemoStore {
  final Map<String, WalletDemoSnapshot> snapshots = {};

  @override
  Future<void> clear({required String userId}) async {
    snapshots.remove(userId);
  }

  @override
  Future<WalletDemoSnapshot?> load({required String userId}) async {
    return snapshots[userId];
  }

  @override
  Future<void> save({
    required String userId,
    required WalletDemoSnapshot snapshot,
  }) async {
    snapshots[userId] = snapshot;
  }
}
