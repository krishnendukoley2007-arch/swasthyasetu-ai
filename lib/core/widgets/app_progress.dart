export 'app_animations.dart' show AppProgressRing, AppSkeleton, AppSkeletonList, AppNumberTicker;

import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/app_button.dart';

class AppProgressIndicator extends StatelessWidget {
  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final double strokeWidth;
  final double radius;
  final StrokeCap strokeCap;

  const AppProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.strokeWidth = 4,
    this.radius = 20,
    this.strokeCap = StrokeCap.round,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: strokeWidth,
        strokeCap: strokeCap,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? theme.colorScheme.primary,
        ),
        backgroundColor: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class AppLinearProgress extends StatelessWidget {
  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final double height;
  final BorderRadius? borderRadius;
  final bool showValue;
  final String? valueLabel;

  const AppLinearProgress({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.height = 8,
    this.borderRadius,
    this.showValue = false,
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveValue = value ?? 0;
    final effectiveColor = color ?? theme.colorScheme.primary;
    final effectiveBackgroundColor = backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(AppTheme.radiusFull);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showValue || valueLabel != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (valueLabel != null)
                Text(
                  valueLabel!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (showValue)
                Text(
                  '${(effectiveValue * 100).round()}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: effectiveColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXs),
        ],
        Container(
          height: height,
          decoration: BoxDecoration(
            color: effectiveBackgroundColor,
            borderRadius: effectiveBorderRadius,
          ),
          child: ClipRRect(
            borderRadius: effectiveBorderRadius,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: effectiveValue.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: effectiveColor,
                  borderRadius: effectiveBorderRadius,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AppStepProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? stepLabels;
  final Color? activeColor;
  final Color? inactiveColor;
  final double lineHeight;
  final double circleSize;

  const AppStepProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabels,
    this.activeColor,
    this.inactiveColor,
    this.lineHeight = 2,
    this.circleSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveActiveColor = activeColor ?? theme.colorScheme.primary;
    final effectiveInactiveColor = inactiveColor ?? theme.colorScheme.outlineVariant;

    return Column(
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        final isLast = index == totalSteps - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    color: isActive ? effectiveActiveColor : theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? effectiveActiveColor : effectiveInactiveColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isActive
                        ? Icon(
                            index == currentStep
                                ? Icons.radio_button_checked
                                : Icons.check_rounded,
                            size: circleSize * 0.6,
                            color: isActive
                                ? theme.colorScheme.onPrimary
                                : effectiveActiveColor,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: circleSize * 0.4,
                              fontWeight: FontWeight.w600,
                              color: effectiveInactiveColor,
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: lineHeight,
                    height: 40,
                    color: index < currentStep
                        ? effectiveActiveColor
                        : effectiveInactiveColor,
                  ),
              ],
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stepLabels != null && index < stepLabels!.length)
                      Text(
                        stepLabels![index],
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (index == currentStep && stepLabels != null)
                      Text(
                        'Current step',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: effectiveActiveColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class AppSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool isCircle;
  final Color? baseColor;
  final Color? highlightColor;

  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.isCircle = false,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBaseColor = baseColor ?? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final effectiveHighlightColor = highlightColor ?? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);

    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [effectiveBaseColor, effectiveHighlightColor, effectiveBaseColor],
          stops: const [0.1, 0.5, 0.9],
          begin: const Alignment(-1.0, -0.3),
          end: const Alignment(1.0, 0.3),
          tileMode: TileMode.clamp,
        ).createShader(bounds);
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: effectiveBaseColor,
          borderRadius: isCircle
              ? BorderRadius.circular(AppTheme.radiusFull)
              : (borderRadius ?? BorderRadius.circular(AppTheme.radiusMd)),
        ),
      ),
    );
  }
}

class AppSkeletonList extends StatelessWidget {
  final int itemCount;
  final Widget Function(int index) itemBuilder;
  final EdgeInsetsGeometry? padding;

  const AppSkeletonList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) => itemBuilder(index),
    );
  }
}

class AppLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? backgroundColor;

  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: backgroundColor ?? theme.colorScheme.surface.withValues(alpha: 0.8),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      message!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.spacingLg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String message;
  final String? title;
  final VoidCallback? onRetry;
  final IconData icon;
  final EdgeInsetsGeometry? padding;

  const AppErrorState({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingSm),
            ],
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spacingLg),
              AppButton(
                label: 'Try Again',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                isExpanded: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}