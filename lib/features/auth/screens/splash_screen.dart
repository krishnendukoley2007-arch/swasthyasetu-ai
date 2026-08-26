import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/constants/app_constants.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _progressController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _titleFadeAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _subtitleFadeAnimation;
  late Animation<Offset> _subtitleSlideAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _progressBarAnimation;
  late Animation<double> _particleAnimation;

  final List<_Particle> _particles = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateParticles();
    _startSequence();
  }

  void _initializeAnimations() {
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: AppTheme.curveSpring),
    );

    _logoRotationAnimation = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: AppTheme.curveDecelerate),
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: AppTheme.curveDecelerate),
    );

    _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: AppTheme.curveDecelerate),
      ),
    );

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: AppTheme.curveDecelerate),
      ),
    );

    _subtitleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 0.8, curve: AppTheme.curveDecelerate),
      ),
    );

    _subtitleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 0.8, curve: AppTheme.curveDecelerate),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: AppTheme.curveStandard),
    );

    _progressBarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: const Interval(0.2, 1.0, curve: AppTheme.curveDecelerate)),
    );

    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_particleController);
  }

  void _generateParticles() {
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 2 + _random.nextDouble() * 4,
        speed: 0.1 + _random.nextDouble() * 0.3,
        opacity: 0.1 + _random.nextDouble() * 0.3,
        color: [
          AppTheme.primaryGreen,
          AppTheme.primaryGreenLight,
          AppTheme.secondaryTeal,
          AppTheme.accentAmber,
        ][_random.nextInt(4)],
      ));
    }
  }

  void _startSequence() async {
    await _logoController.forward();
    await _textController.forward();
    await _progressController.forward();
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      // '/' has no screen of its own — the router's auth guard turns it into
      // /login, /register/patient, /home or /my-health depending on the
      // session that was just restored.
      context.go('/');
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _particleAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _ParticlePainter(
                  particles: _particles,
                  animationValue: _particleAnimation.value,
                ),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_logoController, _particleAnimation]),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: Transform.rotate(
                        angle: _logoRotationAnimation.value,
                        child: Opacity(
                          opacity: _logoFadeAnimation.value,
                          child: _buildLogo(theme),
                        ),
                      ),
                    );
                  },
                ),
                const AppSpacing.vxl(),
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _titleFadeAnimation,
                      child: SlideTransition(
                        position: _titleSlideAnimation,
                        child: Text(
                          AppConstants.appName,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onPrimary,
                            letterSpacing: 1.5,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
                const AppSpacing.vsm(),
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _subtitleFadeAnimation,
                      child: SlideTransition(
                        position: _subtitleSlideAnimation,
                        child: Text(
                          AppConstants.appSubtitle,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
                const AppSpacing.vxl(),
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _progressAnimation,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 200,
                            height: 4,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                              child: LinearProgressIndicator(
                                value: _progressBarAnimation.value,
                                backgroundColor: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.onPrimary,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const AppSpacing.vsm(),
                          Text(
                            'Initializing...',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                            ),
                          ),
                          const AppSpacing.vxs(),
                          Text(
                            '${(_progressBarAnimation.value * 100).round()}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(ThemeData theme) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimary,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
            blurRadius: 40,
            spreadRadius: 5,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 5),
          ),
        ],
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.onPrimary,
            theme.colorScheme.onPrimary.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 70,
            color: theme.colorScheme.primary,
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.medical_services_rounded,
                size: 16,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double animationValue;

  _ParticlePainter({
    required this.particles,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final x = (particle.x + animationValue * particle.speed) % 1.0;
      final y = (particle.y - animationValue * particle.speed * 0.5) % 1.0;
      
      final paint = Paint()
        ..color = particle.color.withValues(alpha: particle.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _ParticlePainter && 
           oldDelegate.animationValue != animationValue;
  }
}