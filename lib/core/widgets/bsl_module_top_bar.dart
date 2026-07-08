import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/bsl_design_system.dart';

class BslModuleTopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badge;
  final String searchHint;
  final VoidCallback? onBack;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final ValueChanged<String>? onSearchSubmitted;

  const BslModuleTopBar({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
    this.searchHint = 'Pretraži...',
    this.onBack,
    this.searchController,
    this.searchFocusNode,
    this.onSearchSubmitted,
  });

  static const double _bottomRadius = 28;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(_bottomRadius),
        bottomRight: Radius.circular(_bottomRadius),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0DAFC0).withValues(alpha: 0.72),
                const Color(0xFF24649A).withValues(alpha: 0.68),
                const Color(0xFF272C73).withValues(alpha: 0.72),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(_bottomRadius),
              bottomRight: Radius.circular(_bottomRadius),
            ),
            border: Border(
              bottom: BorderSide(
                color: BslColors.cyan.withValues(alpha: 0.32),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: BslColors.cyanStrong.withValues(alpha: 0.18),
                blurRadius: 32,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -42,
                right: -46,
                child: _GlowCircle(size: 138, alpha: 0.08),
              ),
              Positioned(
                left: -34,
                bottom: 42,
                child: _GlassReflection(width: 160, height: 52),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _GlassIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: onBack ?? () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: BslTextStyles.body.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              overflow: TextOverflow.ellipsis,
                              style: BslTextStyles.subtitle.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (badge != null && badge!.trim().isNotEmpty)
                        _Badge(text: badge!),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _SearchField(
                    hint: searchHint,
                    controller: searchController,
                    focusNode: searchFocusNode,
                    onSubmitted: onSearchSubmitted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  const _SearchField({
    required this.hint,
    this.controller,
    this.focusNode,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BslDecorations.softPill(),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: BslColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: BslColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BslDecorations.softPill(),
      child: Text(
        text,
        style: const TextStyle(
          color: BslColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(BslRadius.pill),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BslDecorations.softPill(),
        child: Icon(
          icon,
          color: BslColors.textPrimary,
          size: 17,
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final double alpha;

  const _GlowCircle({
    required this.size,
    required this.alpha,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

class _GlassReflection extends StatelessWidget {
  final double width;
  final double height;

  const _GlassReflection({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BslRadius.pill),
        color: Colors.white.withValues(alpha: 0.055),
      ),
    );
  }
}