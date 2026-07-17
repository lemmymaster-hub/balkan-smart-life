import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../../../core/navigation/bsl_navigation_controller.dart';
import '../../../core/theme/bsl_design_system.dart';
import '../../../core/widgets/bsl_navigation_panel.dart';
import '../models/ev_charger.dart';

class EvChargerBottomCard extends StatelessWidget {
  final EvCharger charger;
  final bool navigationVisible;
  final bool navigationActive;
  final bool navigationBusy;
  final BslNavigationStage navigationStage;
  final String navigationStatusMessage;
  final NavInfo? navigationInfo;
  final bool navigationCanRetry;
  final VoidCallback onRecenter;
  final VoidCallback onNavigate;
  final VoidCallback onClose;

  const EvChargerBottomCard({
    super.key,
    required this.charger,
    required this.navigationVisible,
    required this.navigationActive,
    required this.navigationBusy,
    required this.navigationStage,
    required this.navigationStatusMessage,
    required this.navigationInfo,
    required this.navigationCanRetry,
    required this.onRecenter,
    required this.onNavigate,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _feeColor(charger.fee);
    final power = charger.maxPowerKw;
    final connectorSummary = charger.connectors.isEmpty
        ? 'Priključci nisu uneseni'
        : charger.connectors
              .map((connector) {
                final count = connector.count == null
                    ? ''
                    : ' ×${connector.count}';
                return '${connector.type}$count';
              })
              .join(' • ');
    final navigationNeedsRetry =
        navigationVisible &&
        navigationStage == BslNavigationStage.error &&
        navigationCanRetry;
    final navigationArrived =
        navigationVisible && navigationStage == BslNavigationStage.arrived;
    late final IconData navigationActionIcon;
    late final String navigationActionLabel;

    if (navigationBusy) {
      navigationActionIcon = Icons.navigation_rounded;
      navigationActionLabel = 'Pokrećem...';
    } else if (navigationNeedsRetry) {
      navigationActionIcon = Icons.refresh_rounded;
      navigationActionLabel = 'Ponovi';
    } else if (navigationArrived) {
      navigationActionIcon = Icons.check_rounded;
      navigationActionLabel = 'Završi';
    } else if (navigationVisible) {
      navigationActionIcon = Icons.stop_circle_outlined;
      navigationActionLabel = 'Zaustavi';
    } else {
      navigationActionIcon = Icons.navigation_rounded;
      navigationActionLabel = 'Navigacija';
    }

    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(minHeight: 220),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BslDecorations.bottomDock(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xCC07111F),
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.58),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.ev_station_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        charger.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        charger.address.isNotEmpty
                            ? charger.address
                            : charger.city,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white70,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: BslDurations.normal,
              child: navigationVisible
                  ? BslNavigationPanel(
                      key: const ValueKey('ev-charger-navigation'),
                      stage: navigationStage,
                      statusMessage: navigationStatusMessage,
                      navInfo: navigationInfo,
                      onRecenter: onRecenter,
                      destinationIcon: Icons.ev_station_rounded,
                    )
                  : Column(
                      key: const ValueKey('ev-charger-details'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(
                              icon: Icons.payments_outlined,
                              label: _feeLabel(charger),
                              color: statusColor,
                            ),
                            if (power != null)
                              _InfoChip(
                                icon: Icons.bolt_rounded,
                                label: '${_formatNumber(power)} kW',
                                color: BslColors.cyan,
                              ),
                            if (charger.capacity != null)
                              _InfoChip(
                                icon: Icons.electrical_services_rounded,
                                label: '${charger.capacity} mjesta',
                                color: BslColors.cyan,
                              ),
                            _InfoChip(
                              icon: charger.isVerified
                                  ? Icons.verified_rounded
                                  : Icons.travel_explore_rounded,
                              label: charger.isVerified
                                  ? 'Firestore potvrđeno'
                                  : 'OSM podatak',
                              color: charger.isVerified
                                  ? BslColors.success
                                  : BslColors.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 11),
                        Text(
                          connectorSummary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BslColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (charger.operatorName.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            'Operator: ${charger.operatorName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.58),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            _EvNavigationButton(
              icon: navigationActionIcon,
              label: navigationActionLabel,
              onTap: navigationBusy ? null : onNavigate,
              danger:
                  navigationVisible &&
                  !navigationNeedsRetry &&
                  !navigationArrived &&
                  navigationActive,
            ),
          ],
        ),
      ),
    );
  }
}

class EvOsmAttribution extends StatelessWidget {
  const EvOsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xC9070B18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: const Text(
        'Punjači © OpenStreetMap contributors',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class EvMapStatusPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool showProgress;

  const EvMapStatusPill({
    super.key,
    required this.icon,
    required this.text,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xED111A33),
        borderRadius: BorderRadius.circular(BslRadius.pill),
        border: Border.all(color: BslColors.cyan.withValues(alpha: 0.34)),
        boxShadow: BslShadows.cyanGlow(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showProgress)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: BslColors.cyan,
              ),
            )
          else
            Icon(icon, color: BslColors.cyan, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class EvChargerErrorCard extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const EvChargerErrorCard({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BslDecorations.glassCard(radius: BslRadius.medium),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: BslColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error.toString(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => unawaited(onRetry()),
            child: const Text(
              'Pokušaj ponovo',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvNavigationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  const _EvNavigationButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.danger,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? BslColors.danger : BslColors.cyan;

    return AnimatedOpacity(
      duration: BslDurations.fast,
      opacity: onTap == null ? 0.60 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(BslRadius.medium),
          child: Container(
            width: double.infinity,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(BslRadius.medium),
              border: Border.all(color: color.withValues(alpha: 0.40)),
              boxShadow: danger ? null : BslShadows.cyanGlow(alpha: 0.08),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 19),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x99111A33),
        borderRadius: BorderRadius.circular(BslRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.54)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color _feeColor(EvChargingFee fee) {
  switch (fee) {
    case EvChargingFee.free:
      return BslColors.success;
    case EvChargingFee.paid:
      return BslColors.danger;
    case EvChargingFee.unknown:
      return BslColors.warning;
  }
}

String _feeLabel(EvCharger charger) {
  switch (charger.fee) {
    case EvChargingFee.free:
      return 'Besplatno';
    case EvChargingFee.paid:
      return charger.priceLabel.isEmpty ? 'Plaća se' : charger.priceLabel;
    case EvChargingFee.unknown:
      return 'Cijena nepoznata';
  }
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
