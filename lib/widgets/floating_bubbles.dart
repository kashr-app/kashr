import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class FloatingBubbles extends StatefulWidget {
  const FloatingBubbles({
    super.key,
    this.bubbleCount = 10,
    this.minSize = 40.0,
    this.maxSize = 120.0,
    this.minDuration = 8,
    this.maxDuration = 15,
    this.opacity = 0.05,
  });

  final int bubbleCount;
  final double minSize;
  final double maxSize;
  final int minDuration;
  final int maxDuration;
  final double opacity;

  @override
  State<FloatingBubbles> createState() => _FloatingBubblesState();
}

class _FloatingBubblesState extends State<FloatingBubbles>
    with TickerProviderStateMixin {
  final List<_Bubble> _bubbles = [];
  final math.Random _random = math.Random();
  Timer? _spawnTimer;

  var points = 0;
  var speed = 1;

  @override
  void initState() {
    super.initState();
    _initializeBubbles();
    _startSpawning();
  }

  void _initializeBubbles() {
    for (int i = 0; i < widget.bubbleCount; i++) {
      _addBubble(initialDelay: i * 0.5);
    }
  }

  void _startSpawning() {
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (_bubbles.length < widget.bubbleCount * 1.5) {
        _addBubble();
      }
    });
  }

  void _addBubble({double initialDelay = 0.0}) {
    final size =
        widget.minSize +
        _random.nextDouble() * (widget.maxSize - widget.minSize);
    final duration = Duration(
      seconds:
          ((widget.minDuration +
                      _random.nextInt(
                        widget.maxDuration - widget.minDuration,
                      )) *
                  1 /
                  ((speed +
                          3 // bump initial speed a little bit
                          ) /
                      10))
              .round(),
    );
    final startX = _random.nextDouble();
    final swayAmount = 30.0 + _random.nextDouble() * 40.0;

    final controller = AnimationController(duration: duration, vsync: this);
    final popController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    final bubble = _Bubble(
      size: size,
      startX: startX,
      swayAmount: swayAmount,
      controller: controller,
      popController: popController,
      initialDelay: initialDelay,
    );

    setState(() {
      _bubbles.add(bubble);
    });

    Future.delayed(Duration(milliseconds: (initialDelay * 1000).toInt()), () {
      if (mounted) {
        controller.forward().then((_) {
          if (mounted) {
            _removeBubble(bubble);
          }
        });
      }
    });
  }

  void _removeBubble(_Bubble bubble) {
    setState(() {
      _bubbles.remove(bubble);
    });
    bubble.controller.dispose();
    bubble.popController.dispose();
  }

  void _popBubble(_Bubble bubble) {
    if (bubble.isPopping) return;

    bubble.isPopping = true;
    bubble.controller.stop();
    points += (bubble.size / 10).round();
    speed += 1;
    bubble.popController.forward().then((_) {
      if (mounted) {
        _removeBubble(bubble);
      }
    });
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    for (final bubble in _bubbles) {
      bubble.controller.dispose();
      bubble.popController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            ..._bubbles.map((bubble) {
              return _BubbleWidget(
                bubble: bubble,
                constraints: constraints,
                color: colorScheme.primary,
                opacity: widget.opacity,
                onTap: () => _popBubble(bubble),
              );
            }),
            if (points > 0)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "You Catched $points\$",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        "Level: ${(speed / 10).round()}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Bubble {
  _Bubble({
    required this.size,
    required this.startX,
    required this.swayAmount,
    required this.controller,
    required this.popController,
    required this.initialDelay,
  });

  final double size;
  final double startX;
  final double swayAmount;
  final AnimationController controller;
  final AnimationController popController;
  final double initialDelay;
  bool isPopping = false;
}

class _BubbleWidget extends StatelessWidget {
  const _BubbleWidget({
    required this.bubble,
    required this.constraints,
    required this.color,
    required this.opacity,
    required this.onTap,
  });

  final _Bubble bubble;
  final BoxConstraints constraints;
  final Color color;
  final double opacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([bubble.controller, bubble.popController]),
      builder: (context, child) {
        final progress = bubble.controller.value;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final yPosition = height - (progress * (height + bubble.size));

        final swayProgress = math.sin(progress * math.pi * 3);
        final xOffset = swayProgress * bubble.swayAmount;
        final xPosition = (bubble.startX * width) + xOffset - bubble.size / 2;

        final fadeIn = (progress * 4).clamp(0.0, 1.0);
        final fadeOut = ((1 - progress) * 2).clamp(0.0, 1.0);
        var currentOpacity = opacity * fadeIn * fadeOut;

        final rotation = progress * math.pi * 4;

        final popProgress = bubble.popController.value;
        final popScale = 1.0 + (popProgress * 0.5);
        final popOpacity = 1.0 - popProgress;

        if (bubble.isPopping) {
          currentOpacity *= popOpacity;
        }

        return Positioned(
          left: xPosition,
          top: yPosition,
          child: GestureDetector(
            onTap: onTap,
            child: Transform.scale(
              scale: popScale,
              child: Transform.rotate(
                angle: rotation,
                child: Container(
                  width: bubble.size,
                  height: bubble.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: currentOpacity),
                    border: Border.all(
                      color: color.withValues(alpha: currentOpacity * 2),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
