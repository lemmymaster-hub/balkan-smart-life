import 'package:flutter/material.dart';

class BslColors {
  static const bgDark = Color(0xFF070B18);

  static const glassCyan = Color(0xFF0DAFC0);
  static const glassBlue = Color(0xFF24649A);
  static const glassPurple = Color(0xFF272C73);

  static const cyan = Color(0xFF2FE6FF);
  static const cyanStrong = Color(0xFF00D4FF);
  static const blue = Color(0xFF245BFF);
  static const purple = Color(0xFF7B61FF);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFD3D8E8);

  static const success = Color(0xFF35D07F);
  static const warning = Color(0xFFFFB020);
  static const danger = Color(0xFFFF4D6D);
}

class BslRadius {
  static const small = 14.0;
  static const medium = 18.0;
  static const large = 24.0;
  static const xl = 32.0;
  static const pill = 99.0;
}

class BslDurations {
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);
}

class BslShadows {
  static List<BoxShadow> cyanGlow({double alpha = 0.18}) {
    return [
      BoxShadow(
        color: BslColors.cyanStrong.withValues(alpha: alpha),
        blurRadius: 28,
        spreadRadius: 1,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static List<BoxShadow> deepShadow() {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.28),
        blurRadius: 22,
        offset: const Offset(0, 12),
      ),
    ];
  }
}

class BslDecorations {
  static BoxDecoration glassCard({
    double radius = BslRadius.large,
    double alpha = 0.88,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          BslColors.glassCyan.withValues(alpha: 0.78),
          BslColors.glassBlue.withValues(alpha: 0.72),
          BslColors.glassPurple.withValues(alpha: 0.76),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: BslColors.cyan.withValues(alpha: 0.42),
        width: 1.2,
      ),
      boxShadow: [
        ...BslShadows.cyanGlow(alpha: 0.16),
        ...BslShadows.deepShadow(),
      ],
    );
  }

  static BoxDecoration bottomPanel() {
    return glassCard(radius: BslRadius.xl, alpha: 0.92);
  }

  static BoxDecoration softPill() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(BslRadius.pill),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    );
  }
}

class BslButtons {
  static ButtonStyle primary() {
    return ElevatedButton.styleFrom(
      backgroundColor: BslColors.cyanStrong,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BslRadius.medium),
      ),
    );
  }
}

class BslTextStyles {
  static const title = TextStyle(
    color: BslColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w800,
  );

  static const subtitle = TextStyle(
    color: BslColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const body = TextStyle(
    color: BslColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
}

Color bslParkingMarkerColor({required int freeSpots, required int totalSpots}) {
  if (totalSpots <= 0) return BslColors.textSecondary;

  final ratio = freeSpots / totalSpots;

  if (ratio > 0.5) return BslColors.success;
  if (ratio > 0.2) return BslColors.warning;
  return BslColors.danger;
}
