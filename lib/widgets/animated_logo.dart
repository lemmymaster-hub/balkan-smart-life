import 'dart:async';
import 'package:flutter/material.dart';

class AnimatedBslLogo extends StatefulWidget {
  final double height;
  final Duration repeatDelay;

  const AnimatedBslLogo({
    super.key,
    this.height = 120,
    this.repeatDelay = const Duration(seconds: 30),
  });

  @override
  State<AnimatedBslLogo> createState() => _AnimatedBslLogoState();
}

class _AnimatedBslLogoState extends State<AnimatedBslLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _playShine();

    _timer = Timer.periodic(widget.repeatDelay, (_) {
      _playShine();
    });
  }

  void _playShine() {
    if (!mounted) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/bsl_logo.png',
                height: widget.height,
                fit: BoxFit.contain,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    child: Opacity(
                      opacity: _controller.value < 0.78
                          ? 1.0
                          : (1.0 - ((_controller.value - 0.78) / 0.22)).clamp(
                              0.0,
                              1.0,
                            ),
                      child: Align(
                        alignment: Alignment(
                          -1.35 + (_controller.value * 2.7),
                          1.35 - (_controller.value * 2.7),
                        ),
                        child: Transform.rotate(
                          angle: -0.78,
                          child: Container(
                            width: widget.height * 0.12,
                            height: widget.height * 1.45,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Color.fromRGBO(255, 255, 255, 0.18),
                                  Color.fromRGBO(255, 255, 255, 0.75),
                                  Color.fromRGBO(255, 255, 255, 0.18),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
