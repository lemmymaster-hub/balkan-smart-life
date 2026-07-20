import 'package:bsl_app/modules/wallet/models/wallet_demo_models.dart';
import 'package:bsl_app/modules/wallet/services/wallet_card_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletCardValidator', () {
    test('prihvata samo ponuđene Visa i Mastercard demo brojeve', () {
      expect(
        WalletCardValidator.isSupportedDemoNumber('4242 4242 4242 4242'),
        isTrue,
      );
      expect(
        WalletCardValidator.isSupportedDemoNumber('5555 5555 5555 4444'),
        isTrue,
      );
      expect(
        WalletCardValidator.isSupportedDemoNumber('4111 1111 1111 1111'),
        isFalse,
      );
    });

    test('provjerava Luhnov kontrolni zbir', () {
      expect(WalletCardValidator.isValidNumber('4242 4242 4242 4242'), isTrue);
      expect(WalletCardValidator.isValidNumber('4242 4242 4242 4241'), isFalse);
    });

    test('prepoznaje brend testne kartice', () {
      expect(
        WalletCardValidator.brandFor('4242 4242 4242 4242'),
        WalletCardBrand.visa,
      );
      expect(
        WalletCardValidator.brandFor('5555 5555 5555 4444'),
        WalletCardBrand.mastercard,
      );
    });

    test('datum isteka mora biti ispravan i ne smije biti u prošlosti', () {
      final now = DateTime(2026, 7, 20);

      expect(WalletCardValidator.isValidExpiry('07/26', now: now), isTrue);
      expect(WalletCardValidator.isValidExpiry('06/26', now: now), isFalse);
      expect(WalletCardValidator.isValidExpiry('13/30', now: now), isFalse);
    });
  });
}
