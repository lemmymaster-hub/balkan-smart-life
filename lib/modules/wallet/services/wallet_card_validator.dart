import '../models/wallet_demo_models.dart';

abstract final class WalletCardValidator {
  static const visaDemoNumber = '4242424242424242';
  static const mastercardDemoNumber = '5555555555554444';

  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static bool isValidNumber(String value) {
    final digits = digitsOnly(value);
    if (digits.length < 13 || digits.length > 19) return false;

    var sum = 0;
    var doubleDigit = false;

    for (var index = digits.length - 1; index >= 0; index--) {
      var digit = int.parse(digits[index]);
      if (doubleDigit) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleDigit = !doubleDigit;
    }

    return sum % 10 == 0;
  }

  static bool isSupportedDemoNumber(String value) {
    final digits = digitsOnly(value);
    return digits == visaDemoNumber || digits == mastercardDemoNumber;
  }

  static WalletCardBrand brandFor(String value) {
    final digits = digitsOnly(value);
    if (digits.startsWith('4')) return WalletCardBrand.visa;

    if (digits.length >= 2) {
      final prefix2 = int.tryParse(digits.substring(0, 2));
      if (prefix2 != null && prefix2 >= 51 && prefix2 <= 55) {
        return WalletCardBrand.mastercard;
      }
    }

    if (digits.length >= 4) {
      final prefix4 = int.tryParse(digits.substring(0, 4));
      if (prefix4 != null && prefix4 >= 2221 && prefix4 <= 2720) {
        return WalletCardBrand.mastercard;
      }
    }

    return WalletCardBrand.other;
  }

  static ({int month, int year})? parseExpiry(String value) {
    final digits = digitsOnly(value);
    if (digits.length != 4) return null;

    final month = int.tryParse(digits.substring(0, 2));
    final shortYear = int.tryParse(digits.substring(2, 4));
    if (month == null || shortYear == null || month < 1 || month > 12) {
      return null;
    }

    return (month: month, year: 2000 + shortYear);
  }

  static bool isValidExpiry(String value, {DateTime? now}) {
    final expiry = parseExpiry(value);
    if (expiry == null) return false;

    final current = now ?? DateTime.now();
    return expiry.year > current.year ||
        (expiry.year == current.year && expiry.month >= current.month);
  }

  static bool isValidCvv(String value) {
    final digits = digitsOnly(value);
    return digits.length == 3 || digits.length == 4;
  }
}
