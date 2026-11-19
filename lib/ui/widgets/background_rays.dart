import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Animated blurred ray effect in the background, matching the CSS ray-pivot design.
class BackgroundRays extends StatefulWidget {
  const BackgroundRays({super.key});

  @override
  State<BackgroundRays> createState() => _BackgroundRaysState();
}

class _BackgroundRaysState extends State<BackgroundRays>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 35),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Calculates the rotation angle (in radians) for a given animation progress
  /// and phase offset (in seconds).
  double _getRotationAngle(double progress, double offsetSeconds) {
    // 35s loop
    final phaseFraction = (offsetSeconds / 35.0);
    final adjustedProgress = (progress + phaseFraction) % 1.0;

    // Sinusoidal ease-in-out rotation from 0 deg to -75 deg and back to 0 deg
    final normalized = (1 - math.cos(adjustedProgress * 2 * math.pi)) / 2;
    final maxAngleRadians = -75.0 * (math.pi / 180.0);
    return normalized * maxAngleRadians;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rayOpacity = isDark ? 0.30 : 0.22;

    final rayConfigs = [
      (color: AppColors.tealLight, offsetSec: 0.0),
      (color: AppColors.green, offsetSec: 2.5),
      (color: AppColors.tealDark, offsetSec: 5.0),
    ];

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;
          final rayHeight = screenHeight * 3;

          return Stack(
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Stack(
                      children: rayConfigs.map((config) {
                        final angle = _getRotationAngle(
                          _controller.value,
                          config.offsetSec,
                        );

                        return Positioned(
                          top: -screenHeight,
                          left: 0,
                          width: 160,
                          height: rayHeight,
                          child: Transform.rotate(
                            angle: angle,
                            alignment: Alignment.topLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    config.color.withValues(alpha: rayOpacity),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.85],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
