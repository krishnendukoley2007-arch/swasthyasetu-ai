import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/app_animations.dart';

class AppBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double? fontSize;
  final FontWeight? fontWeight;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final BorderSide? border;
  final bool isDot;
  final double dotSize;
  final bool animate;
  final Duration animationDuration;

  const AppBadge({
    super.key,
    required this.label,
    this.color,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.fontSize,
    this.fontWeight,
    this.padding,
    this.borderRadius,
    this.border,
    this.isDot = false,
    this.dotSize = 8,
    this.animate = false,
    this.animationDuration = AppTheme.durationSm,
  });

  const AppBadge.dot({
    super.key,
    this.label = '',
    this.color,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.fontSize,
    this.fontWeight,
    this.padding,
    this.borderRadius,
    this.border,
    this.isDot = true,
    this.dotSize = 8,
    this.animate = false,
    this.animationDuration = AppTheme.durationSm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    final effectiveBackgroundColor = backgroundColor ?? effectiveColor.withValues(alpha: 0.1);
    final effectiveTextColor = textColor ?? effectiveColor;

    Widget badge = Container(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSm,
            vertical: AppTheme.spacingXs,
          ),
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusFull),
        border: border != null ? Border.fromBorderSide(border!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: (fontSize ?? 11) + 2, color: effectiveTextColor),
            const SizedBox(width: AppTheme.spacingXs),
          ],
          // Flexible so a long label wraps inside the pill rather than running
          // past its parent. Wrapping keeps the whole label readable, which
          // matters when it is an escalation level.
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize ?? 11,
                fontWeight: fontWeight ?? FontWeight.w600,
                color: effectiveTextColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (isDot) {
      badge = Container(
        padding: padding ?? const EdgeInsets.all(AppTheme.spacingXs),
        decoration: BoxDecoration(
          color: effectiveBackgroundColor,
          borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusFull),
          border: border != null ? Border.fromBorderSide(border!) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: effectiveColor,
                shape: BoxShape.circle,
              ),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: AppTheme.spacingXs),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize ?? 11,
                    fontWeight: fontWeight ?? FontWeight.w600,
                    color: effectiveTextColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (animate) {
      return AppRippleEffect(
        color: effectiveColor.withValues(alpha: 0.3),
        child: badge,
      );
    }

    return badge;
  }
}

class AppAnimatedBadge extends StatefulWidget {
  final String label;
  final Color? color;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double? fontSize;
  final FontWeight? fontWeight;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Duration pulseDuration;
  final double pulseScale;

  const AppAnimatedBadge({
    super.key,
    required this.label,
    this.color,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.fontSize,
    this.fontWeight,
    this.padding,
    this.borderRadius,
    this.pulseDuration = const Duration(milliseconds: 1500),
    this.pulseScale = 1.05,
  });

  @override
  State<AppAnimatedBadge> createState() => _AppAnimatedBadgeState();
}

class _AppAnimatedBadgeState extends State<AppAnimatedBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.pulseDuration,
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pulseScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: AppBadge(
            label: widget.label,
            color: widget.color,
            backgroundColor: widget.backgroundColor,
            textColor: widget.textColor,
            icon: widget.icon,
            fontSize: widget.fontSize,
            fontWeight: widget.fontWeight,
            padding: widget.padding,
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

class AppStatusBadge extends StatelessWidget {
  final String label;
  final AppStatusType type;
  final IconData? icon;
  final bool showDot;
  final bool animate;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.icon,
    this.showDot = true,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    Color backgroundColor;
    IconData defaultIcon;

    switch (type) {
      case AppStatusType.success:
        color = Theme.of(context).colorScheme.primary;
        backgroundColor = Theme.of(context).colorScheme.primaryContainer;
        defaultIcon = Icons.check_circle_rounded;
        break;
      case AppStatusType.warning:
        color = Theme.of(context).colorScheme.tertiary;
        backgroundColor = Theme.of(context).colorScheme.tertiaryContainer;
        defaultIcon = Icons.warning_amber_rounded;
        break;
      case AppStatusType.error:
        color = Theme.of(context).colorScheme.error;
        backgroundColor = Theme.of(context).colorScheme.errorContainer;
        defaultIcon = Icons.error_rounded;
        break;
      case AppStatusType.info:
        color = Theme.of(context).colorScheme.primary;
        backgroundColor = Theme.of(context).colorScheme.primaryContainer;
        defaultIcon = Icons.info_rounded;
        break;
      case AppStatusType.neutral:
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        defaultIcon = Icons.radio_button_unchecked_rounded;
        break;
    }

    return AppBadge(
      label: label,
      color: color,
      backgroundColor: backgroundColor,
      textColor: type == AppStatusType.neutral
          ? Theme.of(context).colorScheme.onSurfaceVariant
          : null,
      icon: icon ?? (showDot ? null : defaultIcon),
      isDot: showDot,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      animate: animate,
    );
  }
}

enum AppStatusType {
  success,
  warning,
  error,
  info,
  neutral,
}

class AppRiskBadge extends StatefulWidget {
  final String riskLevel;
  final bool showIcon;
  final bool isCompact;
  final bool animate;
  final Duration animationDuration;

  const AppRiskBadge({
    super.key,
    required this.riskLevel,
    this.showIcon = true,
    this.isCompact = false,
    this.animate = false,
    this.animationDuration = AppTheme.durationMd,
  });

  @override
  State<AppRiskBadge> createState() => _AppRiskBadgeState();
}

class _AppRiskBadgeState extends State<AppRiskBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.curveSpring),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.curveDecelerate),
    );
    
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
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
    final level = widget.riskLevel.toUpperCase();

    Color color;
    Color containerColor;
    Color onContainerColor;
    IconData icon;
    String label;

    switch (level) {
      case 'RED':
      case 'HIGH':
      case 'URGENT':
      case 'CRITICAL':
        color = theme.colorScheme.error;
        containerColor = theme.colorScheme.errorContainer;
        onContainerColor = theme.colorScheme.onErrorContainer;
        icon = Icons.error_outline_rounded;
        label = 'URGENT';
        break;
      case 'YELLOW':
      case 'AMBER':
      case 'MEDIUM':
      case 'ATTENTION':
      case 'ELEVATED':
        color = theme.colorScheme.tertiary;
        containerColor = theme.colorScheme.tertiaryContainer;
        onContainerColor = theme.colorScheme.onTertiaryContainer;
        icon = Icons.warning_amber_rounded;
        label = 'ATTENTION';
        break;
      case 'GREEN':
      case 'LOW':
      case 'NORMAL':
      case 'SAFE':
        color = theme.colorScheme.primary;
        containerColor = theme.colorScheme.primaryContainer;
        onContainerColor = theme.colorScheme.onPrimaryContainer;
        icon = Icons.check_circle_outline_rounded;
        label = 'NORMAL';
        break;
      default:
        color = theme.colorScheme.onSurfaceVariant;
        containerColor = theme.colorScheme.surfaceContainerHighest;
        onContainerColor = theme.colorScheme.onSurfaceVariant;
        icon = Icons.help_outline_rounded;
        label = 'UNKNOWN';
    }

    Widget badge;
    if (widget.isCompact) {
      badge = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm,
          vertical: AppTheme.spacingXs,
        ),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showIcon) ...[
              Icon(icon, size: 12, color: onContainerColor),
              const SizedBox(width: AppTheme.spacingXs),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: onContainerColor,
              ),
            ),
          ],
        ),
      );
    } else {
      badge = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showIcon) ...[
              Icon(icon, size: 16, color: onContainerColor),
              const SizedBox(width: AppTheme.spacingSm),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onContainerColor,
              ),
            ),
          ],
        ),
      );
    }

    if (!widget.animate) {
      return ScaleTransition(scale: _scaleAnimation, child: badge);
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.isCompact ? AppTheme.radiusFull : AppTheme.radiusLg),
              boxShadow: _glowAnimation.value > 0
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3 * _glowAnimation.value),
                        blurRadius: 16 * _glowAnimation.value,
                        spreadRadius: 2 * _glowAnimation.value,
                      ),
                    ]
                  : null,
            ),
            child: badge,
          ),
        );
      },
    );
  }
}

class AppMetricBadge extends StatefulWidget {
  final String value;
  final String? unit;
  final String? label;
  final Color? color;
  final IconData? icon;
  final bool isLarge;
  final bool animate;
  final Duration animationDuration;

  const AppMetricBadge({
    super.key,
    required this.value,
    this.unit,
    this.label,
    this.color,
    this.icon,
    this.isLarge = false,
    this.animate = false,
    this.animationDuration = AppTheme.durationLg,
  });

  @override
  State<AppMetricBadge> createState() => _AppMetricBadgeState();
}

class _AppMetricBadgeState extends State<AppMetricBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.curveSpring),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.curveDecelerate),
    );
    
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
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
    final effectiveColor = widget.color ?? theme.colorScheme.primary;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: EdgeInsets.all(widget.isLarge ? AppTheme.spacingMd : AppTheme.spacingSm),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: widget.isLarge ? 24 : 18, color: effectiveColor),
                const SizedBox(height: AppTheme.spacingXs),
              ],
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: widget.isLarge ? 28 : 20,
                    fontWeight: FontWeight.w700,
                    color: effectiveColor,
                  ),
                  children: [
                    TextSpan(text: widget.value),
                    if (widget.unit != null)
                      TextSpan(
                        text: widget.unit!,
                        style: TextStyle(
                          fontSize: widget.isLarge ? 16 : 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.label != null) ...[
                const SizedBox(height: AppTheme.spacingXs),
                Text(
                  widget.label!,
                  style: TextStyle(
                    fontSize: widget.isLarge ? 12 : 10,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppPillLabel extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? backgroundColor;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final VoidCallback? onClose;
  final bool isSelected;

  const AppPillLabel({
    super.key,
    required this.label,
    this.color,
    this.backgroundColor,
    this.leadingIcon,
    this.trailingIcon,
    this.onClose,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    final effectiveBackgroundColor = backgroundColor ??
        (isSelected ? effectiveColor : effectiveColor.withValues(alpha: 0.1));
    final effectiveTextColor = isSelected ? Colors.white : effectiveColor;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: !isSelected
            ? Border.all(color: effectiveColor.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 14, color: effectiveTextColor),
            const SizedBox(width: AppTheme.spacingXs),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: effectiveTextColor,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: AppTheme.spacingXs),
            Icon(trailingIcon, size: 14, color: effectiveTextColor),
          ],
          if (onClose != null) ...[
            const SizedBox(width: AppTheme.spacingXs),
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: effectiveTextColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}