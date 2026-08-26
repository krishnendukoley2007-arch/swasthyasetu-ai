import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

class AppPageTransitions {
  static const Duration defaultDuration = Duration(milliseconds: 400);

  static PageRouteBuilder<T> fadeScale<T>({
    required Widget child,
    Duration duration = defaultDuration,
    RouteSettings? settings,
    Offset beginOffset = const Offset(0, 0.1),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppTheme.curveDecelerate,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
              child: child,
            ),
          ),
        );
      },
    );
  }

  static PageRouteBuilder<T> slideFromRight<T>({
    required Widget child,
    Duration duration = defaultDuration,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppTheme.curveDecelerate,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      },
    );
  }

  static PageRouteBuilder<T> slideFromBottom<T>({
    required Widget child,
    Duration duration = defaultDuration,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppTheme.curveDecelerate,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      },
    );
  }

  static PageRouteBuilder<T> scaleFade<T>({
    required Widget child,
    Duration duration = defaultDuration,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppTheme.curveDecelerate,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }

  static PageRouteBuilder<T> morphingPage<T>({
    required Widget child,
    Duration duration = const Duration(milliseconds: 500),
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      opaque: false,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppTheme.curveSpring,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: AppTheme.curveBounce),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class AppHeroController {
  static const Duration duration = Duration(milliseconds: 500);

  static Widget wrap({
    required String tag,
    required Widget child,
    bool flightShuttleBuilder = false,
    Widget? placeholderBuilder,
  }) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: flightShuttleBuilder
          ? (context, animation, flightDirection, fromHeroContext, toHeroContext) {
              return DefaultTextStyle(
                style: DefaultTextStyle.of(context).style,
                child: toHeroContext.widget,
              );
            }
          : null,
      placeholderBuilder: placeholderBuilder != null
          ? (context, size, widget) => placeholderBuilder
          : null,
      child: child,
    );
  }
}

class AppAnimatedSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Widget Function(Widget, Animation<double>)? transitionBuilder;

  const AppAnimatedSwitcher({
    super.key,
    required this.child,
    this.duration = AppPageTransitions.defaultDuration,
    this.curve = AppTheme.curveStandard,
    this.transitionBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve.flipped,
      transitionBuilder: transitionBuilder ?? _defaultTransitionBuilder,
      child: child,
    );
  }

  Widget _defaultTransitionBuilder(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
        child: child,
      ),
    );
  }
}

class AppStaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Axis axis;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final double startOffset;

  const AppStaggeredList({
    super.key,
    required this.children,
    this.duration = AppTheme.durationMd,
    this.delay = const Duration(milliseconds: 80),
    this.curve = AppTheme.curveDecelerate,
    this.axis = Axis.vertical,
    // Zero, not a token gap: the vertical callers space their own cards and
    // `spacing` was ignored before, so honouring it with a non-zero default
    // would double every gap in the app.
    this.spacing = 0,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.startOffset = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    return Flex(
      // `axis` used to be accepted and ignored — every caller asking for a row
      // silently got a column, and the `Expanded` children they wrote for that
      // row ended up applying flex parent data to the animation wrapper
      // instead of the flex, which breaks layout outright.
      direction: axis,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      spacing: spacing,
      children: [
        for (final (index, child) in children.indexed) _animate(index, child),
      ],
    );
  }

  /// Wraps [child] in its stagger, keeping flex parent data on the outside.
  ///
  /// A `Flexible`/`Expanded` has to stay the direct child of the [Flex], so the
  /// animation goes *inside* it rather than around it.
  Widget _animate(int index, Widget child) {
    Widget staggered(Widget inner) => _StaggeredItem(
          index: index,
          duration: duration,
          delay: delay,
          curve: curve,
          startOffset: startOffset,
          child: inner,
        );

    if (child is Flexible) {
      return Flexible(
        flex: child.flex,
        fit: child.fit,
        child: staggered(child.child),
      );
    }

    // A Spacer is nothing but flex parent data; animating it is meaningless and
    // would misparent it the same way.
    if (child is Spacer) return child;

    if (axis == Axis.horizontal) {
      // Peer tiles across a row: without a share of the width each one takes
      // its intrinsic size and the row overflows as soon as the text scales up.
      return Expanded(child: staggered(child));
    }

    return staggered(child);
  }
}

class _StaggeredItem extends StatefulWidget {
  final int index;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double startOffset;
  final Widget child;

  const _StaggeredItem({
    required this.index,
    required this.duration,
    required this.delay,
    required this.curve,
    required this.startOffset,
    required this.child,
  });

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.startOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    // Held and cancelled rather than fire-and-forget: an orphaned timer keeps
    // the state alive after the route is popped.
    _startTimer = Timer(widget.delay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class AppShimmer extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;
  final double angle;

  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1800),
    this.angle = -0.3,
  });

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.baseColor ?? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final highlightColor = widget.highlightColor ?? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.1, 0.5, 0.9],
              begin: Alignment(-1.0 + 2.0 * _controller.value, widget.angle),
              end: Alignment(1.0 + 2.0 * _controller.value, -widget.angle),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class AppSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;

  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: AppShimmer(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
      ),
    );
  }
}

class AppSkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double spacing;
  final EdgeInsetsGeometry? padding;

  const AppSkeletonList({
    super.key,
    required this.itemCount,
    this.itemHeight = 72,
    this.spacing = AppTheme.spacingSm,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        children: List.generate(itemCount, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : spacing),
            child: AppSkeleton(
              height: itemHeight,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
          );
        }),
      ),
    );
  }
}

class AppRippleEffect extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final double? radius;
  final BorderRadius? borderRadius;
  final double minTouchTargetSize;

  const AppRippleEffect({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.radius,
    this.borderRadius,
    this.minTouchTargetSize = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rippleColor = color ?? theme.colorScheme.primary.withValues(alpha: 0.3);
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(AppTheme.radiusMd);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: effectiveBorderRadius,
        splashColor: rippleColor,
        highlightColor: rippleColor.withValues(alpha: 0.1),
        radius: radius,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minTouchTargetSize,
            minHeight: minTouchTargetSize,
          ),
          child: child,
        ),
      ),
    );
  }
}

class AppPulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final Color? color;
  final bool repeat;

  const AppPulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
    this.minScale = 0.95,
    this.maxScale = 1.05,
    this.color,
    this.repeat = true,
  });

  @override
  State<AppPulseAnimation> createState() => _AppPulseAnimationState();
}

class _AppPulseAnimationState extends State<AppPulseAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    
    if (widget.repeat) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: widget.child,
        );
      },
    );
  }
}

class AppMorphingContainer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final BorderRadius? startBorderRadius;
  final BorderRadius? endBorderRadius;
  final double? startWidth;
  final double? endWidth;
  final double? startHeight;
  final double? endHeight;
  final List<Color>? startColors;
  final List<Color>? endColors;
  final AlignmentGeometry? startAlignment;
  final AlignmentGeometry? endAlignment;

  const AppMorphingContainer({
    super.key,
    required this.child,
    this.duration = AppTheme.durationMd,
    this.curve = AppTheme.curveStandard,
    this.startBorderRadius,
    this.endBorderRadius,
    this.startWidth,
    this.endWidth,
    this.startHeight,
    this.endHeight,
    this.startColors,
    this.endColors,
    this.startAlignment,
    this.endAlignment,
  });

  @override
  State<AppMorphingContainer> createState() => _AppMorphingContainerState();
}

class _AppMorphingContainerState extends State<AppMorphingContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<BorderRadius?>? _borderRadiusAnimation;
  late Animation<double>? _widthAnimation;
  late Animation<double>? _heightAnimation;
  late Animation<Color?>? _colorAnimation;
  late Animation<Alignment>? _alignmentAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    if (widget.startBorderRadius != null && widget.endBorderRadius != null) {
      _borderRadiusAnimation = BorderRadiusTween(
        begin: widget.startBorderRadius,
        end: widget.endBorderRadius,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    }
    
    if (widget.startWidth != null && widget.endWidth != null) {
      _widthAnimation = Tween<double>(
        begin: widget.startWidth,
        end: widget.endWidth,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    }
    
    if (widget.startHeight != null && widget.endHeight != null) {
      _heightAnimation = Tween<double>(
        begin: widget.startHeight,
        end: widget.endHeight,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    }
    
    if (widget.startColors != null && widget.endColors != null) {
      _colorAnimation = ColorTween(
        begin: widget.startColors!.first,
        end: widget.endColors!.first,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    }
    
    if (widget.startAlignment != null && widget.endAlignment != null) {
      _alignmentAnimation = AlignmentTween(
        begin: widget.startAlignment as Alignment,
        end: widget.endAlignment as Alignment,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void forward() => _controller.forward();
  void reverse() => _controller.reverse();
  void toggle() => _controller.isCompleted ? _controller.reverse() : _controller.forward();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: _widthAnimation?.value,
          height: _heightAnimation?.value,
          alignment: _alignmentAnimation?.value,
          decoration: BoxDecoration(
            borderRadius: _borderRadiusAnimation?.value,
            gradient: widget.startColors != null && widget.endColors != null && _colorAnimation != null
                ? LinearGradient(
                    colors: [
                      _colorAnimation!.value ?? widget.startColors!.first,
                      widget.endColors!.last,
                    ],
                    begin: widget.startAlignment ?? Alignment.topLeft,
                    end: widget.endAlignment ?? Alignment.bottomRight,
                  )
                : null,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class AppParticleSystem extends StatefulWidget {
  final int particleCount;
  final Color color;
  final double minSize;
  final double maxSize;
  final Duration duration;
  final bool repeat;
  final Widget? child;

  const AppParticleSystem({
    super.key,
    this.particleCount = 20,
    required this.color,
    this.minSize = 4,
    this.maxSize = 12,
    this.duration = const Duration(milliseconds: 3000),
    this.repeat = true,
    this.child,
  });

  @override
  State<AppParticleSystem> createState() => _AppParticleSystemState();
}

class _AppParticleSystemState extends State<AppParticleSystem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _particles = List.generate(widget.particleCount, (index) => _Particle.random(_random));
    
    if (widget.repeat) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            if (widget.child != null) widget.child!,
            ..._particles.map((particle) => _buildParticle(particle)),
          ],
        );
      },
    );
  }

  Widget _buildParticle(_Particle particle) {
    final progress = _controller.value;
    final size = particle.size * (1 - progress * 0.5);
    final opacity = (1 - progress) * particle.opacity;
    
    return Positioned(
      left: particle.startX + (particle.endX - particle.startX) * progress,
      top: particle.startY + (particle.endY - particle.startY) * progress - progress * particle.height * 0.3,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double size;
  final double opacity;
  final double height;

  _Particle({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.size,
    required this.opacity,
    required this.height,
  });

  static _Particle random(Random random) {
    return _Particle(
      startX: random.nextDouble(),
      startY: random.nextDouble(),
      endX: random.nextDouble(),
      endY: random.nextDouble() * 0.3,
      size: 4 + random.nextDouble() * 8,
      opacity: 0.3 + random.nextDouble() * 0.7,
      height: 100 + random.nextDouble() * 200,
    );
  }
}

class AppConfetti extends StatefulWidget {
  final int count;
  final List<Color> colors;
  final Duration duration;
  final VoidCallback? onComplete;

  const AppConfetti({
    super.key,
    this.count = 50,
    required this.colors,
    this.duration = const Duration(milliseconds: 2000),
    this.onComplete,
  });

  @override
  State<AppConfetti> createState() => _AppConfettiState();
}

class _AppConfettiState extends State<AppConfetti> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ConfettiPiece> _pieces;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _pieces = List.generate(widget.count, (index) => _ConfettiPiece.random(_random, widget.colors));
    
    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: _pieces.map((piece) => _buildPiece(piece)).toList(),
        );
      },
    );
  }

  Widget _buildPiece(_ConfettiPiece piece) {
    final progress = _controller.value;
    final x = piece.startX + (piece.endX - piece.startX) * progress;
    final y = piece.startY + (piece.endY - piece.startY) * progress + piece.gravity * progress * progress * 0.5;
    final rotation = piece.rotation * progress * 4;
    final opacity = (1 - progress).clamp(0.0, 1.0);
    
    return Positioned(
      left: x * MediaQuery.of(context).size.width,
      top: y * MediaQuery.of(context).size.height,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: rotation,
          child: Container(
            width: piece.size,
            height: piece.size * piece.aspectRatio,
            decoration: BoxDecoration(
              color: piece.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double size;
  final double aspectRatio;
  final double rotation;
  final double gravity;
  final Color color;

  _ConfettiPiece({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.size,
    required this.aspectRatio,
    required this.rotation,
    required this.gravity,
    required this.color,
  });

  static _ConfettiPiece random(Random random, List<Color> colors) {
    return _ConfettiPiece(
      startX: 0.5,
      startY: 0.0,
      endX: 0.1 + random.nextDouble() * 0.8,
      endY: 0.5 + random.nextDouble() * 0.5,
      size: 6 + random.nextDouble() * 8,
      aspectRatio: 0.5 + random.nextDouble() * 1.5,
      rotation: (random.nextDouble() - 0.5) * 6.28,
      gravity: 0.5 + random.nextDouble() * 1.5,
      color: colors[random.nextInt(colors.length)],
    );
  }
}

class AppNumberTicker extends StatefulWidget {
  final int value;
  final Duration duration;
  final Curve curve;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;

  const AppNumberTicker({
    super.key,
    required this.value,
    this.duration = AppTheme.durationLg,
    this.curve = AppTheme.curveDecelerate,
    this.style,
    this.prefix,
    this.suffix,
  });

  @override
  State<AppNumberTicker> createState() => _AppNumberTickerState();
}

class _AppNumberTickerState extends State<AppNumberTicker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = IntTween(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AppNumberTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = IntTween(begin: oldWidget.value, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: widget.curve),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return RichText(
          text: TextSpan(
            style: widget.style ?? Theme.of(context).textTheme.displayLarge,
            children: [
              if (widget.prefix != null) TextSpan(text: widget.prefix),
              TextSpan(text: _animation.value.toString()),
              if (widget.suffix != null) TextSpan(text: widget.suffix),
            ],
          ),
        );
      },
    );
  }
}

class AppTypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration characterDelay;
  final Duration initialDelay;
  final VoidCallback? onComplete;

  const AppTypewriterText({
    super.key,
    required this.text,
    this.style,
    this.characterDelay = const Duration(milliseconds: 30),
    this.initialDelay = Duration.zero,
    this.onComplete,
  });

  @override
  State<AppTypewriterText> createState() => _AppTypewriterTextState();
}

class _AppTypewriterTextState extends State<AppTypewriterText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _charCountAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.characterDelay * widget.text.length + widget.initialDelay,
      vsync: this,
    );
    _charCountAnimation = IntTween(begin: 0, end: widget.text.length).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    
    if (widget.initialDelay > Duration.zero) {
      Future.delayed(widget.initialDelay, () {
        if (mounted) _startAnimation();
      });
    } else {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _charCountAnimation,
      builder: (context, child) {
        final visibleText = widget.text.substring(0, _charCountAnimation.value.clamp(0, widget.text.length));
        return Text(
          visibleText,
          style: widget.style ?? Theme.of(context).textTheme.bodyLarge,
        );
      },
    );
  }
}

class AppProgressRing extends StatefulWidget {
  final double progress;
  final double strokeWidth;
  final Color? progressColor;
  final Color? backgroundColor;
  final double size;
  final Duration duration;
  final Widget? child;

  const AppProgressRing({
    super.key,
    required this.progress,
    this.strokeWidth = 8,
    this.progressColor,
    this.backgroundColor,
    this.size = 64,
    this.duration = AppTheme.durationMd,
    this.child,
  });

  @override
  State<AppProgressRing> createState() => _AppProgressRingState();
}

class _AppProgressRingState extends State<AppProgressRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.curveDecelerate),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AppProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _progressAnimation = Tween<double>(begin: oldWidget.progress, end: widget.progress).animate(
        CurvedAnimation(parent: _controller, curve: AppTheme.curveDecelerate),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = widget.progressColor ?? theme.colorScheme.primary;
    final backgroundColor = widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _ProgressRingPainter(
                  progress: _progressAnimation.value,
                  strokeWidth: widget.strokeWidth,
                  progressColor: progressColor,
                  backgroundColor: backgroundColor,
                ),
              ),
              if (widget.child != null) widget.child!,
            ],
          ),
        );
      },
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color backgroundColor;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _ProgressRingPainter && oldDelegate.progress != progress;
  }
}

class AppWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;
  final double strokeWidth;
  final Color? fillColor;
  final double animationValue;
  final bool showGrid;
  final Color? gridColor;

  AppWaveformPainter({
    required this.waveform,
    required this.color,
    this.strokeWidth = 2,
    this.fillColor,
    this.animationValue = 1.0,
    this.showGrid = false,
    this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (showGrid) {
      final gridPaint = Paint()
        ..color = gridColor ?? color.withValues(alpha: 0.05)
        ..strokeWidth = 0.5;

      for (int i = 0; i <= 10; i++) {
        final y = size.height * i / 10;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
      for (int i = 0; i <= 20; i++) {
        final x = size.width * i / 20;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
    }

    final path = Path();
    final visiblePoints = (waveform.length * animationValue).round().clamp(0, waveform.length);

    for (int i = 0; i < visiblePoints; i++) {
      final x = (i / (waveform.length - 1)) * size.width;
      final y = size.height - (waveform[i] * size.height).clamp(0, size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (fillColor != null) {
      final fillPath = Path.from(path);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            fillColor!.withValues(alpha: 0.15),
            fillColor!.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is AppWaveformPainter && 
           oldDelegate.animationValue != animationValue &&
           oldDelegate.waveform != waveform;
  }
}

extension NavigatorExtensions on NavigatorState {
  Future<T?> pushFadeScale<T extends Object?>(Widget page) {
    return push<T>(AppPageTransitions.fadeScale<T>(child: page));
  }

  Future<T?> pushSlideFromRight<T extends Object?>(Widget page) {
    return push<T>(AppPageTransitions.slideFromRight<T>(child: page));
  }

  Future<T?> pushSlideFromBottom<T extends Object?>(Widget page) {
    return push<T>(AppPageTransitions.slideFromBottom<T>(child: page));
  }

  Future<T?> pushScaleFade<T extends Object?>(Widget page) {
    return push<T>(AppPageTransitions.scaleFade<T>(child: page));
  }

  Future<T?> pushMorphingPage<T extends Object?>(Widget page) {
    return push<T>(AppPageTransitions.morphingPage<T>(child: page));
  }
}

extension AnimationExtensions on AnimationController {
  Future<void> forwardThenReverse({Duration? duration}) async {
    await forward();
    await reverse();
  }

  Future<void> repeatTimes(int times) async {
    for (int i = 0; i < times; i++) {
      await forward();
      await reverse();
    }
  }
}

class ReducedMotion {
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  static Duration getDuration(BuildContext context, Duration normal, {Duration? reduced}) {
    return shouldReduceMotion(context) ? (reduced ?? Duration.zero) : normal;
  }

  static T getValue<T>(BuildContext context, T normal, T reduced) {
    return shouldReduceMotion(context) ? reduced : normal;
  }
}