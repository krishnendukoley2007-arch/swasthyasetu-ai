import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';

/// Selection dialog for choosing between screening styles and clinical simulator.
class ScreeningModeDialog extends StatelessWidget {
  const ScreeningModeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ScreeningModeDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.monitor_heart_rounded, color: theme.colorScheme.primary),
          const AppSpacing.hsm(),
          const Text('Select Screening Mode'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose how you want to capture and evaluate patient vitals:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const AppSpacing.vmd(),

            // Option 1: Continuous All-in-One Live Monitor
            _buildModeCard(
              context,
              title: 'Continuous All-in-One Monitor',
              subtitle:
                  'Live streaming of SpO₂, ECG, Temp, BP & Glucose on a unified hospital monitor.',
              badge: 'RECOMMENDED',
              badgeColor: theme.colorScheme.primary,
              icon: Icons.speed_rounded,
              onTap: () {
                Navigator.of(context).pop();
                context.push('/screening/live');
              },
            ),

            const AppSpacing.vsm(),

            // Option 2: Step-by-Step Sequential Guided Mode
            _buildModeCard(
              context,
              title: 'Step-by-Step Guided Mode',
              subtitle:
                  'Mutually exclusive tabs: isolate SpO₂, then Lead-I ECG strip, then Skin Temp.',
              badge: 'FIELD WORKER',
              badgeColor: theme.colorScheme.secondary,
              icon: Icons.checklist_rounded,
              onTap: () {
                Navigator.of(context).pop();
                context.push('/screening/sequential');
              },
            ),

            const AppSpacing.vsm(),

            // Option 3: Virtual Patient Clinical Simulator
            _buildModeCard(
              context,
              title: 'Virtual Patient Clinical Simulator',
              subtitle:
                  'Test 6 realistic medical conditions (Pneumonia, DKA, Hypoglycemia, Arrhythmia, Heat Stroke) with zero hardware.',
              badge: 'ZERO HARDWARE',
              badgeColor: theme.colorScheme.tertiary,
              icon: Icons.science_rounded,
              onTap: () {
                Navigator.of(context).pop();
                // Opens live screen with the scenario bottom sheet automatically available
                context.push('/screening/live');
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          color: theme.colorScheme.surface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: badgeColor, size: 22),
            ),
            const AppSpacing.hmd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
