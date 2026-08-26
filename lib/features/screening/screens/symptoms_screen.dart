import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/constants/app_constants.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/features/screening/state/screening_draft.dart';

class SymptomsScreen extends ConsumerStatefulWidget {
  const SymptomsScreen({super.key});

  @override
  ConsumerState<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends ConsumerState<SymptomsScreen> {
  final Set<String> _selectedSymptoms = {};
  final TextEditingController _notesController = TextEditingController();
  String _selectedDuration = '1-3 days';
  HealthSample? _liveSample;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _toggleSymptom(String symptom) {
    setState(() {
      if (_selectedSymptoms.contains(symptom)) {
        _selectedSymptoms.remove(symptom);
      } else {
        _selectedSymptoms.add(symptom);
      }
    });
  }

  void _proceedToTriage() {
    // Use the live screening sample if available, otherwise use a normal baseline demo sample.
    // Vitals come from sensors (live screening), symptoms from patient report.
    // RiskEngine combines both deterministically. No symptom→vitals coupling.
    final sample = _liveSample ??
        HealthSample.demo(
          heartRateBpm: 72,
          spo2Percent: 98,
          temperatureC: 36.5,
          ecgSignalQuality: 0.95,
          rrIntervalMs: (60000 / 72).round(),
        );

    final notes = _notesController.text.trim();
    ref.read(screeningDraftProvider.notifier).setSymptoms(
          _selectedSymptoms.toList(),
          duration: _selectedDuration,
          notes: notes.isEmpty ? null : notes,
        );

    // The route still carries the reading as well. Triage is reachable directly
    // for the demo walkthrough, and in that case the draft is empty — the extra
    // is what keeps that path working.
    context.go('/screening/triage', extra: {
      'sample': sample.toJson(),
      'symptoms': _selectedSymptoms.toList(),
      'duration': _selectedDuration,
      'notes': notes,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    _liveSample = extra?['liveSample'] as HealthSample?;

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Symptoms'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/screening/live'),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppTheme.spacingMd),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingXs),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              'DEMO',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepHeader(
                    'Select Symptoms',
                    'Check all that apply for this screening',
                    Icons.healing_rounded,
                  ),
                  const AppSpacing.vxl(),
                  ...AppConstants.symptomOptions
                      .map((symptom) => _buildSymptomChip(symptom))
                      ,
                  const AppSpacing.vxl(),
                  _buildSectionHeader('Duration'),
                  const AppSpacing.vmd(),
                  _buildDurationChips(),
                  const AppSpacing.vxl(),
                  _buildSectionHeader('Additional Notes (Optional)'),
                  const AppSpacing.vmd(),
                  AppTextField(
                    controller: _notesController,
                    hint: 'Any other relevant information...',
                    prefixIcon: Icons.note_outlined,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String title, String subtitle, IconData icon) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer, size: 28),
        ),
        const AppSpacing.hmd(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const AppSpacing.vxs(),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSymptomChip(String symptom) {
    final theme = Theme.of(context);
    final isSelected = _selectedSymptoms.contains(symptom);
    final isRespiratory =
        ['Breathlessness', 'Chest discomfort', 'Cough'].contains(symptom);
    final color = isRespiratory ? theme.colorScheme.error : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: FilterChip(
        label: Text(symptom),
        selected: isSelected,
        onSelected: (_) => _toggleSymptom(symptom),
        selectedColor: color.withValues(alpha: 0.15),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: isSelected ? color : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? color : theme.colorScheme.outlineVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildDurationChips() {
    final theme = Theme.of(context);
    final durations = [
      '< 24 hours',
      '1-3 days',
      '4-7 days',
      '1-2 weeks',
      '> 2 weeks'
    ];

    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: durations.map((duration) {
        final isSelected = _selectedDuration == duration;
        return FilterChip(
          label: Text(duration),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedDuration = duration),
          selectedColor: theme.colorScheme.primaryContainer,
          checkmarkColor: theme.colorScheme.primary,
          labelStyle: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildBottomBar() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: AppOutlinedButton(
              label: 'Back',
              onPressed: () => context.go('/screening/live'),
            ),
          ),
          const AppSpacing.hmd(),
          Expanded(
            child: AppButton(
              label: 'Continue to Triage',
              icon: const Icon(Icons.arrow_forward_rounded),
              onPressed: _selectedSymptoms.isEmpty ? null : _proceedToTriage,
            ),
          ),
        ],
      ),
    );
  }
}