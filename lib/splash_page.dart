import 'package:flutter/material.dart';
import 'package:kashr/widgets/floating_bubbles.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoIconScaleAnimation;
  late Animation<double> _logoTextScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<Offset> _textSlideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoIconScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _logoTextScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const FloatingBubbles(),
            _buildContent(context, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 4),
          _buildAnimatedLogoIcon(),
          const SizedBox(height: 12),
          _buildAnimatedLogoText(),
          const Spacer(flex: 1),
          _buildAnimatedText(context, colorScheme),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  final _logoSize = 80.0;

  Widget _buildAnimatedLogoIcon() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _logoOpacityAnimation,
          child: ScaleTransition(
            scale: _logoIconScaleAnimation,
            child: SizedBox(
              height: _logoSize,
              child: Image.asset(
                'assets/logo-icon-transparent.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedLogoText() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _logoOpacityAnimation,
          child: ScaleTransition(
            scale: _logoTextScaleAnimation,
            child: SizedBox(
              height: 140 / 151 * _logoSize,
              child: Image.asset(
                'assets/logo-text-transparent.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedText(BuildContext context, ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _textOpacityAnimation,
          child: SlideTransition(
            position: _textSlideAnimation,
            child: Column(
              children: [
                const SizedBox(height: 48),
                Text(
                  'Catch your cash before it swims away',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [CircularProgressIndicator()],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
