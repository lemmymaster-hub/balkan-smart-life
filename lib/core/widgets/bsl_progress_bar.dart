import 'package:flutter/material.dart';

import '../theme/bsl_design_system.dart';

class BslProgressBar extends StatelessWidget {
  final double value;
  final String label;
  final String? subtitle;
  final bool showPercentage;

  /// Ukupan broj parking mjesta.
  final int? totalSegments;

  /// Broj trenutno zauzetih parking mjesta.
  final int? filledSegments;

  const BslProgressBar({
    super.key,
    required this.value,
    required this.label,
    this.subtitle,
    this.showPercentage = true,
    this.totalSegments,
    this.filledSegments,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0);
    final percentage = (safeValue * 100).round();
    final progressColor = _getProgressColor(safeValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (showPercentage)
              Text(
                '$percentage%',
                style: TextStyle(
                  color: progressColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        _SegmentedProgressTrack(
          value: safeValue,
          progressColor: progressColor,
          totalSegments: totalSegments,
          filledSegments: filledSegments,
        ),

        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Color _getProgressColor(double value) {
    if (value >= 0.85) {
      return const Color(0xFFEF4444);
    }

    if (value >= 0.60) {
      return const Color(0xFFF59E0B);
    }

    return const Color(0xFF22C55E);
  }
}

class _SegmentedProgressTrack extends StatelessWidget {
  final double value;
  final Color progressColor;
  final int? totalSegments;
  final int? filledSegments;

  const _SegmentedProgressTrack({
    required this.value,
    required this.progressColor,
    required this.totalSegments,
    required this.filledSegments,
  });

  @override
  Widget build(BuildContext context) {
    const maximumVisibleSegments = 100;

    final rawTotal = totalSegments ?? maximumVisibleSegments;
    final rawFilled =
        filledSegments ?? (rawTotal * value).round();

    final safeTotal = rawTotal <= 0 ? 1 : rawTotal;
    final safeFilled = rawFilled.clamp(0, safeTotal);

    final visibleSegments = safeTotal > maximumVisibleSegments
        ? maximumVisibleSegments
        : safeTotal;

    final visibleFilled = safeTotal > maximumVisibleSegments
        ? (visibleSegments * value).round()
        : safeFilled;

    return Container(
      height: 22,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(BslRadius.pill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 1.5;

          final totalGapWidth =
              gap * (visibleSegments - 1);

          final availableWidth =
              constraints.maxWidth - totalGapWidth;

          final segmentWidth =
              (availableWidth / visibleSegments)
                  .clamp(1.2, 8.0);

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              visibleSegments,
              (index) {
                final isFilled = index < visibleFilled;

                return Padding(
                  padding: EdgeInsets.only(
                    right:
                        index == visibleSegments - 1 ? 0 : gap,
                  ),
                  child: AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    width: segmentWidth,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: isFilled
                          ? progressColor
                          : Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: progressColor.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}