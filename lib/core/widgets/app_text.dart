import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

class AppAnimatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double startOffset;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AppAnimatedText({
    super.key,
    required this.text,
    this.style,
    this.duration = AppTheme.durationMd,
    this.delay = Duration.zero,
    this.curve = AppTheme.curveDecelerate,
    this.startOffset = 0.3,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedTextItem(
      text: text,
      style: style,
      duration: duration,
      delay: delay,
      curve: curve,
      startOffset: startOffset,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class _AnimatedTextItem extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double startOffset;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const _AnimatedTextItem({
    required this.text,
    this.style,
    required this.duration,
    required this.delay,
    required this.curve,
    required this.startOffset,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  State<_AnimatedTextItem> createState() => _AnimatedTextItemState();
}

class _AnimatedTextItemState extends State<_AnimatedTextItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    if (widget.delay > Duration.zero) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Text(
          widget.text,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        ),
      ),
    );
  }
}

class AppAnimatedRichText extends StatelessWidget {
  final List<InlineSpan> children;
  final TextStyle? style;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double startOffset;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AppAnimatedRichText({
    super.key,
    required this.children,
    this.style,
    this.duration = AppTheme.durationMd,
    this.delay = Duration.zero,
    this.curve = AppTheme.curveDecelerate,
    this.startOffset = 0.3,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedRichTextItem(
      children: children,
      style: style,
      duration: duration,
      delay: delay,
      curve: curve,
      startOffset: startOffset,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class _AnimatedRichTextItem extends StatefulWidget {
  final List<InlineSpan> children;
  final TextStyle? style;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double startOffset;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const _AnimatedRichTextItem({
    required this.children,
    this.style,
    required this.duration,
    required this.delay,
    required this.curve,
    required this.startOffset,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  State<_AnimatedRichTextItem> createState() => _AnimatedRichTextItemState();
}

class _AnimatedRichTextItemState extends State<_AnimatedRichTextItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    if (widget.delay > Duration.zero) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: RichText(
          text: TextSpan(
            style: widget.style,
            children: widget.children,
          ),
          textAlign: widget.textAlign ?? TextAlign.start,
          maxLines: widget.maxLines,
          overflow: widget.overflow ?? TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class AppGradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<Color> colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AppGradientText({
    super.key,
    required this.text,
    this.style,
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: colors,
          begin: begin,
          end: end,
        ).createShader(bounds);
      },
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

class AppHighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AppHighlightText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = <TextSpan>[];
    int start = 0;
    int index = text.toLowerCase().indexOf(query.toLowerCase());

    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: style,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: highlightStyle ?? (style?.copyWith(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        )),
      ));
      start = index + query.length;
      index = text.toLowerCase().indexOf(query.toLowerCase(), start);
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
    );
  }
}

class AppMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final Duration pauseDuration;
  final Axis direction;
  final bool repeat;

  const AppMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(seconds: 8),
    this.pauseDuration = const Duration(seconds: 2),
    this.direction = Axis.horizontal,
    this.repeat = true,
  });

  @override
  State<AppMarqueeText> createState() => _AppMarqueeTextState();
}

class _AppMarqueeTextState extends State<AppMarqueeText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration + widget.pauseDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    if (widget.repeat) {
      _controller.repeat(period: widget.duration + widget.pauseDuration);
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
      animation: _animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final textPainter = TextPainter(
              text: TextSpan(text: widget.text, style: widget.style),
              textDirection: ui.TextDirection.ltr,
            );
            textPainter.layout();

            if (textPainter.width <= constraints.maxWidth) {
              return Text(widget.text, style: widget.style);
            }

            final offset = textPainter.width * _animation.value;
            return Transform.translate(
              offset: Offset(-offset, 0),
              child: Text(widget.text, style: widget.style),
            );
          },
        );
      },
    );
  }
}

class AppAnimatedCounter extends StatelessWidget {
  final num value;
  final Duration duration;
  final Curve curve;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;
  final int? decimalPlaces;
  final NumberFormat? numberFormat;

  const AppAnimatedCounter({
    super.key,
    required this.value,
    this.duration = AppTheme.durationLg,
    this.curve = AppTheme.curveDecelerate,
    this.style,
    this.prefix,
    this.suffix,
    this.decimalPlaces,
    this.numberFormat,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedCounter(
      value: value,
      duration: duration,
      curve: curve,
      style: style,
      prefix: prefix,
      suffix: suffix,
      decimalPlaces: decimalPlaces,
      numberFormat: numberFormat,
    );
  }
}

class _AnimatedCounter extends StatefulWidget {
  final num value;
  final Duration duration;
  final Curve curve;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;
  final int? decimalPlaces;
  final NumberFormat? numberFormat;

  const _AnimatedCounter({
    required this.value,
    required this.duration,
    required this.curve,
    this.style,
    this.prefix,
    this.suffix,
    this.decimalPlaces,
    this.numberFormat,
  });

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: oldWidget.value.toDouble(), end: widget.value.toDouble()).animate(
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

  String _formatValue(double value) {
    if (widget.numberFormat != null) {
      return widget.numberFormat!.format(value);
    }
    if (widget.decimalPlaces != null) {
      return value.toStringAsFixed(widget.decimalPlaces!);
    }
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final formattedValue = _formatValue(_animation.value);
        return RichText(
          text: TextSpan(
            style: widget.style ?? Theme.of(context).textTheme.displayLarge,
            children: [
              if (widget.prefix != null) TextSpan(text: widget.prefix),
              TextSpan(text: formattedValue),
              if (widget.suffix != null) TextSpan(text: widget.suffix),
            ],
          ),
        );
      },
    );
  }
}

class AppExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextStyle? linkStyle;
  final String expandText;
  final String collapseText;
  final Duration animationDuration;
  final Curve animationCurve;

  const AppExpandableText({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 3,
    this.linkStyle,
    this.expandText = 'Read more',
    this.collapseText = 'Show less',
    this.animationDuration = AppTheme.durationMd,
    this.animationCurve = AppTheme.curveStandard,
  });

  @override
  State<AppExpandableText> createState() => _AppExpandableTextState();
}

class _AppExpandableTextState extends State<AppExpandableText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _maxLinesAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _maxLinesAnimation = Tween<double>(begin: widget.maxLines.toDouble(), end: 100.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.animationCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style ?? Theme.of(context).textTheme.bodyMedium),
          textDirection: ui.TextDirection.ltr,
          maxLines: widget.maxLines,
        );
        textPainter.layout(maxWidth: constraints.maxWidth);

        if (!textPainter.didExceedMaxLines) {
          return Text(
            widget.text,
            style: widget.style ?? Theme.of(context).textTheme.bodyMedium,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Text(
                  widget.text,
                  style: widget.style ?? Theme.of(context).textTheme.bodyMedium,
                  maxLines: _maxLinesAnimation.value.toInt(),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            const SizedBox(height: AppTheme.spacingXs),
            GestureDetector(
              onTap: _toggle,
              child: Text(
                _isExpanded ? widget.collapseText : widget.expandText,
                style: widget.linkStyle ?? (widget.style ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}