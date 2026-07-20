import 'package:flutter/foundation.dart';

import '../models/wallet_demo_models.dart';
import '../services/wallet_demo_store.dart';

class WalletDemoController extends ChangeNotifier {
  factory WalletDemoController({
    WalletDemoStore? store,
    DateTime Function()? now,
  }) {
    return WalletDemoController._(
      store ?? SharedPreferencesWalletDemoStore(),
      now ?? DateTime.now,
    );
  }

  WalletDemoController._(this._store, this._now);

  final WalletDemoStore _store;
  final DateTime Function() _now;

  String _userId = 'guest';
  List<WalletDemoCard> _cards = const [];
  List<WalletDemoTransaction> _transactions = const [];
  bool _isInitialized = false;

  List<WalletDemoCard> get cards => List.unmodifiable(_cards);
  List<WalletDemoTransaction> get transactions =>
      List.unmodifiable(_transactions);
  bool get isInitialized => _isInitialized;

  WalletDemoCard? get defaultCard {
    for (final card in _cards) {
      if (card.isDefault) return card;
    }
    return _cards.isEmpty ? null : _cards.first;
  }

  Future<void> initialize({required String userId}) async {
    _userId = userId.trim().isEmpty ? 'guest' : userId.trim();
    final stored = await _store.load(userId: _userId);

    if (stored == null) {
      final seed = _seedSnapshot(_now());
      _cards = seed.cards;
      _transactions = seed.transactions;
      await _persist();
    } else {
      _cards = _normalizeDefaultCard(stored.cards);
      _transactions = _sortTransactions(stored.transactions);
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> addCard(WalletDemoCardDraft draft) async {
    if (!RegExp(r'^\d{4}$').hasMatch(draft.last4) ||
        draft.expiryMonth < 1 ||
        draft.expiryMonth > 12 ||
        draft.expiryYear < 2000) {
      throw const WalletDemoException('Demo kartica ima neispravne podatke.');
    }

    final now = _now();
    final card = WalletDemoCard(
      id: 'demo_card_${now.microsecondsSinceEpoch}',
      nickname: draft.nickname.trim().isEmpty
          ? '${_brandLabel(draft.brand)} •••• ${draft.last4}'
          : draft.nickname.trim(),
      holderName: draft.holderName.trim().toUpperCase(),
      last4: draft.last4,
      brand: draft.brand,
      expiryMonth: draft.expiryMonth,
      expiryYear: draft.expiryYear,
      isDefault: _cards.isEmpty,
    );

    _cards = [..._cards, card];
    await _persistAndNotify();
  }

  Future<void> setDefaultCard(String cardId) async {
    if (!_cards.any((card) => card.id == cardId)) return;

    _cards = _cards
        .map((card) => card.copyWith(isDefault: card.id == cardId))
        .toList(growable: false);
    await _persistAndNotify();
  }

  Future<void> removeCard(String cardId) async {
    final removedWasDefault = _cards.any(
      (card) => card.id == cardId && card.isDefault,
    );
    final remaining = _cards
        .where((card) => card.id != cardId)
        .toList(growable: false);

    _cards = removedWasDefault ? _normalizeDefaultCard(remaining) : remaining;
    await _persistAndNotify();
  }

  Future<WalletDemoTransaction> recordPayment({
    required WalletDemoPaymentRequest request,
    required String cardId,
  }) async {
    final card = _cards.firstWhere(
      (candidate) => candidate.id == cardId,
      orElse: () => throw const WalletDemoException(
        'Izabrana demo kartica nije dostupna.',
      ),
    );

    if (request.amount <= 0) {
      throw const WalletDemoException('Iznos mora biti veći od nule.');
    }

    final now = _now();
    final transaction = WalletDemoTransaction(
      id: 'demo_transaction_${now.microsecondsSinceEpoch}',
      title: request.title,
      subtitle: request.subtitle,
      amount: request.amount,
      cardLast4: card.last4,
      createdAt: now,
      category: request.category,
      status: WalletTransactionStatus.completed,
    );

    _transactions = [transaction, ..._transactions];
    await _persistAndNotify();
    return transaction;
  }

  Future<void> resetDemo() async {
    await _store.clear(userId: _userId);
    final seed = _seedSnapshot(_now());
    _cards = seed.cards;
    _transactions = seed.transactions;
    await _persistAndNotify();
  }

  Future<void> _persistAndNotify() async {
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _store.save(
      userId: _userId,
      snapshot: WalletDemoSnapshot(cards: _cards, transactions: _transactions),
    );
  }

  static WalletDemoSnapshot _seedSnapshot(DateTime now) {
    const card = WalletDemoCard(
      id: 'bsl_seed_demo_card',
      nickname: 'BSL Demo Visa',
      holderName: 'BSL DEMO KORISNIK',
      last4: '4242',
      brand: WalletCardBrand.visa,
      expiryMonth: 12,
      expiryYear: 2030,
      isDefault: true,
    );

    return WalletDemoSnapshot(
      cards: const [card],
      transactions: [
        WalletDemoTransaction(
          id: 'bsl_seed_parking',
          title: 'Parkiraj.ba',
          subtitle: 'Parking Skenderija • 1 sat',
          amount: 2,
          cardLast4: card.last4,
          createdAt: now.subtract(const Duration(hours: 2, minutes: 18)),
          category: WalletTransactionCategory.bslService,
          status: WalletTransactionStatus.completed,
        ),
        WalletDemoTransaction(
          id: 'bsl_seed_merchant',
          title: 'BSL Market',
          subtitle: 'QR plaćanje u prodavnici',
          amount: 13.80,
          cardLast4: card.last4,
          createdAt: now.subtract(const Duration(days: 1, hours: 1)),
          category: WalletTransactionCategory.merchant,
          status: WalletTransactionStatus.completed,
        ),
        WalletDemoTransaction(
          id: 'bsl_seed_ev',
          title: 'EL punjači',
          subtitle: 'Demo sesija punjenja',
          amount: 18.40,
          cardLast4: card.last4,
          createdAt: now.subtract(const Duration(days: 2, hours: 3)),
          category: WalletTransactionCategory.bslService,
          status: WalletTransactionStatus.completed,
        ),
      ],
    );
  }

  static List<WalletDemoCard> _normalizeDefaultCard(
    List<WalletDemoCard> cards,
  ) {
    if (cards.isEmpty) return const [];

    String? defaultId;
    for (final card in cards) {
      if (card.isDefault) {
        defaultId = card.id;
        break;
      }
    }
    final selectedId = defaultId ?? cards.first.id;

    return cards
        .map((card) => card.copyWith(isDefault: card.id == selectedId))
        .toList(growable: false);
  }

  static List<WalletDemoTransaction> _sortTransactions(
    List<WalletDemoTransaction> transactions,
  ) {
    final sorted = List<WalletDemoTransaction>.of(transactions)
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return sorted;
  }

  static String _brandLabel(WalletCardBrand brand) {
    switch (brand) {
      case WalletCardBrand.visa:
        return 'Visa';
      case WalletCardBrand.mastercard:
        return 'Mastercard';
      case WalletCardBrand.other:
        return 'Kartica';
    }
  }
}

class WalletDemoException implements Exception {
  final String message;

  const WalletDemoException(this.message);

  @override
  String toString() => message;
}
