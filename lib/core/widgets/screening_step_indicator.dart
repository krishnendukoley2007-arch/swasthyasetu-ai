import 'package:flutter/material.dart';

/// The small "Step 2 of 4" chip shown in screening-flow app bars.
///
/// The four screening screens (live vitals, ECG, symptoms, result) live at
/// separate routes, so nothing else tells the worker where they are in the
/// flow or that coming back here is normal. A shared chip keeps the label
/// style identical everywhere and makes the count impossible to drift
/// between screens.
class ScreeningStepIndicator extends StatelessWidget {
  const ScreeningStepIndicator({
    super.key,
    required this.current,
    this.total = 4,
  });

  /// 1-based step number within the screening flow.
  final int current;

  /// Total steps in the flow. Kept a parameter rather than hardcoded so a
  /// future fifth screen (e.g. report/share) does not need its own widget.
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Step $current of $total',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Compact progress bar for the AppBar's `bottom` slot: fills left-to-right
/// as the flow advances. Lives under the toolbar rather than beside the
/// title because a fixed-width sliver next to the chip overflows when the
/// user has text scaling turned up.
class ScreeningStepBar extends StatelessWidget implements PreferredSizeWidget {
  const ScreeningStepBar({
    super.key,
    required this.current,
    this.total = 4,
  });

  final int current;
  final int total;

  @override
  Size get preferredSize => const Size.fromHeight(6);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 6,
      child: LinearProgressIndicator(
        value: total == 0 ? 0 : current / total,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
      ),
    );
  }
}
