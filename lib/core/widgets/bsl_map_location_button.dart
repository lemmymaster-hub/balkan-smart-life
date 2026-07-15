import 'package:flutter/material.dart';

import '../theme/bsl_design_system.dart';

class BslMapLocationButton extends StatelessWidget {
  final bool isLoading;
  final bool hasLocation;
  final bool needsAttention;
  final VoidCallback onTap;

  const BslMapLocationButton({
    super.key,
    required this.isLoading,
    required this.hasLocation,
    required this.needsAttention,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = needsAttention
        ? Colors.orangeAccent
        : hasLocation
        ? BslColors.cyan
        : Colors.white70;

    return Material(
      color: const Color(0xEE111A33),
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: BslColors.cyan.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: BslColors.cyan,
                    ),
                  )
                : Icon(
                    needsAttention
                        ? Icons.location_disabled_rounded
                        : Icons.my_location_rounded,
                    color: color,
                    size: 25,
                  ),
          ),
        ),
      ),
    );
  }
}
