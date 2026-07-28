import 'package:flutter/material.dart';

import '../modules/ai_assistant/widgets/bsl_ai_answer_sheet.dart';
import '../modules/ai_assistant/widgets/bsl_ai_ask_field.dart';

typedef BslCityChanged = Future<void> Function(String city);

class BslHomeHeader extends StatelessWidget {
  final String selectedCity;
  final List<String> cities;
  final BslCityChanged onCityChanged;
  final BslAiAskCallback onAsk;
  final BslAiActionCallback? onAction;

  const BslHomeHeader({
    super.key,
    required this.selectedCity,
    required this.cities,
    required this.onCityChanged,
    required this.onAsk,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cityColumnWidth = constraints.maxWidth >= 360 ? 148.0 : 132.0;

        return Container(
          height: 128,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF14243D), Color(0xFF0A1021)],
            ),
            border: Border.all(
              color: Colors.cyanAccent.withValues(alpha: 0.23),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.17),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -42,
                right: -30,
                child: Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.cyanAccent.withValues(alpha: 0.045),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: cityColumnWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 3),
                          child: Text(
                            'IZABERI GRAD',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.75,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        _CompactCitySelector(
                          selectedCity: selectedCity,
                          cities: cities,
                          onChanged: onCityChanged,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BslAiAskField(
                      city: selectedCity,
                      onAsk: onAsk,
                      onAction: onAction,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactCitySelector extends StatelessWidget {
  final String selectedCity;
  final List<String> cities;
  final BslCityChanged onChanged;

  const _CompactCitySelector({
    required this.selectedCity,
    required this.cities,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Izaberi grad',
      button: true,
      child: Container(
        height: 43,
        padding: const EdgeInsets.only(left: 11, right: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedCity,
            isExpanded: true,
            isDense: true,
            dropdownColor: const Color(0xFF111A33),
            borderRadius: BorderRadius.circular(16),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF77E9FF),
              size: 19,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            selectedItemBuilder: (context) {
              return cities
                  .map(
                    (city) => Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  )
                  .toList(growable: false);
            },
            items: cities
                .map(
                  (city) => DropdownMenuItem<String>(
                    value: city,
                    child: Text(city, maxLines: 1),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) async {
              if (value != null && value != selectedCity) {
                await onChanged(value);
              }
            },
          ),
        ),
      ),
    );
  }
}
