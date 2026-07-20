import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/bsl_design_system.dart';
import '../models/wallet_demo_models.dart';

class WalletDemoPaymentSheet extends StatefulWidget {
  final WalletDemoPaymentRequest request;
  final List<WalletDemoCard> cards;
  final String? initialCardId;

  const WalletDemoPaymentSheet({
    super.key,
    required this.request,
    required this.cards,
    this.initialCardId,
  });

  @override
  State<WalletDemoPaymentSheet> createState() => _WalletDemoPaymentSheetState();
}

class _WalletDemoPaymentSheetState extends State<WalletDemoPaymentSheet> {
  String? _selectedCardId;

  @override
  void initState() {
    super.initState();
    if (widget.cards.any((card) => card.id == widget.initialCardId)) {
      _selectedCardId = widget.initialCardId;
    } else if (widget.cards.isNotEmpty) {
      _selectedCardId = widget.cards.first.id;
    }
  }

  void _confirmWithBiometrics() {
    final selectedCardId = _selectedCardId;
    if (selectedCardId == null) return;
    Navigator.pop(context, selectedCardId);
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _selectedCardId != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(32),
            bottom: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.90,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xE60A1022),
                    Color(0xDB111D3B),
                    Color(0xE60B1225),
                  ],
                ),
                border: Border.all(
                  color: BslColors.cyan.withValues(alpha: 0.28),
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                  bottom: Radius.circular(24),
                ),
                boxShadow: BslShadows.cyanGlow(alpha: 0.13),
              ),
              child: Stack(
                children: [
                  const Positioned(
                    left: -76,
                    top: 88,
                    child: _BiometricGlowOrb(
                      size: 190,
                      color: Color(0x242FE6FF),
                    ),
                  ),
                  const Positioned(
                    right: -88,
                    top: 248,
                    child: _BiometricGlowOrb(
                      size: 210,
                      color: Color(0x207B61FF),
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 13),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0x332FE6FF),
                                    Color(0x267B61FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: BslColors.cyan.withValues(alpha: 0.36),
                                ),
                              ),
                              child: const Text(
                                'BSL',
                                style: TextStyle(
                                  color: BslColors.cyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 11),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Biometrijska potvrda',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'DEMO • nema stvarne naplate',
                                    style: TextStyle(
                                      color: BslColors.warning,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                              color: Colors.white70,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                widget.request.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.request.subtitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: BslColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '${widget.request.amount.toStringAsFixed(2)} KM',
                                style: const TextStyle(
                                  color: BslColors.cyan,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        _BiometricFingerprintHero(
                          enabled: canConfirm,
                          onTap: _confirmWithBiometrics,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Izaberi karticu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                        ...widget.cards.map(
                          (card) => _CardChoice(
                            card: card,
                            selected: card.id == _selectedCardId,
                            onTap: () =>
                                setState(() => _selectedCardId = card.id),
                          ),
                        ),
                        const SizedBox(height: 13),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.045),
                            borderRadius: BorderRadius.circular(
                              BslRadius.small,
                            ),
                            border: Border.all(
                              color: BslColors.success.withValues(alpha: 0.20),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                color: BslColors.success,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Nakon dodira otvara se zaštićeni sistemski '
                                  'prozor. BSL ne čita niti čuva otisak ili '
                                  'Face ID podatke.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.5,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const ValueKey('wallet-confirm-demo-payment'),
                            onPressed: canConfirm
                                ? _confirmWithBiometrics
                                : null,
                            style: BslButtons.primary(),
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: const Text('Otvori sigurnu biometriju'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BiometricFingerprintHero extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _BiometricFingerprintHero({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Potvrdi plaćanje biometrijom',
      hint: 'Otvara zaštićeni biometrijski prozor uređaja',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('wallet-biometric-fingerprint'),
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.86, end: 1),
                  duration: const Duration(milliseconds: 720),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: SizedBox(
                    width: 132,
                    height: 132,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 124,
                          height: 124,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: BslColors.cyan.withValues(alpha: 0.035),
                            border: Border.all(
                              color: BslColors.cyan.withValues(alpha: 0.14),
                            ),
                          ),
                        ),
                        Container(
                          width: 98,
                          height: 98,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                BslColors.cyan.withValues(alpha: 0.18),
                                BslColors.blue.withValues(alpha: 0.08),
                              ],
                            ),
                            border: Border.all(
                              color: BslColors.cyan.withValues(alpha: 0.48),
                              width: 1.4,
                            ),
                            boxShadow: BslShadows.cyanGlow(alpha: 0.28),
                          ),
                        ),
                        Icon(
                          Icons.fingerprint_rounded,
                          color: enabled ? BslColors.cyan : Colors.white38,
                          size: 66,
                          shadows: enabled
                              ? [
                                  Shadow(
                                    color: BslColors.cyan.withValues(
                                      alpha: 0.70,
                                    ),
                                    blurRadius: 18,
                                  ),
                                ]
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  enabled
                      ? 'Dodirni otisak za potvrdu'
                      : 'Izaberi karticu za nastavak',
                  style: TextStyle(
                    color: enabled ? BslColors.cyan : Colors.white54,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
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

class _BiometricGlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BiometricGlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _CardChoice extends StatelessWidget {
  final WalletDemoCard card;
  final bool selected;
  final VoidCallback onTap;

  const _CardChoice({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(BslRadius.small),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? BslColors.cyan.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(BslRadius.small),
              border: Border.all(
                color: selected
                    ? BslColors.cyan
                    : Colors.white.withValues(alpha: 0.09),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.credit_card_rounded,
                  color: selected ? BslColors.cyan : Colors.white54,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.nickname,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${card.brandLabel} •••• ${card.last4}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? BslColors.cyan : Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
