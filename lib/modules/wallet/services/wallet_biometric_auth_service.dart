import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

enum WalletBiometricAuthStatus {
  authenticated,
  canceled,
  noHardware,
  notEnrolled,
  temporarilyLocked,
  locked,
  unavailable,
  failed,
}

class WalletBiometricAuthResult {
  final WalletBiometricAuthStatus status;
  final String title;
  final String message;

  const WalletBiometricAuthResult({
    required this.status,
    required this.title,
    required this.message,
  });

  bool get isAuthenticated => status == WalletBiometricAuthStatus.authenticated;

  bool get wasCanceled => status == WalletBiometricAuthStatus.canceled;
}

abstract interface class WalletBiometricAuthenticator {
  Future<WalletBiometricAuthResult> authenticate({
    required String localizedReason,
  });
}

abstract interface class WalletBiometricDriver {
  Future<bool> supportsBiometrics();

  Future<bool> hasEnrolledBiometrics();

  Future<bool> authenticate({required String localizedReason});
}

class LocalAuthWalletBiometricDriver implements WalletBiometricDriver {
  LocalAuthWalletBiometricDriver({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<bool> supportsBiometrics() {
    return _localAuthentication.canCheckBiometrics;
  }

  @override
  Future<bool> hasEnrolledBiometrics() async {
    final biometrics = await _localAuthentication.getAvailableBiometrics();
    return biometrics.isNotEmpty;
  }

  @override
  Future<bool> authenticate({required String localizedReason}) {
    return _localAuthentication.authenticate(
      localizedReason: localizedReason,
      biometricOnly: true,
      sensitiveTransaction: true,
      persistAcrossBackgrounding: true,
    );
  }
}

class LocalAuthWalletBiometricAuthenticator
    implements WalletBiometricAuthenticator {
  LocalAuthWalletBiometricAuthenticator({WalletBiometricDriver? driver})
    : _driver = driver ?? LocalAuthWalletBiometricDriver();

  final WalletBiometricDriver _driver;

  @override
  Future<WalletBiometricAuthResult> authenticate({
    required String localizedReason,
  }) async {
    try {
      if (!await _driver.supportsBiometrics()) {
        return _resultFor(WalletBiometricAuthStatus.noHardware);
      }

      if (!await _driver.hasEnrolledBiometrics()) {
        return _resultFor(WalletBiometricAuthStatus.notEnrolled);
      }

      final authenticated = await _driver.authenticate(
        localizedReason: localizedReason,
      );
      return _resultFor(
        authenticated
            ? WalletBiometricAuthStatus.authenticated
            : WalletBiometricAuthStatus.canceled,
      );
    } on LocalAuthException catch (error) {
      return _resultFor(_statusForException(error.code));
    } catch (error, stackTrace) {
      debugPrint('BSL WALLET BIOMETRIC ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _resultFor(WalletBiometricAuthStatus.failed);
    }
  }

  static WalletBiometricAuthStatus _statusForException(
    LocalAuthExceptionCode code,
  ) {
    if (code == LocalAuthExceptionCode.userCanceled ||
        code == LocalAuthExceptionCode.userRequestedFallback ||
        code == LocalAuthExceptionCode.timeout ||
        code == LocalAuthExceptionCode.systemCanceled) {
      return WalletBiometricAuthStatus.canceled;
    }
    if (code == LocalAuthExceptionCode.noCredentialsSet ||
        code == LocalAuthExceptionCode.noBiometricsEnrolled) {
      return WalletBiometricAuthStatus.notEnrolled;
    }
    if (code == LocalAuthExceptionCode.noBiometricHardware) {
      return WalletBiometricAuthStatus.noHardware;
    }
    if (code == LocalAuthExceptionCode.temporaryLockout) {
      return WalletBiometricAuthStatus.temporarilyLocked;
    }
    if (code == LocalAuthExceptionCode.biometricLockout) {
      return WalletBiometricAuthStatus.locked;
    }
    if (code == LocalAuthExceptionCode.authInProgress ||
        code == LocalAuthExceptionCode.uiUnavailable ||
        code ==
            LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable) {
      return WalletBiometricAuthStatus.unavailable;
    }

    // local_auth može dodati nove kodove bez major verzije. Nepoznati kodovi
    // zato uvijek završavaju u sigurnom stanju bez evidentiranja plaćanja.
    return WalletBiometricAuthStatus.failed;
  }

  static WalletBiometricAuthResult _resultFor(
    WalletBiometricAuthStatus status,
  ) {
    switch (status) {
      case WalletBiometricAuthStatus.authenticated:
        return const WalletBiometricAuthResult(
          status: WalletBiometricAuthStatus.authenticated,
          title: 'Identitet potvrđen',
          message: 'Biometrija je uspješno potvrđena na uređaju.',
        );
      case WalletBiometricAuthStatus.canceled:
        return const WalletBiometricAuthResult(
          status: WalletBiometricAuthStatus.canceled,
          title: 'Potvrda je otkazana',
          message: 'Plaćanje nije evidentirano.',
        );
      case WalletBiometricAuthStatus.noHardware:
        return const WalletBiometricAuthResult(
          status: WalletBiometricAuthStatus.noHardware,
          title: 'Biometrija nije podržana',
          message: 'Ovaj uređaj nema podržani biometrijski senzor.',
        );
      case WalletBiometricAuthStatus.notEnrolled:
        return const WalletBiometricAuthResult(
          status: WalletBiometricAuthStatus.notEnrolled,
          title: 'Biometrija nije registrovana',
          message:
              'Dodaj otisak prsta ili Face ID u sigurnosnim postavkama '
              'telefona, pa pokušaj ponovo.',
        );
      case WalletBiometricAuthStatus.temporarilyLocked:
        return const WalletBiometricAuthResult(
          status: WalletBiometricAuthStatus.temporarilyLocked,
          title: 'Biometrija je privremeno zaključana',
          message:
              'Bilo je previše neuspjelih pokušaja. Sačekaj, pa pokušaj '
              'ponovo.',
        );
      case WalletBiometricAuthStatus.locked:
        return const WalletBiometricAuthResult(
          status: WalletBiometricAuthStatus.locked,
          title: 'Biometrija je zaključana',
          message:
              'Otključaj telefon šifrom, a zatim ponovo potvrdi plaćanje '
              'biometrijom.',
        );
      case WalletBiometricAuthStatus.unavailable:
        return const WalletBiometricAuthResult(
          status: WalletBiometricAuthStatus.unavailable,
          title: 'Biometrija trenutno nije dostupna',
          message: 'Zatvori drugi biometrijski prozor i pokušaj ponovo.',
        );
      case WalletBiometricAuthStatus.failed:
        return const WalletBiometricAuthResult(
          status: WalletBiometricAuthStatus.failed,
          title: 'Potvrda nije uspjela',
          message:
              'Sistemska biometrijska provjera nije završena. Plaćanje '
              'nije evidentirano.',
        );
    }
  }
}
