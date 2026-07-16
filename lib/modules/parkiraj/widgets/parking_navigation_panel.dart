import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../../../core/theme/bsl_design_system.dart';
import '../controllers/parking_navigation_controller.dart';

class ParkingNavigationPanel extends StatelessWidget {
  const ParkingNavigationPanel({
    super.key,
    required this.stage,
    required this.statusMessage,
    required this.navInfo,
    required this.onRecenter,
  });

  final ParkingNavigationStage stage;
  final String statusMessage;
  final NavInfo? navInfo;
  final VoidCallback onRecenter;

  bool get _isBusy {
    return stage == ParkingNavigationStage.preparing ||
        stage == ParkingNavigationStage.waitingForGps ||
        stage == ParkingNavigationStage.calculatingRoute;
  }

  bool get _isGuiding {
    return stage == ParkingNavigationStage.guiding ||
        stage == ParkingNavigationStage.rerouting ||
        stage == ParkingNavigationStage.gpsLost;
  }

  @override
  Widget build(BuildContext context) {
    final step = navInfo?.currentStep;
    final instruction = switch (stage) {
      ParkingNavigationStage.rerouting ||
      ParkingNavigationStage.gpsLost ||
      ParkingNavigationStage.arrived ||
      ParkingNavigationStage.error => statusMessage,
      _ => _instruction(step, statusMessage),
    };
    final accent = _accentColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _NavigationIcon(
              icon: _isBusy ? null : _maneuverIcon(step?.maneuver, stage),
              color: accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isGuiding &&
                      navInfo?.distanceToCurrentStepMeters != null)
                    Text(
                      _formatDistance(
                        navInfo!.distanceToCurrentStepMeters!,
                      ),
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  Text(
                    instruction,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (_isGuiding)
              IconButton.filledTonal(
                onPressed: onRecenter,
                tooltip: 'Vrati prateću kameru',
                style: IconButton.styleFrom(
                  backgroundColor: BslColors.cyan.withValues(alpha: 0.13),
                  foregroundColor: BslColors.cyan,
                ),
                icon: const Icon(Icons.my_location_rounded, size: 19),
              ),
          ],
        ),
        if (_isGuiding && navInfo != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RouteMetric(
                  icon: Icons.route_rounded,
                  value: _formatDistance(
                    navInfo!.distanceToFinalDestinationMeters,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RouteMetric(
                  icon: Icons.schedule_rounded,
                  value: _formatDuration(
                    navInfo!.timeToFinalDestinationSeconds,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color get _accentColor {
    switch (stage) {
      case ParkingNavigationStage.gpsLost:
      case ParkingNavigationStage.error:
        return BslColors.danger;
      case ParkingNavigationStage.rerouting:
        return BslColors.warning;
      case ParkingNavigationStage.arrived:
        return BslColors.success;
      case ParkingNavigationStage.idle:
      case ParkingNavigationStage.preparing:
      case ParkingNavigationStage.waitingForGps:
      case ParkingNavigationStage.calculatingRoute:
      case ParkingNavigationStage.guiding:
        return BslColors.cyan;
    }
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({required this.icon, required this.color});

  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(BslRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: icon == null
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(color: color, strokeWidth: 2.4),
            )
          : Icon(icon, color: color, size: 27),
    );
  }
}

class _RouteMetric extends StatelessWidget {
  const _RouteMetric({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BslDecorations.softPill(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: BslColors.cyan, size: 16),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _instruction(StepInfo? step, String fallback) {
  final fullInstruction = step?.fullInstructions?.trim();
  if (fullInstruction != null && fullInstruction.isNotEmpty) {
    return fullInstruction;
  }

  final roadName = step?.fullRoadName?.trim();
  if (roadName != null && roadName.isNotEmpty) {
    return 'Nastavi prema $roadName';
  }

  return fallback;
}

String _formatDistance(int? meters) {
  if (meters == null || meters < 0) return '—';
  if (meters < 1000) return '$meters m';

  final kilometers = meters / 1000;
  return kilometers < 10
      ? '${kilometers.toStringAsFixed(1)} km'
      : '${kilometers.toStringAsFixed(0)} km';
}

String _formatDuration(int? seconds) {
  if (seconds == null || seconds < 0) return '—';
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '$minutes min';

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) return '$hours h';
  return '$hours h $remainingMinutes min';
}

IconData _maneuverIcon(Maneuver? maneuver, ParkingNavigationStage stage) {
  if (stage == ParkingNavigationStage.arrived) {
    return Icons.local_parking_rounded;
  }
  if (stage == ParkingNavigationStage.gpsLost) {
    return Icons.gps_off_rounded;
  }
  if (stage == ParkingNavigationStage.error) {
    return Icons.error_outline_rounded;
  }
  if (maneuver == null) return Icons.navigation_rounded;

  final name = maneuver.name.toLowerCase();
  if (name.contains('destination')) return Icons.local_parking_rounded;
  if (name.contains('roundabout')) return Icons.roundabout_right_rounded;
  if (name.contains('uturn')) return Icons.u_turn_left_rounded;
  if (name.contains('ferry')) return Icons.directions_boat_rounded;
  if (name.contains('keepleft')) return Icons.fork_left_rounded;
  if (name.contains('keepright')) return Icons.fork_right_rounded;
  if (name.contains('left')) return Icons.turn_left_rounded;
  if (name.contains('right')) return Icons.turn_right_rounded;
  if (name.contains('merge')) return Icons.merge_rounded;
  if (maneuver == Maneuver.straight || maneuver == Maneuver.depart) {
    return Icons.straight_rounded;
  }
  return Icons.navigation_rounded;
}
