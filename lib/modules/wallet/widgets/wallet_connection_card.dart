import 'package:flutter/material.dart';

import '../../../core/theme/bsl_design_system.dart';

class WalletConnectionCard extends StatelessWidget {
  final VoidCallback onAddCard;

  const WalletConnectionCard({super.key, required this.onAddCard});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123653), Color(0xFF172C68), Color(0xFF33236F)],
        ),
        borderRadius: BorderRadius.circular(BslRadius.large),
        border: Border.all(
          color: BslColors.cyan.withValues(alpha: 0.54),
          width: 1.2,
        ),
        boxShadow: [
          ...BslShadows.cyanGlow(alpha: 0.20),
          ...BslShadows.deepShadow(),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -42,
            right: -32,
            child: _CardGlow(size: 150, color: Color(0x332FE6FF)),
          ),
          const Positioned(
            bottom: -52,
            left: -42,
            child: _CardGlow(size: 135, color: Color(0x267B61FF)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: BslColors.cyan,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BSL PAYMENTS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tokenizovano plaćanje usluga',
                          style: TextStyle(
                            color: BslColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: BslColors.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(BslRadius.pill),
                      border: Border.all(
                        color: BslColors.warning.withValues(alpha: 0.48),
                      ),
                    ),
                    child: const Text(
                      'NIJE POVEZANA',
                      style: TextStyle(
                        color: BslColors.warning,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              Text(
                '••••  ••••  ••••  ••••',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Simuliraj buduće povezivanje kroz sigurni prozor providera.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('wallet-add-card-button'),
                  onPressed: onAddCard,
                  style: FilledButton.styleFrom(
                    backgroundColor: BslColors.cyan,
                    foregroundColor: BslColors.bgDark,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BslRadius.medium),
                    ),
                  ),
                  icon: const Icon(Icons.add_card_rounded),
                  label: const Text(
                    'Dodaj demo karticu',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _CardGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 46, spreadRadius: 8)],
      ),
    );
  }
}
