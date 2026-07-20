enum WalletCardBrand { visa, mastercard, other }

enum WalletTransactionCategory { bslService, merchant, parkingMachine }

enum WalletTransactionStatus { completed, pending, refunded }

class WalletDemoCard {
  final String id;
  final String nickname;
  final String holderName;
  final String last4;
  final WalletCardBrand brand;
  final int expiryMonth;
  final int expiryYear;
  final bool isDefault;

  const WalletDemoCard({
    required this.id,
    required this.nickname,
    required this.holderName,
    required this.last4,
    required this.brand,
    required this.expiryMonth,
    required this.expiryYear,
    this.isDefault = false,
  });

  String get maskedNumber => '••••  ••••  ••••  $last4';

  String get expiryLabel =>
      '${expiryMonth.toString().padLeft(2, '0')}/${(expiryYear % 100).toString().padLeft(2, '0')}';

  String get brandLabel {
    switch (brand) {
      case WalletCardBrand.visa:
        return 'VISA';
      case WalletCardBrand.mastercard:
        return 'MASTERCARD';
      case WalletCardBrand.other:
        return 'CARD';
    }
  }

  WalletDemoCard copyWith({bool? isDefault}) {
    return WalletDemoCard(
      id: id,
      nickname: nickname,
      holderName: holderName,
      last4: last4,
      brand: brand,
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nickname': nickname,
      'holderName': holderName,
      'last4': last4,
      'brand': brand.name,
      'expiryMonth': expiryMonth,
      'expiryYear': expiryYear,
      'isDefault': isDefault,
    };
  }

  factory WalletDemoCard.fromMap(Map<String, dynamic> data) {
    final last4 = (data['last4'] ?? '').toString();
    final expiryMonth = (data['expiryMonth'] as num?)?.toInt();
    final expiryYear = (data['expiryYear'] as num?)?.toInt();

    if (last4.length != 4 || expiryMonth == null || expiryYear == null) {
      throw const FormatException('Neispravan zapis demo kartice.');
    }

    return WalletDemoCard(
      id: (data['id'] ?? '').toString(),
      nickname: (data['nickname'] ?? 'Demo kartica').toString(),
      holderName: (data['holderName'] ?? 'BSL DEMO KORISNIK').toString(),
      last4: last4,
      brand: WalletCardBrand.values.firstWhere(
        (brand) => brand.name == data['brand'],
        orElse: () => WalletCardBrand.other,
      ),
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
      isDefault: data['isDefault'] == true,
    );
  }
}

class WalletDemoCardDraft {
  final String nickname;
  final String holderName;
  final String last4;
  final WalletCardBrand brand;
  final int expiryMonth;
  final int expiryYear;

  const WalletDemoCardDraft({
    required this.nickname,
    required this.holderName,
    required this.last4,
    required this.brand,
    required this.expiryMonth,
    required this.expiryYear,
  });
}

class WalletDemoPaymentRequest {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final WalletTransactionCategory category;

  const WalletDemoPaymentRequest({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.category,
  });
}

class WalletDemoTransaction {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final String currency;
  final String cardLast4;
  final DateTime createdAt;
  final WalletTransactionCategory category;
  final WalletTransactionStatus status;

  const WalletDemoTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.cardLast4,
    required this.createdAt,
    required this.category,
    required this.status,
    this.currency = 'KM',
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'amount': amount,
      'currency': currency,
      'cardLast4': cardLast4,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'category': category.name,
      'status': status.name,
    };
  }

  factory WalletDemoTransaction.fromMap(Map<String, dynamic> data) {
    final createdAt = DateTime.tryParse((data['createdAt'] ?? '').toString());
    final amount = (data['amount'] as num?)?.toDouble();

    if (createdAt == null || amount == null) {
      throw const FormatException('Neispravan zapis demo transakcije.');
    }

    return WalletDemoTransaction(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? 'BSL demo plaćanje').toString(),
      subtitle: (data['subtitle'] ?? '').toString(),
      amount: amount,
      currency: (data['currency'] ?? 'KM').toString(),
      cardLast4: (data['cardLast4'] ?? '').toString(),
      createdAt: createdAt,
      category: WalletTransactionCategory.values.firstWhere(
        (category) => category.name == data['category'],
        orElse: () => WalletTransactionCategory.bslService,
      ),
      status: WalletTransactionStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => WalletTransactionStatus.completed,
      ),
    );
  }
}

class WalletDemoSnapshot {
  final List<WalletDemoCard> cards;
  final List<WalletDemoTransaction> transactions;

  const WalletDemoSnapshot({required this.cards, required this.transactions});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cards': cards.map((card) => card.toMap()).toList(growable: false),
      'transactions': transactions
          .map((transaction) => transaction.toMap())
          .toList(growable: false),
    };
  }

  factory WalletDemoSnapshot.fromMap(Map<String, dynamic> data) {
    final rawCards = data['cards'] as List? ?? const [];
    final rawTransactions = data['transactions'] as List? ?? const [];

    return WalletDemoSnapshot(
      cards: rawCards
          .whereType<Map>()
          .map(
            (card) => WalletDemoCard.fromMap(Map<String, dynamic>.from(card)),
          )
          .toList(growable: false),
      transactions: rawTransactions
          .whereType<Map>()
          .map(
            (transaction) => WalletDemoTransaction.fromMap(
              Map<String, dynamic>.from(transaction),
            ),
          )
          .toList(growable: false),
    );
  }
}
