import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

/// Icon + label row shared by every button variant.
///
/// The label is [Flexible] so it wraps instead of running off the screen edge —
/// the failure mode all three button classes had at large system font sizes.
/// Wrapping rather than ellipsising is deliberate: a taller button is fine,
/// whereas truncating "Start Screening" to "Start Scre…" on a triage flow is not.
Widget _buttonContent({
  required String label,
  Widget? icon,
  Widget? trailingIcon,
  required bool isExpanded,
}) {
  return Row(
    mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (icon != null) ...[
        icon,
        const SizedBox(width: AppTheme.spacingSm),
      ],
      Flexible(child: Text(label, textAlign: TextAlign.center)),
      if (trailingIcon != null) ...[
        const SizedBox(width: AppTheme.spacingSm),
        trailingIcon,
      ],
    ],
  );
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget? trailingIcon;
  final bool isLoading;
  final bool isExpanded;
  final ButtonStyle? style;
  final double? minWidth;
  final double minHeight;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = true,
    this.style,
    this.minWidth,
    this.minHeight = 56,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = style ??
        ElevatedButton.styleFrom(
          minimumSize: Size(minWidth ?? (isExpanded ? double.infinity : 140), minHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingXl,
            vertical: AppTheme.spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          elevation: 2,
        );

    return SizedBox(
      width: isExpanded ? double.infinity : null,
      child: ElevatedButton(
        style: buttonStyle,
        onPressed: isLoading || onPressed == null ? null : onPressed,
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    buttonStyle.foregroundColor?.resolve({}) ?? Colors.white,
                  ),
                ),
              )
            : _buttonContent(
                label: label,
                icon: icon,
                trailingIcon: trailingIcon,
                isExpanded: isExpanded,
              ),
      ),
    );
  }
}

class AppOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget? trailingIcon;
  final bool isLoading;
  final bool isExpanded;
  final Color? borderColor;
  final Color? foregroundColor;
  final ButtonStyle? style;
  final double? minWidth;
  final double minHeight;

  const AppOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = true,
    this.borderColor,
    this.foregroundColor,
    this.style,
    this.minWidth,
    this.minHeight = 56,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBorderColor = borderColor ?? theme.colorScheme.primary;
    final effectiveForegroundColor = foregroundColor ?? theme.colorScheme.primary;

    final buttonStyle = style ??
        OutlinedButton.styleFrom(
          foregroundColor: effectiveForegroundColor,
          minimumSize: Size(minWidth ?? (isExpanded ? double.infinity : 140), minHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingXl,
            vertical: AppTheme.spacingMd,
          ),
          side: BorderSide(color: effectiveBorderColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        );

    return SizedBox(
      width: isExpanded ? double.infinity : null,
      child: OutlinedButton(
        style: buttonStyle,
        onPressed: isLoading || onPressed == null ? null : onPressed,
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(effectiveForegroundColor),
                ),
              )
            : _buttonContent(
                label: label,
                icon: icon,
                trailingIcon: trailingIcon,
                isExpanded: isExpanded,
              ),
      ),
    );
  }
}

class AppTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isExpanded;
  final double minHeight;

  const AppTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isExpanded = false,
    this.minHeight = 48,
  });

  @override
  Widget build(BuildContext context) {

    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: isExpanded ? Size(double.infinity, minHeight) : Size(80, minHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLg,
          vertical: AppTheme.spacingSm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      onPressed: onPressed,
      child: _buttonContent(
        label: label,
        icon: icon,
        isExpanded: isExpanded,
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 48,
    this.color,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final button = Material(
      color: backgroundColor ?? Colors.transparent,
      borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusFull),
      child: InkWell(
        onTap: onPressed,
        borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusFull),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: IconTheme(
              data: IconThemeData(
                color: color ?? theme.colorScheme.onSurface,
                size: size * 0.5,
              ),
              child: icon,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class AppFloatingActionButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isExtended;
  final String? extendedLabel;
  final Widget? extendedIcon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppFloatingActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.isExtended = false,
    this.extendedLabel,
    this.extendedIcon,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isExtended) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: extendedIcon ?? icon,
        label: Text(extendedLabel ?? ''),
        backgroundColor: backgroundColor ?? theme.colorScheme.primary,
        foregroundColor: foregroundColor ?? theme.colorScheme.onPrimary,
        elevation: AppTheme.elevationLevel3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: backgroundColor ?? theme.colorScheme.primary,
      foregroundColor: foregroundColor ?? theme.colorScheme.onPrimary,
      elevation: AppTheme.elevationLevel3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: icon,
    );
  }
}

class AppSegmentedButton<T> extends StatelessWidget {
  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;

  const AppSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: segments,
      selected: selected,
      onSelectionChanged: onSelectionChanged,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return Theme.of(context).colorScheme.primaryContainer;
          }
          return Theme.of(context).colorScheme.surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return Theme.of(context).colorScheme.onPrimaryContainer;
          }
          return Theme.of(context).colorScheme.onSurface;
        }),
        side: WidgetStateProperty.resolveWith<BorderSide>((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5);
          }
          return BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1);
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
        ),
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }
}