import 'package:flutter/material.dart';

import '../../../core/theme/bsl_design_system.dart';
import '../models/wallet_service.dart';

class WalletQuickServiceCard extends StatelessWidget {
  final WalletService service;
  final VoidCallback onTap;

  const WalletQuickServiceCard({
    super.key,
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('wallet-service-${service.id}'),
        borderRadius: BorderRadius.circular(BslRadius.medium),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xD90D1428),
            borderRadius: BorderRadius.circular(BslRadius.medium),
            border: Border.all(
              color: service.accentColor.withValues(alpha: 0.26),
            ),
            boxShadow: [
              BoxShadow(
                color: service.accentColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: service.accentColor.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: service.accentColor.withValues(alpha: 0.34),
                      ),
                    ),
                    child: Icon(
                      service.icon,
                      color: service.accentColor,
                      size: 23,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.055),
                      borderRadius: BorderRadius.circular(BslRadius.pill),
                    ),
                    child: const Text(
                      'DEMO',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                service.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                service.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
