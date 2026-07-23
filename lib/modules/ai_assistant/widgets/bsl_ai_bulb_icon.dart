import 'package:flutter/material.dart';

class BslAiBulbIcon extends StatelessWidget {
  final double size;

  const BslAiBulbIcon({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'BSL AI',
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          'assets/images/bsl_ai_bulb.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
