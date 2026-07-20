import 'package:flutter/material.dart';

import '../../../core/theme/bsl_design_system.dart';

class WalletSecurityCard extends StatelessWidget {
  final VoidCallback onTap;

  const WalletSecurityCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(BslRadius.medium),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: BslColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(BslRadius.medium),
            border: Border.all(
              color: BslColors.success.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BslColors.success.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: BslColors.success,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Produkcijski podaci ostaju kod providera',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Demo čuva maskirani prikaz; produkcija samo token.',
                      style: TextStyle(
                        color: BslColors.textSecondary,
                        fontSize: 10.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: BslColors.success),
            ],
          ),
        ),
      ),
    );
  }
}
