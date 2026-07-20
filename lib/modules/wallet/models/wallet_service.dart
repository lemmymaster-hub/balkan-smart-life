import 'package:flutter/material.dart';

class WalletService {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const WalletService({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

abstract final class WalletServices {
  static const parking = WalletService(
    id: 'parking',
    title: 'Parkiranje',
    subtitle: 'Plati odabrano parking mjesto',
    icon: Icons.local_parking_rounded,
    accentColor: Color(0xFF2FE6FF),
  );

  static const evCharging = WalletService(
    id: 'ev_charging',
    title: 'EL punjači',
    subtitle: 'Plati završenu sesiju punjenja',
    icon: Icons.ev_station_rounded,
    accentColor: Color(0xFF35D07F),
  );

  static const taxi = WalletService(
    id: 'taxi',
    title: 'Taxi',
    subtitle: 'Potvrdi i plati završenu vožnju',
    icon: Icons.local_taxi_rounded,
    accentColor: Color(0xFFFFB020),
  );

  static const bills = WalletService(
    id: 'bills',
    title: 'Računi',
    subtitle: 'Skeniraj i plati podržani račun',
    icon: Icons.receipt_long_rounded,
    accentColor: Color(0xFF9A7BFF),
  );

  static const values = <WalletService>[parking, evCharging, taxi, bills];
}
