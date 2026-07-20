import 'package:flutter/material.dart';

import '../../../core/theme/bsl_design_system.dart';

class WalletPayAnywhereCard extends StatelessWidget {
  final VoidCallback onScanMerchantQr;
  final VoidCallback onScanParkingMachine;
  final VoidCallback onNfcPayment;

  const WalletPayAnywhereCard({
    super.key,
    required this.onScanMerchantQr,
    required this.onScanParkingMachine,
    required this.onNfcPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BslColors.glassCyan.withValues(alpha: 0.26),
            BslColors.glassBlue.withValues(alpha: 0.24),
            BslColors.glassPurple.withValues(alpha: 0.30),
          ],
        ),
        borderRadius: BorderRadius.circular(BslRadius.large),
        border: Border.all(color: BslColors.cyan.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: BslColors.cyan),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Plati u gradu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _DemoPill(),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Simulacija QR ili NFC plaćanja u prodavnici i na parking aparatu.',
            style: TextStyle(
              color: BslColors.textSecondary,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PayAnywhereButton(
                  key: const ValueKey('wallet-scan-merchant'),
                  icon: Icons.storefront_rounded,
                  label: 'Prodavnica',
                  onTap: onScanMerchantQr,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _PayAnywhereButton(
                  key: const ValueKey('wallet-scan-parking-machine'),
                  icon: Icons.local_parking_rounded,
                  label: 'Parking aparat',
                  onTap: onScanParkingMachine,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: _PayAnywhereButton(
              key: const ValueKey('wallet-pay-nfc'),
              icon: Icons.contactless_rounded,
              label: 'NFC • Prisloni telefon na terminal',
              onTap: onNfcPayment,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'NFC je u demo režimu; pravi terminal zahtijeva certificiranu '
            'tokenizaciju i podršku payment providera.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 9,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayAnywhereButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PayAnywhereButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        backgroundColor: Colors.white.withValues(alpha: 0.055),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BslRadius.small),
        ),
      ),
      icon: Icon(icon, color: BslColors.cyan, size: 19),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _DemoPill extends StatelessWidget {
  const _DemoPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BslColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BslRadius.pill),
        border: Border.all(color: BslColors.warning.withValues(alpha: 0.35)),
      ),
      child: const Text(
        'DEMO',
        style: TextStyle(
          color: BslColors.warning,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
