import 'package:flutter/material.dart';

class BslParkingBottomCard extends StatelessWidget {
  const BslParkingBottomCard({
    super.key,
    required this.title,
    required this.distanceText,
    required this.freeSpotsText,
    required this.priceText,
    required this.isOpen,
    this.onNavigate,
    this.onDetails,
    this.onPay,
  });

  final String title;
  final String distanceText;
  final String freeSpotsText;
  final String priceText;
  final bool isOpen;

  final VoidCallback? onNavigate;
  final VoidCallback? onDetails;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final statusColor = isOpen ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xEE0B1220),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.local_parking_rounded,
                    color: Color(0xFF38BDF8),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    isOpen ? 'Otvoreno' : 'Zatvoreno',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                _InfoChip(
                  icon: Icons.near_me_rounded,
                  label: distanceText,
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.event_seat_rounded,
                  label: freeSpotsText,
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.payments_rounded,
                  label: priceText,
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Navigacija',
                    icon: Icons.navigation_rounded,
                    onTap: onNavigate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: 'Detalji',
                    icon: Icons.expand_more_rounded,
                    onTap: onDetails,
                    secondary: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: 'Plati',
                    icon: Icons.credit_card_rounded,
                    onTap: onPay,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF93C5FD), size: 17),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.secondary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final bgColor = secondary
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFF0EA5E9).withValues(alpha: 0.22);

    final borderColor = secondary
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFF38BDF8).withValues(alpha: 0.35);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: secondary ? const Color(0xFFE5E7EB) : const Color(0xFF7DD3FC),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: secondary ? const Color(0xFFE5E7EB) : const Color(0xFFE0F2FE),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}