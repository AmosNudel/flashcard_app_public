import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A card widget that performs a 3D flip animation around its Y-axis.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    this.isFlipped = false,
    this.onFlip,
    this.duration = const Duration(milliseconds: 400),
  });

  final Widget front;
  final Widget back;
  final bool isFlipped;
  final VoidCallback? onFlip;
  final Duration duration;

  @override
  State<FlipCard> createState() => FlipCardState();
}

class FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late bool _isBackVisible;

  @override
  void initState() {
    super.initState();
    _isBackVisible = widget.isFlipped;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: _isBackVisible ? 1.0 : 0.0,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );

    _controller.addListener(() {
      final isBack = _controller.value >= 0.5;
      if (isBack != _isBackVisible) {
        setState(() {
          _isBackVisible = isBack;
        });
      }
    });
  }

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  void toggleFlip() {
    if (widget.onFlip != null) {
      widget.onFlip!();
    } else {
      if (_controller.isAnimating) return;
      if (_isBackVisible) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  /// Reset card to front without animation (e.g. when loading a new card).
  void resetFront() {
    _controller.value = 0.0;
    setState(() {
      _isBackVisible = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: toggleFlip,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * math.pi;
          final isBack = angle >= (math.pi / 2);

          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(angle);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    transform: Matrix4.identity()..rotateY(math.pi),
                    alignment: Alignment.center,
                    child: widget.back,
                  )
                : widget.front,
          );
        },
      ),
    );
  }
}
