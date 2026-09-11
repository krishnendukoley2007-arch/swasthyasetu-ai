import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

/// Data model for each step in the clinical screening flow.
class TriageStep {
  final int number;
  final String name;
  final String subtitle;
  final IconData icon;
  final String route;

  const TriageStep({
    required this.number,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}

/// The canonical 5-step clinical screening flow.
const kTriageSteps = <TriageStep>[
  TriageStep(
    number: 1,
    name: 'Patient',
    subtitle: 'Select patient profile',
    icon: Icons.person_rounded,
    route: '/screening/new',
  ),
  TriageStep(
    number: 2,
    name: 'Vitals',
    subtitle: 'Record sensor readings',
    icon: Icons.monitor_heart_rounded,
    route: '/screening/live',
  ),
  TriageStep(
    number: 3,
    name: 'Symptoms',
    subtitle: 'Clinical symptom checklist',
    icon: Icons.sick_rounded,
    route: '/screening/symptoms',
  ),
  TriageStep(
    number: 4,
    name: 'Triage',
    subtitle: 'AI risk assessment',
    icon: Icons.assessment_rounded,
    route: '/screening/triage',
  ),
  TriageStep(
    number: 5,
    name: 'Referral',
    subtitle: 'Doctor slip & ABHA export',
    icon: Icons.local_hospital_rounded,
    route:
        '/screening/triage', // Same route — the referral dialog opens from triage
  ),
];

/// Interactive clinical-flow stepper that replaces static breadcrumbs.
///
/// Each node is tappable for backward navigation (completed steps only),
/// shows animated state transitions, and presents a step-detail bottom
/// sheet when the current step's pill is tapped.
///
/// Designed for the AppBar title or `bottom` slot, taking minimal vertical
/// space while conveying the full 5-step clinical workflow at a glance.
class ScreeningStepIndicator extends StatelessWidget {
  const ScreeningStepIndicator({
    super.key,
    required this.current,
    this.total = 5,
  });

  /// 1-based current step.
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = kTriageSteps.take(total).toList();

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _showStepsOverview(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Current step icon
            Icon(
              steps[current - 1].icon,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            // Current step label — flex-capped so a long step name at a large
            // text scale truncates instead of overflowing the app bar column.
            Flexible(
              child: Text(
                '${steps[current - 1].name}  ($current/$total)',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }

  void _showStepsOverview(BuildContext context) {
    final steps = kTriageSteps.take(total).toList();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomContext) {
        final theme = Theme.of(bottomContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title bar
                Row(
                  children: [
                    Icon(
                      Icons.timeline_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Clinical Screening Flow',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Step $current of $total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Steps list with connecting line
                for (int i = 0; i < steps.length; i++) ...[
                  _StepRow(
                    step: steps[i],
                    currentStep: current,
                    isLast: i == steps.length - 1,
                    onTap: steps[i].number < current
                        ? () {
                            Navigator.of(bottomContext).pop();
                            context.go(steps[i].route);
                          }
                        : null,
                  ),
                ],

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A single step row in the overview bottom sheet.
class _StepRow extends StatelessWidget {
  final TriageStep step;
  final int currentStep;
  final bool isLast;
  final VoidCallback? onTap;

  const _StepRow({
    required this.step,
    required this.currentStep,
    required this.isLast,
    this.onTap,
  });

  bool get _isCompleted => step.number < currentStep;
  bool get _isActive => step.number == currentStep;
  bool get _isUpcoming => step.number > currentStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodeColor = _isCompleted
        ? AppTheme.successGreen
        : _isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final iconColor = _isCompleted || _isActive
        ? Colors.white
        : theme.colorScheme.onSurfaceVariant;
    final lineColor = _isCompleted
        ? AppTheme.successGreen.withValues(alpha: 0.5)
        : theme.colorScheme.outlineVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step node + connecting line
              SizedBox(
                width: 36,
                child: Column(
                  children: [
                    // Circle node
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: nodeColor,
                        shape: BoxShape.circle,
                        border: _isActive
                            ? Border.all(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                                width: 3,
                              )
                            : null,
                        boxShadow: _isActive
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: _isCompleted
                            ? Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: iconColor,
                              )
                            : Icon(step.icon, size: 14, color: iconColor),
                      ),
                    ),
                    // Connecting line
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 28,
                        decoration: BoxDecoration(
                          color: lineColor,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Step label
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            step.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: _isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _isUpcoming
                                  ? theme.colorScheme.onSurfaceVariant
                                  : _isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          if (_isCompleted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.riskGreenContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Done',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppTheme.riskGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                          if (_isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Current',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                          if (_isCompleted && onTap != null) ...[
                            const Spacer(),
                            Icon(
                              Icons.arrow_back_ios_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated step progress bar for AppBar `bottom` slot.
///
/// Shows individual step dots connected by lines rather than a plain
/// LinearProgressIndicator, giving the user a clear sense of where they are
/// in the 5-step flow.
class ScreeningStepBar extends StatelessWidget implements PreferredSizeWidget {
  const ScreeningStepBar({super.key, required this.current, this.total = 5});

  final int current;
  final int total;

  @override
  Size get preferredSize => const Size.fromHeight(32);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = kTriageSteps.take(total).toList();

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            // Step dot
            _buildDot(theme, steps[i], i + 1),
            // Connecting line (except after last)
            if (i < steps.length - 1)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 2.5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i + 1 < current
                        ? AppTheme.successGreen.withValues(alpha: 0.6)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDot(ThemeData theme, TriageStep step, int stepNum) {
    final isCompleted = stepNum < current;
    final isActive = stepNum == current;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 24 : 18,
      height: isActive ? 24 : 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? AppTheme.successGreen
            : isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        border: isActive
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 2.5,
              )
            : null,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
            : isActive
            ? Icon(step.icon, size: 11, color: Colors.white)
            : Text(
                '$stepNum',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
