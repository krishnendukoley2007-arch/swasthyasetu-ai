import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/early_warning_trajectory.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/features/patient_home/state/vulnerability_persona_controller.dart';
import 'package:swasthyasetu_ai/features/screening/state/audio_coach_controller.dart';

/// 7-Day Cumulative Early Warning Trajectory Card.
///
/// Implements rolling multi-day physiological trajectory monitoring across:
/// 1. Cumulative Thermal Debt Index (Heatwave & cardiovascular strain).
/// 2. Trailing Respiratory Curve (48h particulate exposure vs SpO₂ reserve).
/// 3. Post-Flood Epidemic Incubation Timeline (Days 1–14 infection watch).
class EarlyWarningTrajectoryCard extends ConsumerWidget {
  const EarlyWarningTrajectoryCard({super.key});

  Color _severityColor(TrajectorySeverity s) => switch (s) {
    TrajectorySeverity.normal => ClinicalPalette.teal,
    TrajectorySeverity.watchful => ClinicalPalette.cyan,
    TrajectorySeverity.warning => ClinicalPalette.amber,
    TrajectorySeverity.critical => ClinicalPalette.coral,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assessment = ref.watch(earlyWarningTrajectoryProvider);
    final statusColor = _severityColor(assessment.severity);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.show_chart_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '7-Day Early Warning Radar',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Cumulative Multi-Day Trajectory',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        assessment.severity.label.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Listen to Trajectory Voice Summary',
                icon: const Icon(Icons.volume_up_rounded, size: 20),
                onPressed: () {
                  final sample = HealthSample(
                    timestamp: DateTime.now().millisecondsSinceEpoch,
                    heartRateBpm:
                        72 + assessment.thermalDebt.restingHrDriftBpm.toInt(),
                    spo2Percent: (98 - assessment.respiratoryCurve.spo2Drop)
                        .clamp(70.0, 100.0)
                        .toInt(),
                    temperatureC: 36.6,
                    estimatedGlucose: 100,
                    estimatedSystolic: 120,
                    estimatedDiastolic: 80,
                    ecgSignalQuality: 0.9,
                    rPeakDetected: true,
                    rrIntervalMs: 800,
                    batteryPercent: 90,
                  );
                  ref
                      .read(audioCoachControllerProvider.notifier)
                      .speakWhatIsMySituation(
                        band: assessment.severity == TrajectorySeverity.critical
                            ? RiskBand.red
                            : (assessment.severity == TrajectorySeverity.warning
                                  ? RiskBand.yellow
                                  : RiskBand.green),
                        sample: sample,
                        trajectorySummary: assessment.actionableEarlyWarning,
                      );
                },
              ),
            ],
          ),
          const AppSpacing.vmd(),

          // ── Actionable Early Warning Alert Banner (if elevated) ──
          if (assessment.hasActiveEarlyWarning) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                  const AppSpacing.hsm(),
                  Expanded(
                    child: Text(
                      assessment.actionableEarlyWarning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const AppSpacing.vmd(),
          ],

          // ── 1. Thermal Debt Trajectory ──
          _TrajectoryMetricRow(
            title: 'Cumulative Thermal Debt Index',
            score: assessment.thermalDebt.debtScore,
            valueReadout:
                '${assessment.thermalDebt.debtScore.toStringAsFixed(0)}/100 · Drift: +${assessment.thermalDebt.restingHrDriftBpm.toStringAsFixed(1)} bpm',
            subtitle: assessment.thermalDebt.advisoryNote,
            color: assessment.thermalDebt.impendingHeatCollapse
                ? ClinicalPalette.coral
                : (assessment.thermalDebt.debtScore >= 40
                      ? ClinicalPalette.amber
                      : ClinicalPalette.teal),
          ),
          const AppSpacing.vmd(),

          // ── 2. Respiratory Inflammatory Curve ──
          _TrajectoryMetricRow(
            title: 'Trailing Respiratory Curve',
            score: assessment.respiratoryCurve.inflammatoryIndex,
            valueReadout:
                '${assessment.respiratoryCurve.inflammatoryIndex.toStringAsFixed(0)}/100 · PM2.5: ${assessment.respiratoryCurve.trailingPm25.toStringAsFixed(0)} µg/m³',
            subtitle: assessment.respiratoryCurve.advisoryNote,
            color: assessment.respiratoryCurve.preBronchospasm
                ? ClinicalPalette.coral
                : (assessment.respiratoryCurve.inflammatoryIndex >= 40
                      ? ClinicalPalette.amber
                      : ClinicalPalette.cyan),
          ),
          const AppSpacing.vmd(),

          // ── 3. Post-Flood Epidemic Incubation Watch ──
          _EpidemicIncubationSection(incubation: assessment.epidemicIncubation),
          const AppSpacing.vmd(),

          // ── Deterministic Rationale & Medical Disclaimer ──
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deterministic Trajectory Rationale:',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  assessment.clinicalRationale,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const AppSpacing.vsm(),
          Text(
            'Screening & physiological trajectory advisor only. Does not replace clinical diagnosis. If dizzy or experiencing chest pain, call 108 immediately.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrajectoryMetricRow extends StatelessWidget {
  final String title;
  final double score;
  final String valueReadout;
  final String subtitle;
  final Color color;

  const _TrajectoryMetricRow({
    required this.title,
    required this.score,
    required this.valueReadout,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (score / 100.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              valueReadout,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _EpidemicIncubationSection extends StatelessWidget {
  final PostDisasterIncubationTrajectory incubation;

  const _EpidemicIncubationSection({required this.incubation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = incubation.isVigilanceActive;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? ClinicalPalette.amber.withValues(alpha: 0.4)
              : theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.water_damage_rounded,
                size: 18,
                color: isActive ? ClinicalPalette.amber : ClinicalPalette.teal,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post-Flood Incubation Watch (Days 1–14)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isActive
                                    ? ClinicalPalette.amber
                                    : ClinicalPalette.teal)
                                .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? 'Watch Active' : 'Low Risk',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? ClinicalPalette.amber
                              : ClinicalPalette.teal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            incubation.advisoryNote,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          if (incubation.symptomChecklist.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Active Incubation Checklist:',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final item in incubation.symptomChecklist)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
