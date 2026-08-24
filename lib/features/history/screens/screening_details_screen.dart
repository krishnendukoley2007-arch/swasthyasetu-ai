import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/screening.dart';

/// Resolves the stored screening, then hands a non-null record to the view.
///
/// Splitting the load out means the view never has to reason about a
/// half-loaded record, and a deleted screening produces a clear message instead
/// of a crash.
class ScreeningDetailsScreen extends ConsumerWidget {
  final String screeningId;

  const ScreeningDetailsScreen({super.key, required this.screeningId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screeningAsync = ref.watch(screeningProvider(screeningId));

    return screeningAsync.when(
      loading: () => const AppPageScaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => AppPageScaffold(
        appBar: AppBar(
          title: const Text('Screening'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () => context.go('/history'),
          ),
        ),
        body: const AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load this screening',
          subtitle: 'The local database did not respond.',
        ),
      ),
      data: (screening) {
        if (screening == null) {
          return AppPageScaffold(
            appBar: AppBar(
              title: const Text('Screening'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
                onPressed: () => context.go('/history'),
              ),
            ),
            body: AppEmptyState(
              icon: Icons.find_in_page_outlined,
              title: 'Screening not found',
              subtitle: 'This record may have been deleted from this device.',
              action: AppOutlinedButton(
                label: 'Back to history',
                isExpanded: false,
                onPressed: () => context.go('/history'),
              ),
            ),
          );
        }

        final patientName =
            ref.watch(patientNamesProvider)[screening.patientId];
        return _ScreeningDetailsView(
          screening: screening,
          patientName: patientName,
        );
      },
    );
  }
}

class _ScreeningDetailsView extends StatefulWidget {
  final Screening screening;
  final String? patientName;

  const _ScreeningDetailsView({required this.screening, this.patientName});

  @override
  State<_ScreeningDetailsView> createState() => _ScreeningDetailsViewState();
}

class _ScreeningDetailsViewState extends State<_ScreeningDetailsView> {
  Screening get _screening => widget.screening;

  @override
  Widget build(BuildContext context) {
    final riskColor = AppTheme.getRiskColor(context, _screening.riskLevel);
    final riskIcon = AppTheme.getRiskIcon(_screening.riskLevel);

    return AppPageScaffold(
      appBar: AppBar(
        title: Text(widget.patientName ?? 'Screening'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/history'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareScreening,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(riskColor, riskIcon).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),
            const AppSpacing.vmd(),
            _buildVitalsCard().animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.1),
            const AppSpacing.vmd(),
            _buildECGAndBPCard().animate().fadeIn(duration: 300.ms, delay: 200.ms).slideY(begin: 0.1),
            const AppSpacing.vmd(),
            _buildSymptomsCard().animate().fadeIn(duration: 300.ms, delay: 300.ms).slideY(begin: 0.1),
            const AppSpacing.vmd(),
            _buildRiskAnalysisCard(riskColor).animate().fadeIn(duration: 300.ms, delay: 400.ms).slideY(begin: 0.1),
            const AppSpacing.vmd(),
            if (_screening.aiSummary != null) _buildAICard().animate().fadeIn(duration: 300.ms, delay: 500.ms).slideY(begin: 0.1),
            const AppSpacing.vmd(),
            _buildMetadataCard().animate().fadeIn(duration: 300.ms, delay: 600.ms).slideY(begin: 0.1),
            const AppSpacing.vxl(),
            _buildActionButtons().animate().fadeIn(duration: 300.ms, delay: 700.ms).slideY(begin: 0.1),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Color riskColor, IconData riskIcon) {
    final theme = Theme.of(context);
    final risk = RiskStyle.ofStorage(_screening.riskLevel, context.l10n);

    return AppCard(
      color: riskColor.withValues(alpha: 0.05),
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      border: BorderSide(color: riskColor.withValues(alpha: 0.3), width: 2),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(riskIcon, size: 30, color: riskColor),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // Humanised band, never the stored 'RED'.
                      risk.label,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                    Text(
                      'Risk Score: ${_screening.riskScore}/100',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const AppSpacing.hsm(),
              // Flexible so the timestamp gives ground at large text scales
              // rather than shoving the whole row past the card edge.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatDate(_screening.timestamp),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      textAlign: TextAlign.end,
                    ),
                    Text(
                      _formatTime(_screening.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _screening.recommendedAction,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: riskColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          if (_screening.isDemo) ...[
            const AppSpacing.vsm(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingXs),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Text(
                'DEMO MODE - Simulated Data',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVitalsCard() {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vital Signs',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const AppSpacing.vlg(),
          Row(
            children: [
              Expanded(child: _buildDetailVital('Heart Rate', '${_screening.heartRate}', 'BPM', Icons.favorite_rounded, theme.colorScheme.primary, _screening.heartRate > 100)),
              const AppSpacing.hmd(),
              Expanded(child: _buildDetailVital('SpO₂', '${_screening.spo2}', '%', Icons.air_rounded, theme.colorScheme.secondary, _screening.spo2 < 95)),
              const AppSpacing.hmd(),
              Expanded(child: _buildDetailVital('Temperature', _screening.temperature.toStringAsFixed(1), '°C', Icons.thermostat_rounded, theme.colorScheme.tertiary, _screening.temperature >= 38)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailVital(String label, String value, String unit, IconData icon, Color color, bool isAlert) {
    final theme = Theme.of(context);
    final displayColor = isAlert ? theme.colorScheme.error : color;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const AppSpacing.vmd(),
        RichText(
          text: TextSpan(
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: displayColor,
            ),
            children: [
              TextSpan(text: value),
              TextSpan(
                text: ' $unit',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (isAlert) ...[
          const AppSpacing.vxs(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              'ABNORMAL',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildECGAndBPCard() {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ECG & Experimental BP',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const AppSpacing.vlg(),
          Row(
            children: [
              Expanded(child: _buildInfoItem('ECG quality', _screening.ecgQualityLabel, Icons.monitor_heart_rounded, theme.colorScheme.primary)),
              Expanded(child: _buildInfoItem('Rhythm', ecgRhythmLabel(_screening.ecgRhythm, context.l10n), Icons.timeline_rounded, theme.colorScheme.primary)),
            ],
          ),
          if (_screening.pttMs > 0) ...[
            const AppSpacing.vlg(),
            AppCard(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.2),
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              border: BorderSide(color: theme.colorScheme.tertiary.withValues(alpha: 0.3), width: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: theme.colorScheme.tertiary, size: 18),
                      const AppSpacing.hsm(),
                      Expanded(
                        child: Text(
                            'Experimental BP Estimation',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                      ),
                    ],
                  ),
                  const AppSpacing.vmd(),
                  Row(
                    children: [
                      Expanded(child: _buildBPDetail('Systolic', '${_screening.estimatedSystolic} mmHg', theme.colorScheme.error)),
                      Expanded(child: _buildBPDetail('Diastolic', '${_screening.estimatedDiastolic} mmHg', theme.colorScheme.secondary)),
                      Expanded(child: _buildBPDetail('PTT', '${_screening.pttMs} ms', theme.colorScheme.primary)),
                    ],
                  ),
                  const AppSpacing.vsm(),
                  Text(
                    'NOT FOR CLINICAL USE - PTT-based estimation is experimental',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w500,
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

  Widget _buildInfoItem(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const AppSpacing.hxs(),
            Expanded(
              child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ),
          ],
        ),
        const AppSpacing.vxs(),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildBPDetail(String label, String value, Color color) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const AppSpacing.vxs(),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSymptomsCard() {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reported Symptoms',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const AppSpacing.vmd(),
          if (_screening.symptoms.isEmpty)
            Text(
              'No symptoms reported',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: _screening.symptoms.map((s) => Chip(
                label: Text(s),
                backgroundColor: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                labelStyle: TextStyle(color: theme.colorScheme.tertiary),
                side: BorderSide(color: theme.colorScheme.tertiary.withValues(alpha: 0.3)),
              )).toList(),
            ),
          if (_screening.symptomDuration != null) ...[
            const AppSpacing.vmd(),
            _buildInfoRow('Duration', _screening.symptomDuration!),
          ],
          if (_screening.symptomNotes != null && _screening.symptomNotes!.isNotEmpty) ...[
            const AppSpacing.vmd(),
            _buildInfoRow('Notes', _screening.symptomNotes!),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskAnalysisCard(Color riskColor) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Risk Analysis',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const AppSpacing.vlg(),
          _buildInfoRow('Escalation Level', _screening.escalationLevel),
          const AppSpacing.vmd(),
          if (_screening.triggeredRules.isNotEmpty) ...[
            Text(
              'Triggered Rules:',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const AppSpacing.vsm(),
            ..._screening.triggeredRules.map((rule) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingXs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.flag_rounded, size: 16, color: riskColor),
                      const AppSpacing.hsm(),
                      Expanded(
                        child: Text(
                          rule,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )),
          ] else ...[
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20),
                const AppSpacing.hsm(),
                Expanded(
                  child: Text(
                      'No risk rules triggered',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAICard() {
    final theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      border: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, color: theme.colorScheme.primary, size: 20),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                    'AI Explanation Summary',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          Text(
            _screening.aiSummary!,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const AppSpacing.vmd(),
          AppTextButton(
            label: 'View Full Explanation',
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: () => context.go('/screening/ai-explanation'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard() {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Screening Metadata',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const AppSpacing.vlg(),
          _buildInfoRow('Screening ID', _screening.id),
          _buildInfoRow('Patient ID', _screening.patientId),
          _buildInfoRow('Device ID', _screening.deviceId),
          _buildInfoRow('Sync Status', _screening.syncStatus),
          if (_screening.retryCount > 0)
            _buildInfoRow('Sync Retries', _screening.retryCount.toString()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: AppOutlinedButton(
            label: 'View Triage',
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () => context.go('/screening/triage'),
          ),
        ),
        const AppSpacing.hmd(),
        Expanded(
          child: AppButton(
            label: 'Share Report',
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareScreening,
          ),
        ),
      ],
    );
  }

  void _shareScreening() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_monthName(dt.month)} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}