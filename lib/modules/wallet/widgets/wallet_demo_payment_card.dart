import 'package:flutter/material.dart';

import '../../../core/theme/bsl_design_system.dart';
import '../models/wallet_demo_models.dart';

class WalletDemoPaymentCard extends StatelessWidget {
  final WalletDemoCard card;
  final VoidCallback onManage;

  const WalletDemoPaymentCard({
    super.key,
    required this.card,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _gradientFor(card.brand);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(BslRadius.large),
        border: Border.all(
          color: BslColors.cyan.withValues(alpha: 0.48),
          width: 1.2,
        ),
        boxShadow: [
          ...BslShadows.cyanGlow(alpha: 0.18),
          ...BslShadows.deepShadow(),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -42,
            right: -34,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BslColors.cyan.withValues(alpha: 0.08),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                  width: 18,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: BslColors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(BslRadius.pill),
                      border: Border.all(
                        color: BslColors.cyan.withValues(alpha: 0.40),
                      ),
                    ),
                    child: const Text(
                      'DEMO TOKEN',
                      style: TextStyle(
                        color: BslColors.cyan,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.65,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (card.isDefault)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: BslColors.success,
                      size: 20,
                    ),
                  IconButton(
                    key: ValueKey('wallet-manage-card-${card.id}'),
                    onPressed: onManage,
                    icon: const Icon(Icons.more_horiz_rounded),
                    color: Colors.white70,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                card.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                card.maskedNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VLASNIK',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          card.holderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SmallCardValue(label: 'VAŽI DO', value: card.expiryLabel),
                  const SizedBox(width: 16),
                  Text(
                    card.brandLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallCardValue extends StatelessWidget {
  final String label;
  final String value;

  const _SmallCardValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

List<Color> _gradientFor(WalletCardBrand brand) {
  switch (brand) {
    case WalletCardBrand.visa:
      return const [Color(0xFF0A4665), Color(0xFF15306F), Color(0xFF33256D)];
    case WalletCardBrand.mastercard:
      return const [Color(0xFF4A2536), Color(0xFF3C2C70), Color(0xFF173E69)];
    case WalletCardBrand.other:
      return const [Color(0xFF16484D), Color(0xFF26345F), Color(0xFF3A2A64)];
  }
}
