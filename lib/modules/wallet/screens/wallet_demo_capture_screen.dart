import 'package:flutter/material.dart';

import '../../../core/theme/bsl_design_system.dart';
import '../models/wallet_demo_models.dart';

enum WalletDemoCaptureMode { merchantQr, parkingQr, nfc }

class WalletDemoCaptureScreen extends StatefulWidget {
  final WalletDemoCaptureMode mode;

  const WalletDemoCaptureScreen({super.key, required this.mode});

  @override
  State<WalletDemoCaptureScreen> createState() =>
      _WalletDemoCaptureScreenState();
}

class _WalletDemoCaptureScreenState extends State<WalletDemoCaptureScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _detected = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  WalletDemoPaymentRequest get _request {
    switch (widget.mode) {
      case WalletDemoCaptureMode.merchantQr:
        return const WalletDemoPaymentRequest(
          id: 'merchant_qr_demo',
          title: 'BSL City Shop',
          subtitle: 'QR plaćanje • Sarajevo',
          amount: 13.80,
          category: WalletTransactionCategory.merchant,
        );
      case WalletDemoCaptureMode.parkingQr:
        return const WalletDemoPaymentRequest(
          id: 'parking_machine_demo',
          title: 'Parking aparat PA-104',
          subtitle: 'Zona 1 • 90 minuta',
          amount: 3,
          category: WalletTransactionCategory.parkingMachine,
        );
      case WalletDemoCaptureMode.nfc:
        return const WalletDemoPaymentRequest(
          id: 'merchant_nfc_demo',
          title: 'BSL Urban Market',
          subtitle: 'NFC terminal • Sarajevo',
          amount: 24.90,
          category: WalletTransactionCategory.merchant,
        );
    }
  }

  bool get _isNfc => widget.mode == WalletDemoCaptureMode.nfc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BslColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_isNfc ? 'NFC plaćanje' : 'Skeniraj BSL QR'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Column(
            children: [
              const _HardwareDemoBanner(),
              const Spacer(),
              AnimatedSwitcher(
                duration: BslDurations.normal,
                child: _detected
                    ? _DetectedPaymentCard(request: _request)
                    : _isNfc
                    ? _NfcTarget(animation: _pulseController)
                    : _QrTarget(animation: _pulseController),
              ),
              const Spacer(),
              if (!_detected) ...[
                Text(
                  _isNfc
                      ? 'U produkciji korisnik prislanja telefon na certificirani terminal.'
                      : 'U produkciji kamera očitava dinamički QR trgovca ili parking aparata.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: BslColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('wallet-simulate-capture'),
                    onPressed: () => setState(() => _detected = true),
                    style: BslButtons.primary(),
                    icon: Icon(
                      _isNfc
                          ? Icons.contactless_rounded
                          : Icons.qr_code_scanner_rounded,
                    ),
                    label: Text(
                      _isNfc
                          ? 'Simuliraj NFC terminal'
                          : 'Simuliraj očitanje QR koda',
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('wallet-capture-continue'),
                    onPressed: () => Navigator.pop(context, _request),
                    style: BslButtons.primary(),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Nastavi na izbor kartice'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _detected = false),
                  child: const Text('Ponovi simulaciju'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HardwareDemoBanner extends StatelessWidget {
  const _HardwareDemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: BslColors.warning.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(BslRadius.small),
        border: Border.all(color: BslColors.warning.withValues(alpha: 0.30)),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_rounded, color: BslColors.warning, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'HARDWARE DEMO • nema komunikacije s pravim terminalom i nema naplate',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrTarget extends StatelessWidget {
  final Animation<double> animation;

  const _QrTarget({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          key: const ValueKey('wallet-qr-target'),
          width: 250,
          height: 250,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xB30D1428),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: BslColors.cyan.withValues(
                alpha: 0.45 + animation.value * 0.35,
              ),
              width: 2,
            ),
            boxShadow: BslShadows.cyanGlow(
              alpha: 0.12 + animation.value * 0.10,
            ),
          ),
          child: const Icon(
            Icons.qr_code_2_rounded,
            color: Colors.white,
            size: 150,
          ),
        );
      },
    );
  }
}

class _NfcTarget extends StatelessWidget {
  final Animation<double> animation;

  const _NfcTarget({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = 0.94 + animation.value * 0.08;
        return Transform.scale(
          scale: scale,
          child: Container(
            key: const ValueKey('wallet-nfc-target'),
            width: 245,
            height: 245,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  BslColors.cyan.withValues(alpha: 0.30),
                  BslColors.blue.withValues(alpha: 0.16),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: BslColors.cyan.withValues(alpha: 0.42),
                width: 2,
              ),
              boxShadow: BslShadows.cyanGlow(
                alpha: 0.16 + animation.value * 0.12,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.contactless_rounded, color: Colors.white, size: 88),
                SizedBox(height: 11),
                Text(
                  'PRISLONI TELEFON',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetectedPaymentCard extends StatelessWidget {
  final WalletDemoPaymentRequest request;

  const _DetectedPaymentCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('wallet-capture-detected'),
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BslDecorations.glassCard(radius: BslRadius.large),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 31,
            backgroundColor: Color(0x2635D07F),
            child: Icon(
              Icons.check_rounded,
              color: BslColors.success,
              size: 36,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'Zahtjev za plaćanje prepoznat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            request.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            request.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: BslColors.textSecondary),
          ),
          const SizedBox(height: 17),
          Text(
            '${request.amount.toStringAsFixed(2)} KM',
            style: const TextStyle(
              color: BslColors.cyan,
              fontSize: 31,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
