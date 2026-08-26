import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final double elevation;
  final PreferredSizeWidget? bottom;
  final bool showBackButton;

  const AppTopBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
    this.elevation = 0,
    this.bottom,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor = backgroundColor ?? theme.colorScheme.surface;

    return AppBar(
      title: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
      centerTitle: centerTitle,
      leading: leading ?? (showBackButton ? _buildBackButton(context) : null),
      automaticallyImplyLeading: showBackButton && leading == null,
      actions: actions,
      backgroundColor: effectiveBackgroundColor,
      foregroundColor: theme.colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: elevation,
      scrolledUnderElevation: AppTheme.elevationLevel1,
      toolbarHeight: 64,
      bottom: bottom,
      shape: Border(
        bottom: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
    );
  }

  Widget? _buildBackButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(64 + (bottom?.preferredSize.height ?? 0));
}

class AppSliverAppBar extends StatelessWidget {
  final String title;
  final Widget? flexibleSpace;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final double expandedHeight;
  final bool pinned;
  final bool floating;
  final bool snap;

  const AppSliverAppBar({
    super.key,
    required this.title,
    this.flexibleSpace,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
    this.expandedHeight = 200,
    this.pinned = true,
    this.floating = false,
    this.snap = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverAppBar(
      title: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      expandedHeight: expandedHeight,
      pinned: pinned,
      floating: floating,
      snap: snap,
      flexibleSpace: flexibleSpace != null
          ? FlexibleSpaceBar(
              background: flexibleSpace!,
              titlePadding: const EdgeInsets.only(left: AppTheme.spacingMd, right: AppTheme.spacingMd, bottom: AppTheme.spacingMd),
            )
          : null,
      shape: Border(
        bottom: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
    );
  }
}

class AppSearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final List<Widget>? actions;
  final Widget? leading;
  final Color? backgroundColor;

  const AppSearchAppBar({
    super.key,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.actions,
    this.leading,
    this.backgroundColor,
  });

  @override
  State<AppSearchAppBar> createState() => _AppSearchAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(64);
}

class _AppSearchAppBarState extends State<AppSearchAppBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      title: Container(
        height: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () {
                      _controller.clear();
                      widget.onClear?.call();
                      widget.onChanged?.call('');
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingXs),
          ),
          onChanged: (value) {
            setState(() {});
            widget.onChanged?.call(value);
          },
          style: theme.textTheme.bodyLarge,
        ),
      ),
      leading: widget.leading,
      actions: widget.actions,
      backgroundColor: widget.backgroundColor ?? theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: AppTheme.elevationLevel1,
      toolbarHeight: 64,
      shape: Border(
        bottom: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
    );
  }
}

class AppTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> tabs;
  final TabController controller;
  final Color? indicatorColor;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final TabBarIndicatorSize indicatorSize;
  final EdgeInsetsGeometry? padding;

  const AppTabBar({
    super.key,
    required this.tabs,
    required this.controller,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
    this.indicatorSize = TabBarIndicatorSize.label,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TabBar(
      controller: controller,
      tabs: tabs,
      indicatorColor: indicatorColor ?? theme.colorScheme.primary,
      indicatorSize: indicatorSize,
      labelColor: labelColor ?? theme.colorScheme.primary,
      unselectedLabelColor: unselectedLabelColor ?? theme.colorScheme.onSurfaceVariant,
      labelStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
      dividerColor: Colors.transparent,
      padding: padding,
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return theme.colorScheme.primary.withValues(alpha: 0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return theme.colorScheme.primary.withValues(alpha: 0.05);
        }
        return null;
      }),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}

class AppTabBarView extends StatelessWidget {
  final TabController controller;
  final List<Widget> children;
  final ScrollPhysics? physics;

  const AppTabBarView({
    super.key,
    required this.controller,
    required this.children,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: controller,
      physics: physics,
      children: children,
    );
  }
}