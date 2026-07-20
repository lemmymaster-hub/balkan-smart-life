import 'package:bsl_app/modules/wallet/services/wallet_biometric_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  test('uspješna sistemska provjera odobrava nastavak plaćanja', () async {
    final driver = _FakeBiometricDriver();
    final authenticator = LocalAuthWalletBiometricAuthenticator(driver: driver);

    final result = await authenticator.authenticate(
      localizedReason: 'Potvrdi plaćanje 2.00 KM.',
    );

    expect(result.status, WalletBiometricAuthStatus.authenticated);
    expect(result.isAuthenticated, isTrue);
    expect(driver.lastReason, 'Potvrdi plaćanje 2.00 KM.');
    expect(driver.authenticateCalls, 1);
  });

  test('ne pokušava autentikaciju ako uređaj nema biometriju', () async {
    final driver = _FakeBiometricDriver(supported: false);
    final authenticator = LocalAuthWalletBiometricAuthenticator(driver: driver);

    final result = await authenticator.authenticate(localizedReason: 'Test');

    expect(result.status, WalletBiometricAuthStatus.noHardware);
    expect(driver.authenticateCalls, 0);
  });

  test('traži registraciju biometrije ako nije podešena', () async {
    final driver = _FakeBiometricDriver(enrolled: false);
    final authenticator = LocalAuthWalletBiometricAuthenticator(driver: driver);

    final result = await authenticator.authenticate(localizedReason: 'Test');

    expect(result.status, WalletBiometricAuthStatus.notEnrolled);
    expect(result.message, contains('sigurnosnim postavkama'));
    expect(driver.authenticateCalls, 0);
  });

  test('otkazivanje sistemskog prozora ne odobrava plaćanje', () async {
    final driver = _FakeBiometricDriver(authenticated: false);
    final authenticator = LocalAuthWalletBiometricAuthenticator(driver: driver);

    final result = await authenticator.authenticate(localizedReason: 'Test');

    expect(result.status, WalletBiometricAuthStatus.canceled);
    expect(result.isAuthenticated, isFalse);
    expect(result.wasCanceled, isTrue);
  });

  test('mapira privremeno zaključavanje nakon pogrešnih otisaka', () async {
    final driver = _FakeBiometricDriver(
      error: const LocalAuthException(
        code: LocalAuthExceptionCode.temporaryLockout,
      ),
    );
    final authenticator = LocalAuthWalletBiometricAuthenticator(driver: driver);

    final result = await authenticator.authenticate(localizedReason: 'Test');

    expect(result.status, WalletBiometricAuthStatus.temporarilyLocked);
    expect(result.message, contains('previše neuspjelih pokušaja'));
  });
}

class _FakeBiometricDriver implements WalletBiometricDriver {
  _FakeBiometricDriver({
    this.supported = true,
    this.enrolled = true,
    this.authenticated = true,
    this.error,
  });

  final bool supported;
  final bool enrolled;
  final bool authenticated;
  final LocalAuthException? error;

  int authenticateCalls = 0;
  String? lastReason;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authenticateCalls += 1;
    lastReason = localizedReason;
    if (error != null) throw error!;
    return authenticated;
  }

  @override
  Future<bool> hasEnrolledBiometrics() async => enrolled;

  @override
  Future<bool> supportsBiometrics() async => supported;
}
