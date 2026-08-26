import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

class AppPageScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  const AppPageScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
  }
}

class AppScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool physics;
  final ScrollController? controller;

  const AppScrollView({
    super.key,
    required this.child,
    this.padding,
    this.physics = true,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      physics: physics ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
      padding: padding,
      child: child,
    );
  }
}

class AppListView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final double? itemExtent;

  const AppListView({
    super.key,
    required this.children,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.itemExtent,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      scrollDirection: scrollDirection,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      addSemanticIndexes: addSemanticIndexes,
      itemExtent: itemExtent,
      children: children,
    );
  }
}

class AppGridView extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Axis scrollDirection;

  const AppGridView({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = AppTheme.spacingMd,
    this.crossAxisSpacing = AppTheme.spacingMd,
    this.childAspectRatio = 1.0,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: padding,
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
      shrinkWrap: shrinkWrap,
      physics: physics,
      scrollDirection: scrollDirection,
      children: children,
    );
  }
}

class AppSliverGrid extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;

  const AppSliverGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = AppTheme.spacingMd,
    this.crossAxisSpacing = AppTheme.spacingMd,
    this.childAspectRatio = 1.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding ?? EdgeInsets.zero,
      sliver: SliverGrid(
        delegate: SliverChildListDelegate(children),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          childAspectRatio: childAspectRatio,
        ),
      ),
    );
  }
}

class AppResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final double tabletBreakpoint;
  final double desktopBreakpoint;

  const AppResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.tabletBreakpoint = 600,
    this.desktopBreakpoint = 900,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= desktopBreakpoint && desktop != null) {
          return desktop!;
        }
        if (constraints.maxWidth >= tabletBreakpoint && tablet != null) {
          return tablet!;
        }
        return mobile;
      },
    );
  }
}

class AppResponsiveValue<T> extends StatelessWidget {
  final T mobile;
  final T? tablet;
  final T? desktop;
  final double tabletBreakpoint;
  final double desktopBreakpoint;
  final Widget Function(T value) builder;

  const AppResponsiveValue({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.tabletBreakpoint = 600,
    this.desktopBreakpoint = 900,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        T value;
        if (constraints.maxWidth >= desktopBreakpoint && desktop != null) {
          value = desktop as T;
        } else if (constraints.maxWidth >= tabletBreakpoint && tablet != null) {
          value = tablet as T;
        } else {
          value = mobile;
        }
        return builder(value);
      },
    );
  }
}

class AppSpacing extends StatelessWidget {
  final double? vertical;
  final double? horizontal;

  const AppSpacing({super.key, this.vertical, this.horizontal});

  const AppSpacing.xs({super.key}) : vertical = AppTheme.spacingXs, horizontal = AppTheme.spacingXs;
  const AppSpacing.sm({super.key}) : vertical = AppTheme.spacingSm, horizontal = AppTheme.spacingSm;
  const AppSpacing.md({super.key}) : vertical = AppTheme.spacingMd, horizontal = AppTheme.spacingMd;
  const AppSpacing.lg({super.key}) : vertical = AppTheme.spacingLg, horizontal = AppTheme.spacingLg;
  const AppSpacing.xl({super.key}) : vertical = AppTheme.spacingXl, horizontal = AppTheme.spacingXl;
  const AppSpacing.xxl({super.key}) : vertical = AppTheme.spacingXxl, horizontal = AppTheme.spacingXxl;

  const AppSpacing.vxs({super.key}) : vertical = AppTheme.spacingXs, horizontal = null;
  const AppSpacing.vsm({super.key}) : vertical = AppTheme.spacingSm, horizontal = null;
  const AppSpacing.vmd({super.key}) : vertical = AppTheme.spacingMd, horizontal = null;
  const AppSpacing.vlg({super.key}) : vertical = AppTheme.spacingLg, horizontal = null;
  const AppSpacing.vxl({super.key}) : vertical = AppTheme.spacingXl, horizontal = null;
  const AppSpacing.vxxl({super.key}) : vertical = AppTheme.spacingXxl, horizontal = null;

  const AppSpacing.hxs({super.key}) : vertical = null, horizontal = AppTheme.spacingXs;
  const AppSpacing.hsm({super.key}) : vertical = null, horizontal = AppTheme.spacingSm;
  const AppSpacing.hmd({super.key}) : vertical = null, horizontal = AppTheme.spacingMd;
  const AppSpacing.hlg({super.key}) : vertical = null, horizontal = AppTheme.spacingLg;
  const AppSpacing.hxl({super.key}) : vertical = null, horizontal = AppTheme.spacingXl;
  const AppSpacing.hxxl({super.key}) : vertical = null, horizontal = AppTheme.spacingXxl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: horizontal,
      height: vertical,
    );
  }
}

class AppDivider extends StatelessWidget {
  final double? height;
  final double? thickness;
  final Color? color;
  final double? indent;
  final double? endIndent;

  const AppDivider({
    super.key,
    this.height,
    this.thickness,
    this.color,
    this.indent,
    this.endIndent,
  });

  const AppDivider.vertical({
    super.key,
    this.height,
    this.thickness,
    this.color,
    this.indent,
    this.endIndent,
  }) : assert(false, 'Use VerticalDivider for vertical dividers');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Divider(
      height: height ?? 1,
      thickness: thickness ?? 1,
      color: color ?? theme.colorScheme.outlineVariant,
      indent: indent ?? AppTheme.spacingMd,
      endIndent: endIndent ?? AppTheme.spacingMd,
    );
  }
}

class AppVerticalDivider extends StatelessWidget {
  final double? width;
  final double? thickness;
  final Color? color;
  final double? indent;
  final double? endIndent;

  const AppVerticalDivider({
    super.key,
    this.width,
    this.thickness,
    this.color,
    this.indent,
    this.endIndent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VerticalDivider(
      width: width ?? 1,
      thickness: thickness ?? 1,
      color: color ?? theme.colorScheme.outlineVariant,
      indent: indent ?? AppTheme.spacingSm,
      endIndent: endIndent ?? AppTheme.spacingSm,
    );
  }
}

/// Centres [child] when there is room and scrolls it when there is not.
///
/// The plain `Center(child: Column(...))` used by every loading and empty state
/// overflows the bottom of the screen as soon as the system font is scaled up —
/// a `Center` has no way to give ground. This keeps the centred look at normal
/// text sizes and degrades to a scroll instead of clipping content off-screen.
class AppCenteredScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppCenteredScrollView({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spacingLg),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final insets = padding.resolve(
          Directionality.maybeOf(context) ?? TextDirection.ltr,
        );
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            // minHeight is what does the centring: the column is given the full
            // viewport to centre within, and only exceeds it — and so scrolls —
            // when its content genuinely does not fit. The padding comes off
            // first, or the view would always be a few pixels scrollable.
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? (constraints.maxHeight - insets.vertical).clamp(0.0, double.infinity)
                  : 0,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class AppContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Decoration? decoration;
  final Decoration? foregroundDecoration;
  final AlignmentGeometry? alignment;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final Clip clipBehavior;

  const AppContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    this.alignment,
    this.width,
    this.height,
    this.constraints,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      color: color,
      decoration: decoration,
      foregroundDecoration: foregroundDecoration,
      alignment: alignment,
      width: width,
      height: height,
      constraints: constraints,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

class AppSafeArea extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  final EdgeInsets? minimum;

  const AppSafeArea({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
    this.minimum,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      minimum: minimum ?? EdgeInsets.zero,
      child: child,
    );
  }
}

class AppAspectRatio extends StatelessWidget {
  final Widget child;
  final double aspectRatio;

  const AppAspectRatio({
    super.key,
    required this.child,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: child,
    );
  }
}

class AppLimitedBox extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double maxHeight;

  const AppLimitedBox({
    super.key,
    required this.child,
    this.maxWidth = double.infinity,
    this.maxHeight = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return LimitedBox(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      child: child,
    );
  }
}

class AppConstrainedBox extends StatelessWidget {
  final Widget child;
  final BoxConstraints constraints;

  const AppConstrainedBox({
    super.key,
    required this.child,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: constraints,
      child: child,
    );
  }
}