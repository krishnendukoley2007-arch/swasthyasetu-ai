/// The explanation half of the tiered AI layer.
///
/// The screen never decides anything clinical. It shows the band the rule engine
/// already produced, then whatever prose explains it — from Gemini when there is
/// a network *and* consent, from the on-device guideline corpus otherwise. Which
/// of the two happened is stated on screen, because "this came from the internet"
/// and "this came from the guidelines on your phone" are different claims and a
/// worker is entitled to know which one they are reading.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/gemini_service.dart'
    show GeminiFailureText;
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/explanation_repository.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/features/screening/state/screening_draft.dart';

class AiExplanationScreen extends ConsumerStatefulWidget {
  const AiExplanationScreen({super.key});

  @override
  ConsumerState<AiExplanationScreen> createState() =>
      _AiExplanationScreenState();
}

class _AiExplanationScreenState extends ConsumerState<AiExplanationScreen> {
  /// Guards the one-shot setup. `didChangeDependencies` fires again on a theme
  /// or text-scale change, and re-generating would mean a second network call
  /// because the worker rotated the phone.
  bool _prepared = false;

  bool _loading = true;
  ExplanationResult? _result;
  String? _error;

  TriageAssessment? _assessment;
  String? _patientName;

  /// Null for the demo walkthrough — there is no row to cache against.
  String? _screeningId;

  final TextEditingController _question = TextEditingController();
  bool _asking = false;
  String? _answer;
  String? _answerNotice;

  /// Set when the only thing standing between the question and an answer is the
  /// consent switch — which the worker can grant from here rather than being
  /// sent to Settings and back with their question lost.
  bool _answerNeedsConsent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prepared) return;
    _prepared = true;
    _prepare();
    _load();
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  /// Rebuilds the assessment rather than accepting one over the route.
  ///
  /// Re-running the engine on the same sample is deterministic and costs
  /// microseconds, which is cheaper than serialising a [TriageAssessment]
  /// through `GoRouter.extra` and risking a stale copy.
  void _prepare() {
    final draft = ref.read(screeningDraftProvider);

    if (draft.hasPatient && draft.sample != null) {
      _assessment = RiskEngine.assessForPatient(
        sample: draft.sample!,
        symptoms: draft.symptoms,
        patient: draft.patient!,
      );
      _patientName = draft.patient!.name;
      _screeningId = draft.savedScreeningId;
      return;
    }

    // Entered sideways: deep link, or the demo route opened directly.
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final sampleJson = extra?['sample'] as Map<String, dynamic>?;
    final sample = sampleJson != null
        ? HealthSample.fromJson(sampleJson)
        : HealthSample.demo(
            heartRateBpm: 108,
            spo2Percent: 94,
            temperatureC: 38.3,
            ecgSignalQuality: 0.88,
            rrIntervalMs: 556,
          );
    final symptoms =
        (extra?['symptoms'] as List<dynamic>?)?.whereType<String>().toList() ??
            const ['Fever', 'Dizziness'];

    _assessment = RiskEngine.assess(sample: sample, symptoms: symptoms);
    _patientName = extra?['patientName'] as String?;
    _screeningId = extra?['screeningId'] as String?;
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final assessment = _assessment;
    if (assessment == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final settings = ref.read(settingsProvider);
      final result = await ref.read(explanationRepositoryProvider).explain(
            assessment: assessment,
            screeningId: _screeningId,
            patientName: _patientName,
            languageCode: settings.locale.languageCode,
            // Going online means a reading leaves the phone. That is gated on
            // the same consent switch Settings exposes; without it the offline
            // path answers, which it can always do.
            preferOnline: settings.aiConsent,
            forceRefresh: forceRefresh,
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _ask() async {
    final assessment = _assessment;
    final text = _question.text.trim();
    if (assessment == null || text.isEmpty || _asking) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _asking = true;
      _answer = null;
      _answerNotice = null;
      _answerNeedsConsent = false;
    });

    if (!ref.read(settingsProvider).aiConsent) {
      setState(() {
        _asking = false;
        _answerNeedsConsent = true;
        _answerNotice = 'Online AI assistance is off, so nothing was sent. The '
            'explanation above works without it.';
      });
      return;
    }

    String? answer;
    try {
      answer = await ref.read(explanationRepositoryProvider).answerQuestion(
            assessment: assessment,
            question: text,
          );
    } catch (_) {
      answer = null;
    }

    if (!mounted) return;
    setState(() {
      _asking = false;
      _answer = answer;
      // Null is the designed offline answer, not a crash: a free-text clinical
      // question is never answered from a template. But *why* it failed decides
      // what the worker should do next, so read it off the service instead of
      // always blaming the connection — a rejected key looked identical to no
      // signal, and sent people hunting for bars they already had.
      _answerNotice = answer == null ? _failureNotice() : null;
    });
  }

  /// The reason the last online attempt failed, in words that imply an action.
  String _failureNotice() {
    final failure = ref.read(geminiServiceProvider).lastFailure;
    if (failure == null) {
      return 'No answer came back. The explanation above is already saved on '
          'this phone.';
    }
    return '${failure.label}. ${failure.detail}';
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Explanation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to result',
          onPressed: () => context.go('/screening/triage'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Write it again',
            onPressed: _loading ? null : () => _load(forceRefresh: true),
          ),
        ],
        elevation: 0,
        scrolledUnderElevation: AppTheme.elevationLevel1,
      ),
      body: _loading
          ? _buildLoadingState()
          : _result == null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final result = _result!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(result),
          const AppSpacing.vlg(),
          _buildSection(
            title: 'Summary',
            body: result.explanation.summary,
            icon: Icons.summarize_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          _buildSection(
            title: 'Why this level',
            body: result.explanation.whyThisLevel,
            icon: Icons.help_outline_rounded,
            color: Theme.of(context).colorScheme.secondary,
          ),
          _buildSection(
            title: 'What to do now',
            body: result.explanation.safeNextSteps,
            icon: Icons.directions_outlined,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          _buildSection(
            title: 'When to escalate',
            body: result.explanation.whenToEscalate,
            icon: Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          if (result.explanation.questionsToAsk.isNotEmpty)
            _buildQuestionsToAsk(result.explanation.questionsToAsk),
          if (result.citations.isNotEmpty) _buildCitations(result.citations),
          _buildAskBox(),
          const AppSpacing.vmd(),
          _buildDisclaimer(result.explanation.disclaimer),
          const AppSpacing.vxl(),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader(ExplanationResult result) {
    final theme = Theme.of(context);
    final assessment = _assessment!;
    final risk = RiskStyle.of(assessment.band, context.l10n);
    final online = result.source == ExplanationSource.gemini;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      border: BorderSide(
        color: theme.colorScheme.primary.withValues(alpha: 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  color: theme.colorScheme.primary,
                  size: 26,
                ),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plain-language explanation',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      // The invariant, stated where the worker can see it.
                      'The risk level came from fixed clinical rules. This text '
                      'only explains that result.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          // Wrap, not Row: three pills at 2.0x text scale do not fit on one
          // line of a 360px screen, and they must reflow rather than clip.
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: [
              _pill(
                label: '${risk.label} · ${assessment.score}/100',
                icon: risk.icon,
                foreground: risk.onColor,
                background: risk.color,
              ),
              _pill(
                label: result.source.label,
                icon: online
                    ? Icons.cloud_done_outlined
                    : Icons.offline_bolt_outlined,
                foreground: theme.colorScheme.onSecondaryContainer,
                background: theme.colorScheme.secondaryContainer,
              ),
              if (result.fromCache)
                _pill(
                  label: 'Saved on this phone',
                  icon: Icons.save_outlined,
                  foreground: theme.colorScheme.onSurfaceVariant,
                  background: theme.colorScheme.surfaceContainerHighest,
                ),
              if (assessment.isDemo)
                _pill(
                  label: 'Demo reading',
                  icon: Icons.science_outlined,
                  foreground: theme.colorScheme.onTertiaryContainer,
                  background: theme.colorScheme.tertiaryContainer,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required IconData icon,
    required Color foreground,
    required Color background,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const AppSpacing.hxs(),
          // Flexible, not a fixed maxWidth: a non-flex child of a Row is
          // measured against *unbounded* width, so a ConstrainedBox here would
          // let the label size past the pill's own share of the line.
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String body,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    if (body.trim().isEmpty) return const SizedBox.shrink();

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          // Rendered plainly rather than typed out character by character. The
          // offline path quotes guideline text verbatim, and a 1,500-character
          // passage at 15ms a character is a twenty-second wait for a worker
          // who needs to read it now.
          Text(
            body.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsToAsk(List<String> questions) {
    final theme = Theme.of(context);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  Icons.record_voice_over_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Ask the person',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          for (final question in questions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  Expanded(
                    child: Text(
                      question,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCitations(List<String> citations) {
    final theme = Theme.of(context);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Guidelines used',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          for (final citation in citations)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingXs),
              child: Text(
                citation,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAskBox() {
    final theme = Theme.of(context);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ask a follow-up',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const AppSpacing.vxs(),
          Text(
            // Two prerequisites, not one, and saying only "needs a connection"
            // left a worker with full signal and no key retrying forever.
            ref.watch(geminiServiceProvider).isConfigured
                ? 'Needs a connection. The explanation above does not.'
                : 'Needs a connection and an AI key (add one in Settings). The '
                    'explanation above needs neither.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const AppSpacing.vmd(),
          AppTextField(
            controller: _question,
            hint: 'e.g. Should they walk to the clinic or wait?',
            maxLines: 3,
            minLines: 1,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
          ),
          const AppSpacing.vmd(),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Ask',
              icon: const Icon(Icons.send_rounded),
              isLoading: _asking,
              onPressed: _asking ? null : _ask,
            ),
          ),
          if (_answer != null) ...[
            const AppSpacing.vmd(),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer
                    .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Text(
                _answer!,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ],
          if (_answerNotice != null) ...[
            const AppSpacing.vmd(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _answerNeedsConsent
                      ? Icons.privacy_tip_outlined
                      : Icons.cloud_off_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const AppSpacing.hsm(),
                Expanded(
                  child: Text(
                    _answerNotice!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (_answerNeedsConsent) ...[
              const AppSpacing.vsm(),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.cloud_outlined, size: 18),
                  label: const Text('Allow online AI and ask'),
                  onPressed: () async {
                    await ref
                        .read(settingsProvider.notifier)
                        .setAiConsent(true);
                    if (!mounted) return;
                    await _ask();
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    final theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      border: BorderSide(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel_outlined, color: theme.colorScheme.tertiary, size: 20),
          const AppSpacing.hmd(),
          Expanded(
            child: Text(
              disclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: AppOutlinedButton(
            label: 'Back to result',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/screening/triage'),
            borderColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.primary,
          ),
        ),
        const AppSpacing.hmd(),
        Expanded(
          child: AppButton(
            label: 'Done',
            icon: const Icon(Icons.check_circle_outline_rounded),
            onPressed: () {
              ref.read(screeningDraftProvider.notifier).clear();
              context.go('/home');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);

    return AppCenteredScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
            strokeWidth: 3,
          ),
          const AppSpacing.vlg(),
          Text(
            'Writing the explanation…',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vsm(),
          Text(
            'Uses the internet if there is one, the guidelines on this phone if '
            'there is not.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);

    return AppCenteredScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
          const AppSpacing.vlg(),
          Text(
            'Could not write the explanation',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vsm(),
          Text(
            // The reading itself is already saved; say so, or the worker will
            // assume the whole screening was lost.
            'The screening result is safe and already stored on this phone. '
            'Only the written explanation failed.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const AppSpacing.vsm(),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const AppSpacing.vxl(),
          AppButton(
            label: 'Try again',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _load(forceRefresh: true),
          ),
          const AppSpacing.vmd(),
          AppTextButton(
            label: 'Back to result',
            onPressed: () => context.go('/screening/triage'),
          ),
        ],
      ),
    );
  }
}
