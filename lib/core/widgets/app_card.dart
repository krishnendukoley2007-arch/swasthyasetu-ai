import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double? elevation;
  final BorderRadius? borderRadius;
  final BorderSide? border;
  final VoidCallback? onTap;
  final bool isSelected;
  final List<BoxShadow>? shadows;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.elevation,
    this.borderRadius,
    this.border,
    this.onTap,
    this.isSelected = false,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.cardTheme.color ?? theme.colorScheme.surface;
    final cardElevation = elevation ?? theme.cardTheme.elevation ?? AppTheme.elevationLevel1;
    final cardBorderRadius = borderRadius ?? BorderRadius.circular(AppTheme.radiusLg);
    final cardBorder = border ?? BorderSide(
      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
      width: isSelected ? 2 : 1,
    );

    final effectiveShadows = shadows ??
        (cardElevation > 0
            ? [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.08),
                  blurRadius: cardElevation * 2,
                  offset: Offset(0, cardElevation),
                ),
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.04),
                  blurRadius: cardElevation,
                  offset: Offset(0, cardElevation * 0.5),
                ),
              ]
            : null);

    final content = Padding(
      padding: padding ?? const EdgeInsets.all(AppTheme.spacingMd),
      child: child,
    );

    // The card surface is a real Material rather than a coloured Container.
    // ListTile, SwitchListTile and InkWell all paint their background and their
    // ink on the nearest Material ancestor, so a decorated box sitting between
    // them and the card swallowed both — the framework asserts on exactly this.
    // Material also carries the border and the clip, so a tap ripple stops at
    // the rounded corner instead of squaring it off.
    final surface = Material(
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: cardBorderRadius,
        side: cardBorder,
      ),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );

    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      // The shadow is drawn outside the Material so it is not clipped by it.
      // Material's own elevation would add an M3 surface tint on top of the
      // explicit card colour, which is not what the palette specifies.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: cardBorderRadius,
          boxShadow: effectiveShadows,
        ),
        child: surface,
      ),
    );
  }
}

class AppCardHeader extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const AppCardHeader({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppTheme.spacingMd),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  style: Theme.of(context).textTheme.titleLarge!,
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppTheme.spacingXs),
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class AppCardSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool addDivider;

  const AppCardSection({
    super.key,
    required this.child,
    this.padding,
    this.addDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (addDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
            indent: padding?.resolve(Directionality.of(context)).left ?? 0,
            endIndent: padding?.resolve(Directionality.of(context)).right ?? 0,
          ),
        Padding(
          padding: padding ?? const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
          child: child,
        ),
      ],
    );
  }
}

class AppElevatedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;

  const AppElevatedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      margin: margin,
      color: color,
      elevation: AppTheme.elevationLevel2,
      onTap: onTap,
      child: child,
    );
  }
}

class AppOutlinedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AppOutlinedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      margin: margin,
      color: color,
      elevation: 0,
      border: BorderSide(
        color: borderColor ?? Theme.of(context).colorScheme.outlineVariant,
        width: 1.5,
      ),
      onTap: onTap,
      child: child,
    );
  }
}

class AppFilledCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;

  const AppFilledCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      margin: margin,
      color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      elevation: 0,
      border: BorderSide.none,
      onTap: onTap,
      child: child,
    );
  }
}