import 'package:flutter/material.dart';

import '../../../core/theme/bsl_design_system.dart';
import '../models/wallet_demo_models.dart';

class WalletTransactionTile extends StatelessWidget {
  final WalletDemoTransaction transaction;

  const WalletTransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation(transaction.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xC90D1428),
        borderRadius: BorderRadius.circular(BslRadius.medium),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: presentation.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(presentation.icon, color: presentation.color, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_dateLabel(transaction.createdAt)} • •••• ${transaction.cardLast4}',
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _statusLabel(transaction.status),
                style: TextStyle(
                  color: _statusColor(transaction.status),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

({IconData icon, Color color}) _presentation(
  WalletTransactionCategory category,
) {
  switch (category) {
    case WalletTransactionCategory.bslService:
      return (icon: Icons.apps_rounded, color: BslColors.cyan);
    case WalletTransactionCategory.merchant:
      return (icon: Icons.storefront_rounded, color: BslColors.success);
    case WalletTransactionCategory.parkingMachine:
      return (icon: Icons.local_parking_rounded, color: BslColors.warning);
  }
}

String _statusLabel(WalletTransactionStatus status) {
  switch (status) {
    case WalletTransactionStatus.completed:
      return 'USPJEŠNO';
    case WalletTransactionStatus.pending:
      return 'U OBRADI';
    case WalletTransactionStatus.refunded:
      return 'VRAĆENO';
  }
}

Color _statusColor(WalletTransactionStatus status) {
  switch (status) {
    case WalletTransactionStatus.completed:
      return BslColors.success;
    case WalletTransactionStatus.pending:
      return BslColors.warning;
    case WalletTransactionStatus.refunded:
      return BslColors.cyan;
  }
}

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final isToday =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;

  if (isToday) {
    return 'Danas ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}.';
}
