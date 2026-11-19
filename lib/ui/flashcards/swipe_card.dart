import 'dart:math' as math;
import 'package:flutter/material.dart';

enum SwipeDirection { left, right }

/// A card wrapper that can be swiped off-screen horizontally.
class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.child,
    required this.onSwiped,
    this.enabled = true,
  });

  final Widget child;
  final ValueChanged<SwipeDirection> onSwiped;
  final bool enabled;

  @override
  State<SwipeCard> createState() => SwipeCardState();
}

class SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  Offset _offset = Offset.zero;
  bool _isDragging = false;
  late final AnimationController _animController;
  Animation<Offset>? _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animController.addListener(() {
      if (_offsetAnimation != null) {
        setState(() {
          _offset = _offsetAnimation!.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.enabled || _animController.isAnimating) return;
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _animController.isAnimating) return;
    setState(() {
      _offset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.enabled || _animController.isAnimating) return;
    _isDragging = false;

    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.3;
    final velocity = details.velocity.pixelsPerSecond.dx;

    final isSwipeRight = _offset.dx > threshold || velocity > 800;
    final isSwipeLeft = _offset.dx < -threshold || velocity < -800;

    if (isSwipeRight || isSwipeLeft) {
      final direction =
          isSwipeRight ? SwipeDirection.right : SwipeDirection.left;
      _animateOut(direction, velocity: velocity);
    } else {
      _animateToCenter();
    }
  }

  void _animateToCenter() {
    _offsetAnimation = Tween<Offset>(
      begin: _offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward(from: 0.0);
  }

  void _animateOut(SwipeDirection direction, {double velocity = 0}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetX = direction == SwipeDirection.right
        ? screenWidth * 1.5
        : -screenWidth * 1.5;

    _offsetAnimation = Tween<Offset>(
      begin: _offset,
      end: Offset(targetX, _offset.dy + (velocity * 0.1)),
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuad,
    ));

    _animController.forward(from: 0.0).then((_) {
      widget.onSwiped(direction);
      _reset();
    });
  }

  /// Programmatically trigger a swipe off-screen (e.g. from a Next button).
  void swipe(SwipeDirection direction) {
    if (_animController.isAnimating) return;
    _animateOut(direction);
  }

  void _reset() {
    _animController.stop();
    setState(() {
      _offset = Offset.zero;
      _offsetAnimation = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rotation = _offset.dx * 0.0008; // subtle rotation
    final screenWidth = MediaQuery.of(context).size.width;
    final opacity = (1.0 - (_offset.dx.abs() / (screenWidth * 1.2)))
        .clamp(0.0, 1.0);

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _offset,
        child: Transform.rotate(
          angle: rotation,
          child: Opacity(
            opacity: opacity,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
