import 'package:flutter/material.dart';

import '../../../core/theme/bsl_design_system.dart';
import '../models/ev_charging_session.dart';

class EvChargingSessionPanel extends StatelessWidget {
  final EvChargingSession session;
  final DateTime now;

  const EvChargingSessionPanel({
    super.key,
    required this.session,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final energy = session.energyAt(now);
    final elapsed = session.elapsedAt(now);
    final power = session.powerKw ?? session.ratedPowerKw;
    final isStale =
        session.source == EvChargingSessionSource.operatorLive &&
        now.difference(session.updatedAt).abs() > const Duration(minutes: 2);
    final statusColor = _statusColor(session.status, isStale: isStale);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xA6070B18),
        borderRadius: BorderRadius.circular(BslRadius.medium),
        border: Border.all(color: statusColor.withValues(alpha: 0.56)),
        boxShadow: BslShadows.cyanGlow(alpha: 0.07),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(BslRadius.pill),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.52),
                  ),
                ),
                child: Text(
                  session.source == EvChargingSessionSource.operatorLive
                      ? 'OPERATOR • UŽIVO'
                      : 'BSL PROCJENA',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isStale ? 'Podaci kasne' : _statusLabel(session.status),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SessionMetric(
                  icon: Icons.battery_charging_full_rounded,
                  value: '${_formatEnergy(energy)} kWh',
                  label: session.isEstimated
                      ? 'procijenjena energija'
                      : 'isporučena energija',
                  color: BslColors.cyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SessionMetric(
                  icon: Icons.timer_outlined,
                  value: _formatDuration(elapsed),
                  label: 'trajanje',
                  color: BslColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SessionMetric(
                  icon: Icons.bolt_rounded,
                  value: power == null ? '—' : '${_formatPower(power)} kW',
                  label: session.isEstimated
                      ? 'nazivna snaga'
                      : 'trenutna snaga',
                  color: BslColors.warning,
                ),
              ),
              if (session.batteryPercent != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _SessionMetric(
                    icon: Icons.ev_station_rounded,
                    value: '${session.batteryPercent!.toStringAsFixed(0)}%',
                    label: 'baterija vozila',
                    color: BslColors.success,
                  ),
                ),
              ] else ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _SessionMetric(
                    icon: Icons.electrical_services_rounded,
                    value: session.connectorLabel.isEmpty
                        ? '—'
                        : session.connectorLabel,
                    label: 'priključak',
                    color: BslColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                session.isEstimated
                    ? Icons.info_outline_rounded
                    : Icons.verified_rounded,
                color: session.isEstimated
                    ? BslColors.warning
                    : BslColors.success,
                size: 15,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _description(session, isStale: isStale),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 10.5,
                    height: 1.25,
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

class _SessionMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SessionMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 59),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(BslRadius.small),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _description(EvChargingSession session, {required bool isStale}) {
  if (session.isEstimated) {
    return 'Procjena koristi nazivnu snagu. BSL nije povezan s mjeračem '
        'punjača i ovim dugmetom ne pokreće fizičko punjenje.';
  }

  if (isStale) {
    return 'Posljednji podatak operatora stariji je od dvije minute. Vrijednosti '
        'se ne smatraju trenutnim dok ne stigne novo osvježenje.';
  }

  final provider = session.providerName.trim();
  return provider.isEmpty
      ? 'Podaci dolaze iz potvrđenog operatorskog kanala.'
      : 'Podaci dolaze iz potvrđenog kanala operatora $provider.';
}

String _statusLabel(EvChargingSessionStatus status) {
  switch (status) {
    case EvChargingSessionStatus.preparing:
      return 'Priprema punjenja';
    case EvChargingSessionStatus.charging:
      return 'Punjenje aktivno';
    case EvChargingSessionStatus.paused:
      return 'Punjenje pauzirano';
    case EvChargingSessionStatus.completed:
      return 'Punjenje završeno';
    case EvChargingSessionStatus.failed:
      return 'Greška punjenja';
  }
}

Color _statusColor(EvChargingSessionStatus status, {required bool isStale}) {
  if (isStale) return BslColors.warning;

  switch (status) {
    case EvChargingSessionStatus.preparing:
    case EvChargingSessionStatus.paused:
      return BslColors.warning;
    case EvChargingSessionStatus.charging:
      return BslColors.success;
    case EvChargingSessionStatus.completed:
      return BslColors.cyan;
    case EvChargingSessionStatus.failed:
      return BslColors.danger;
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String _formatEnergy(double value) {
  if (value < 10) return value.toStringAsFixed(2);
  return value.toStringAsFixed(1);
}

String _formatPower(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
