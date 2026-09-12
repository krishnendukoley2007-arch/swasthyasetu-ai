/// The explanation half of the tiered AI layer, as a conversation.
///
/// The screen never decides anything clinical. It shows the band the rule engine
/// already produced, then whatever prose explains it — from Gemini when there is
/// a network *and* consent, from the on-device guideline corpus otherwise. Which
/// of the two happened is stated on screen, because "this came from the internet"
/// and "this came from the guidelines on your phone" are different claims and a
/// worker is entitled to know which one they are reading.
///
/// It is a chat rather than a stack of cards because of two complaints, both
/// fair. The explanation sat behind one tap and the question box behind a
/// scroll, so the thing a worker wanted was the thing furthest away; and the old
/// load awaited Gemini before rendering anything, so a weak signal bought a
/// twelve-second spinner instead of the offline text that was already on the
/// phone. Here the offline explanation is posted the moment the screen opens,
/// and the online one replaces it if and when it arrives.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/gemini_service.dart'
    show GeminiFailureText, GeminiService;
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/explanation_repository.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/models/patient_profile_context.dart';
import 'package:swasthyasetu_ai/domain/rules/offline_explainer.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';
import 'package:swasthyasetu_ai/features/screening/state/screening_draft.dart';

/// Who a bubble belongs to. [system] is the app speaking about itself — a
/// failure, a consent gate, a note that the text above was replaced — and is
/// deliberately styled unlike the assistant so it cannot be mistaken for
/// clinical content.
enum _Author { assistant, worker, system }

/// The one bubble that gets a red wash. Reserved for the escalation section, so
/// "go immediately if" is findable without reading.
enum _Tone { danger }

@immutable
class _Message {
  const _Message({
    required this.author,
    required this.text,
    required this.at,
    this.heading,
    this.footnote,
    this.tone,
  });

  final _Author author;
  final String text;
  final DateTime at;

  /// Bold label above the text. The explanation arrives in four parts and a
  /// worker scanning for one of them needs it labelled.
  final String? heading;

  /// Small line under the text saying where the words came from.
  final String? footnote;

  final _Tone? tone;
}

const _kVitalsHeading = 'Vitals Executive Summary';
const _kActionPlanTag = 'Action Plan';
const _kEmergencyTag = 'Emergency Red Flags';
const _kFindingsTag = 'Key Clinical Findings';
const _kSosBtnLabel = 'Send Emergency SOS';
const _kHrTachy = 'Elevated';
const _kHrBrady = 'Low';
const _kNormalTag = 'Normal';
const _kCriticalTag = 'Critical';
const _kLowTag = 'Low';
const _kFeverTag = 'Fever';
const _kSignalTag = 'Signal';
const _kOnDevicePrivacyPill = 'On-Device Private';
const _kOnDevicePrivacyTooltip =
    '100% on-device guideline evaluation · Zero cloud vitals';
const _kSectionReadingShowed = 'What your reading showed';
const _kSectionMeaning = 'What this could mean';
const _kSectionActionPlan = 'What you can do now';
const _kSectionWarningSigns = 'Warning signs to watch for';
const _kWarningSignsTag = 'Signs to Watch';

class AiExplanationScreen extends ConsumerStatefulWidget {
  const AiExplanationScreen({super.key});

  @override
  ConsumerState<AiExplanationScreen> createState() =>
      _AiExplanationScreenState();
}

class _AiExplanationScreenState extends ConsumerState<AiExplanationScreen> {
  /// Guards the one-shot setup. `didChangeDependencies` fires again on a theme
  /// or text-scale change, and re-running would mean a second network call
  /// because the worker rotated the phone.
  bool _prepared = false;

  /// The explanation, replaced wholesale when the online tier lands. Kept apart
  /// from [_chat] so the upgrade can swap it without disturbing anything the
  /// worker has since asked.
  List<_Message> _brief = const [];

  /// Questions, answers and notices, in the order they happened.
  final List<_Message> _chat = [];

  bool _loadingBrief = true;
  bool _typing = false;
  bool _sending = false;

  /// The question that was blocked by the consent switch, so granting it can
  /// resend rather than making the worker retype.
  String? _blockedQuestion;

  List<String> _suggestions = const [];

  TriageAssessment? _assessment;
  String? _patientName;
  String? _patientId;

  /// Null for the demo walkthrough — there is no row to cache against.
  String? _screeningId;

  final TextEditingController _question = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prepared) return;
    _prepared = true;
    _prepare();
    _start();
  }

  @override
  void dispose() {
    _question.dispose();
    _scroll.dispose();
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
      _patientId = draft.patient!.id;
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
    _patientId = extra?['patientId'] as String?;
    _screeningId = extra?['screeningId'] as String?;
  }

  PatientProfileContext _resolveProfile() {
    final account = ref.read(authStateProvider).account;
    final draft = ref.read(screeningDraftProvider);

    if (account != null && account.role.isPatient) {
      return PatientProfileContext.fromAccount(account);
    }

    if (draft.hasPatient) {
      return PatientProfileContext.fromPatient(
        draft.patient,
        complaints: draft.symptomNotes?.isNotEmpty == true
            ? draft.symptomNotes
            : null,
      );
    }

    if (account != null) {
      return PatientProfileContext.fromAccount(account);
    }

    return const PatientProfileContext();
  }

  /// Offline first, online second, and nothing blocking on the network.
  Future<void> _start({bool refresh = false}) async {
    final assessment = _assessment;
    if (assessment == null) return;

    final settings = ref.read(settingsProvider);
    // Derived from the account, never from a setting anyone can tap — see
    // effectiveAudienceProvider.
    final audience = ref.read(effectiveAudienceProvider);
    final repo = ref.read(explanationRepositoryProvider);

    setState(() {
      _loadingBrief = true;
      if (refresh) {
        _brief = const [];
        _suggestions = const [];
      }
    });

    // Anything already stored wins outright: it is instant, and regenerating
    // would spend a network call rewriting text the worker may already have
    // read. "Write it again" is the way to override that.
    ExplanationResult? shown;
    final id = _screeningId;
    if (id != null && !refresh) {
      shown = await _attempt(() => repo.cached(id, audience: audience));
    }

    shown ??= await _attempt(
      () => repo.explainOffline(
        assessment: assessment,
        screeningId: _screeningId,
        patientName: _patientName,
        audience: audience,
      ),
    );

    if (!mounted) return;

    if (shown == null) {
      // Both tiers failed, which for the offline one means the guideline corpus
      // could not be read at all. Say that, and say the reading itself is safe.
      setState(() {
        _loadingBrief = false;
        _chat.add(
          _Message(
            author: _Author.system,
            text:
                'The written explanation could not be built on this phone. '
                'The screening itself is saved — only the words failed.',
            at: DateTime.now(),
          ),
        );
      });
      return;
    }

    _postBrief(shown);

    // Upgrade only when it can add something: consent given, a key present, and
    // the text on screen not already the online one.
    final canUpgrade =
        settings.aiConsent &&
        ref.read(geminiServiceProvider).isConfigured &&
        shown.source != ExplanationSource.gemini;
    if (!canUpgrade) return;

    setState(() => _typing = true);
    _scrollToEnd();

    final better = await _attempt(
      () => repo.explainOnline(
        assessment: assessment,
        screeningId: _screeningId,
        patientName: _patientName,
        languageCode: settings.locale.languageCode,
        audience: audience,
        profile: _resolveProfile(),
      ),
    );

    if (!mounted) return;
    setState(() => _typing = false);
    if (better != null) _postBrief(better, replacing: true);
  }

  /// Runs a repository call and turns a throw into null.
  ///
  /// Every tier here is allowed to fail; none of them is allowed to take the
  /// screen down with it, because the band and the reading are already saved.
  Future<T?> _attempt<T>(Future<T?> Function() body) async {
    try {
      return await body();
    } catch (_) {
      return null;
    }
  }

  /// Turns one explanation into the run of bubbles that represents it.
  void _postBrief(ExplanationResult result, {bool replacing = false}) {
    final explanation = result.explanation;
    final now = DateTime.now();
    // Same four sections either way — only the labels differ, because a patient
    // is not "escalating" anything and a nurse is not being told what to do at
    // home. The underlying JSON keys are identical in both prompts.
    final patient = ref.read(effectiveAudienceProvider).isPatient;

    final isCriticalRed = _assessment?.band == RiskBand.red;
    final sections = <(String, String, _Tone?)>[
      (
        patient ? _kSectionReadingShowed : 'What this reading showed',
        explanation.summary,
        null,
      ),
      (
        patient ? _kSectionMeaning : 'Why this level',
        explanation.whyThisLevel,
        null,
      ),
      (
        patient ? _kSectionActionPlan : 'What to do now',
        explanation.safeNextSteps,
        null,
      ),
      (
        patient ? _kSectionWarningSigns : 'Go immediately if',
        explanation.whenToEscalate,
        isCriticalRed ? _Tone.danger : null,
      ),
    ].where((section) => section.$2.trim().isNotEmpty).toList();

    final built = <_Message>[
      for (var i = 0; i < sections.length; i++)
        _Message(
          author: _Author.assistant,
          heading: sections[i].$1,
          text: sections[i].$2.trim(),
          tone: sections[i].$3,
          at: now,
          // Provenance rides on the last bubble of the run rather than each
          // one: repeating it four times trains people to stop reading it.
          footnote: i == sections.length - 1 ? _provenance(result) : null,
        ),
    ];

    final notes = <String>[
      if (result.citations.isNotEmpty)
        'Guidelines used: ${result.citations.join(' · ')}',
      explanation.disclaimer.trim(),
    ].where((note) => note.isNotEmpty).toList();

    if (notes.isNotEmpty) {
      built.add(
        _Message(author: _Author.system, text: notes.join('\n\n'), at: now),
      );
    }

    setState(() {
      _brief = built;
      _loadingBrief = false;
      _suggestions = explanation.questionsToAsk
          .map((question) => question.trim())
          .where((question) => question.isNotEmpty)
          .toList();
      if (replacing) {
        _chat.add(
          _Message(
            author: _Author.system,
            text: 'The explanation above was rewritten using the online model.',
            at: now,
          ),
        );
      }
    });
    _scrollToEnd();
  }

  String _provenance(ExplanationResult result) {
    final saved = result.fromCache ? ' · saved on this phone' : '';
    return switch (result.source) {
      ExplanationSource.gemini =>
        'Explained online by ${GeminiService.model}'
            '$saved. The risk level came from the rule engine, not the model.',
      ExplanationSource.offline =>
        'Explained offline from the guidelines on this phone$saved.',
    };
  }

  Future<void> _ask(String raw) async {
    final assessment = _assessment;
    final text = raw.trim();
    if (assessment == null || text.isEmpty || _sending) return;

    _question.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _chat.add(
        _Message(author: _Author.worker, text: text, at: DateTime.now()),
      );
      _sending = true;
      _blockedQuestion = null;
    });
    _scrollToEnd();

    if (!ref.read(settingsProvider).aiConsent) {
      final offlineAnswer = OfflineExplainer.answerClinicalQuestion(
        assessment: assessment,
        question: text,
      );
      setState(() {
        _sending = false;
        _chat.add(
          _Message(
            author: _Author.assistant,
            text: offlineAnswer,
            at: DateTime.now(),
            footnote:
                'Answered offline from on-device guidelines (Online AI switched off)',
          ),
        );
      });
      _scrollToEnd();
      return;
    }

    setState(() => _typing = true);
    _scrollToEnd();

    final answer = await _attempt(
      () => ref
          .read(explanationRepositoryProvider)
          .answerQuestion(
            assessment: assessment,
            question: text,
            audience: ref.read(effectiveAudienceProvider),
            languageCode: ref.read(settingsProvider).locale.languageCode,
            profile: _resolveProfile(),
          ),
    );

    if (!mounted) return;
    setState(() {
      _typing = false;
      _sending = false;
      final trimmed = answer?.trim() ?? '';
      final isOnline = ref.read(geminiServiceProvider).isConfigured;
      _chat.add(
        trimmed.isNotEmpty
            ? _Message(
                author: _Author.assistant,
                text: trimmed,
                at: DateTime.now(),
                footnote: isOnline
                    ? 'Answered online by ${GeminiService.model}'
                    : 'Answered offline from on-device guidelines',
              )
            : _Message(
                author: _Author.system,
                text: _failureNotice(),
                at: DateTime.now(),
              ),
      );
    });
    _scrollToEnd();
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

  Future<void> _allowAndResend() async {
    final pending = _blockedQuestion;
    await ref.read(settingsProvider.notifier).setAiConsent(true);
    if (!mounted || pending == null) return;
    setState(() => _blockedQuestion = null);
    await _ask(pending);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  /// Back to the result the chat is about. Pushed on top of it in the normal
  /// flow, so pop first and only route as a fallback for a deep link.
  void _back() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    context.go('/screening/triage');
  }

  void _openSos() {
    final query = <String, String>{
      'trigger': SosTrigger.highRisk.storageValue,
      if (_patientId != null) 'patientId': _patientId!,
      if (_screeningId != null) 'screeningId': _screeningId!,
    };
    context.push(
      Uri(path: '/emergency/sos', queryParameters: query).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assessment = _assessment;
    final messages = <_Message>[..._brief, ..._chat];
    // Red bands offer the SOS on the result screen. This screen opens on top of
    // that one automatically, so it has to carry the same affordance or the
    // convenience would have cost a worker the emergency button.
    final offerSos =
        assessment?.band == RiskBand.red &&
        ref.watch(settingsProvider).autoSuggestSos;

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Explanation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to result',
          onPressed: _back,
        ),
        actions: [
          if (offerSos)
            IconButton(
              icon: const Icon(Icons.sos_rounded),
              color: Theme.of(context).colorScheme.error,
              tooltip: 'Send emergency SOS',
              onPressed: _openSos,
            ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              switch (value) {
                case 'again':
                  _start(refresh: true);
                case 'result':
                  _back();
                case 'finish':
                  ref.read(screeningDraftProvider.notifier).clear();
                  context.go('/home');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'again', child: Text('Write it again')),
              PopupMenuItem(value: 'result', child: Text('Back to result')),
              PopupMenuItem(value: 'finish', child: Text('Finish screening')),
            ],
          ),
        ],
        elevation: 0,
        scrolledUnderElevation: AppTheme.elevationLevel1,
      ),
      body: Column(
        children: [
          _statusStrip(),
          Expanded(
            child: messages.isEmpty
                ? _openingState()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingMd,
                      AppTheme.spacingMd,
                      AppTheme.spacingMd,
                      AppTheme.spacingSm,
                    ),
                    itemCount:
                        (assessment != null ? 1 : 0) +
                        messages.length +
                        (_typing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (assessment != null && index == 0) {
                        return _buildVitalsHero(assessment);
                      }
                      final msgIndex = assessment != null ? index - 1 : index;
                      return msgIndex < messages.length
                          ? _bubble(messages[msgIndex])
                          : _typingBubble();
                    },
                  ),
          ),
          _composer(),
        ],
      ),
    );
  }

  /// The honesty row: which band, where the words came from, whether the numbers
  /// behind them were measured at all.
  Widget _statusStrip() {
    final theme = Theme.of(context);
    final assessment = _assessment;
    if (assessment == null) return const SizedBox.shrink();

    final risk = RiskStyle.of(assessment.band, context.l10n);
    final source = _brief.isEmpty
        ? null
        : _brief.any((m) => m.footnote?.startsWith('Explained online') ?? false)
        ? ExplanationSource.gemini
        : ExplanationSource.offline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingSm,
        AppTheme.spacingMd,
        AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      // Wrap, not Row: three pills at 2.0x text scale do not fit on one line of
      // a 360px screen, and they must reflow rather than clip.
      child: Wrap(
        spacing: AppTheme.spacingSm,
        runSpacing: AppTheme.spacingXs,
        children: [
          _pill(
            label: '${risk.label} · ${assessment.score}/100',
            icon: risk.icon,
            foreground: risk.onColor,
            background: risk.color,
          ),
          if (source != null)
            _pill(
              label: source.label,
              icon: source == ExplanationSource.gemini
                  ? Icons.cloud_done_outlined
                  : Icons.offline_bolt_outlined,
              foreground: theme.colorScheme.onSecondaryContainer,
              background: theme.colorScheme.secondaryContainer,
            ),
          if (source == ExplanationSource.offline)
            _pill(
              label: _kOnDevicePrivacyPill,
              icon: Icons.shield_outlined,
              foreground: theme.colorScheme.onTertiaryContainer,
              background: theme.colorScheme.tertiaryContainer,
              tooltip: _kOnDevicePrivacyTooltip,
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
    );
  }

  Widget _pill({
    required String label,
    required IconData icon,
    required Color foreground,
    required Color background,
    String? tooltip,
  }) {
    final theme = Theme.of(context);

    final pillWidget = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const AppSpacing.hxs(),
          // Flexible, not a fixed maxWidth: a non-flex child of a Row is
          // measured against *unbounded* width, so a ConstrainedBox here would
          // let the label size past the pill's own share of the line.
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: pillWidget);
    }
    return pillWidget;
  }

  Widget _buildVitalsHero(TriageAssessment assessment) {
    final s = assessment.sample;
    final theme = Theme.of(context);

    final hrBpm = s.heartRateBpm;
    final hrColor = (hrBpm > 100 || hrBpm < 50)
        ? const Color(0xFFEF4444)
        : (theme.brightness == Brightness.dark
              ? AppTheme.cardiacCoralDark
              : AppTheme.cardiacCoral);
    final hrStatus = hrBpm > 100
        ? _kHrTachy
        : (hrBpm < 50 ? _kHrBrady : _kNormalTag);

    final spo2 = s.spo2Percent;
    final spo2Color = spo2 < 90
        ? const Color(0xFFEF4444)
        : (spo2 < 95 ? const Color(0xFFF59E0B) : const Color(0xFF06B6D4));
    final spo2Status = spo2 < 90
        ? _kCriticalTag
        : (spo2 < 95 ? _kLowTag : _kNormalTag);

    final temp = s.temperatureC;
    final tempColor = temp >= 38.0
        ? const Color(0xFFEF4444)
        : (temp >= 37.5 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
    final tempStatus = temp >= 38.0 ? _kFeverTag : _kNormalTag;

    final sqi = (s.ecgSignalQuality * 100).round();
    final sqiColor = sqi >= 75
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_heart_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _kVitalsHeading,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricTile(
                icon: Icons.favorite_rounded,
                label: '$hrBpm BPM',
                sublabel: hrStatus,
                color: hrColor,
              ),
              _metricTile(
                icon: Icons.air_rounded,
                label: '$spo2% SpO₂',
                sublabel: spo2Status,
                color: spo2Color,
              ),
              _metricTile(
                icon: Icons.thermostat_rounded,
                label: '${temp.toStringAsFixed(1)}°C',
                sublabel: tempStatus,
                color: tempColor,
              ),
              _metricTile(
                icon: Icons.graphic_eq_rounded,
                label: '$sqi% SQI',
                sublabel: _kSignalTag,
                color: sqiColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  sublabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Message message) {
    if (message.author == _Author.system) return _systemLine(message);
    if (message.author == _Author.worker) return _workerBubble(message);
    return _assistantClinicalCard(message);
  }

  Widget _workerBubble(_Message message) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _clock(message.at),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _assistantClinicalCard(_Message message) {
    final theme = Theme.of(context);
    final isPatient = ref.watch(effectiveAudienceProvider).isPatient;
    final danger = message.tone == _Tone.danger;
    final heading = message.heading?.toLowerCase() ?? '';
    final isActionPlan =
        heading.contains('do') ||
        heading.contains('action') ||
        heading.contains('step');
    final isWarningSigns =
        heading.contains('warning') || heading.contains('watch');
    final isEscalation =
        danger ||
        (!isPatient &&
            (heading.contains('immediately') || heading.contains('escalat')));

    final cardBg = isEscalation
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.35)
        : isWarningSigns
        ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.22)
        : isActionPlan
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);

    final borderColor = isEscalation
        ? theme.colorScheme.error.withValues(alpha: 0.6)
        : isWarningSigns
        ? theme.colorScheme.tertiary.withValues(alpha: 0.45)
        : isActionPlan
        ? theme.colorScheme.primary.withValues(alpha: 0.4)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.4);

    final cardTitle =
        message.heading ??
        (isEscalation
            ? _kEmergencyTag
            : (isWarningSigns
                  ? _kWarningSignsTag
                  : (isActionPlan ? _kActionPlanTag : _kFindingsTag)));

    final titleIcon = isEscalation
        ? Icons.warning_amber_rounded
        : (isWarningSigns
              ? Icons.shield_outlined
              : (isActionPlan
                    ? Icons.checklist_rounded
                    : Icons.analytics_outlined));

    final titleColor = isEscalation
        ? theme.colorScheme.error
        : (isWarningSigns
              ? theme.colorScheme.tertiary
              : (isActionPlan
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary));

    final points = _extractPoints(message.text);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: borderColor,
            width: isEscalation ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(titleIcon, size: 18, color: titleColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cardTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isActionPlan) ...[
              for (var i = 0; i < points.length; i++)
                _buildActionStepTile(i + 1, points[i]),
            ] else if (isEscalation) ...[
              for (final pt in points) _buildDangerPointTile(pt),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openSos,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.sos_rounded, size: 20),
                  label: const Text(
                    _kSosBtnLabel,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else ...[
              for (final pt in points) _buildFindingPointTile(pt),
            ],
            if (message.footnote != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow.withValues(
                    alpha: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  message.footnote!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _clock(message.at),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionStepTile(int stepNumber, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$stepNumber',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerPointTile(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onErrorContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingPointTile(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _extractPoints(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return const [];

    if (clean.contains('•') || clean.contains('\n-') || clean.contains('\n*')) {
      return clean
          .split('\n')
          .map((l) => l.replaceAll(RegExp(r'^[•\-\*\d\.\)]\s*'), '').trim())
          .where((l) => l.isNotEmpty)
          .toList();
    }

    final lines = clean
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length > 1) {
      return lines;
    }

    final sentences = clean
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return sentences.isNotEmpty ? sentences : [clean];
  }

  /// The app talking about itself. Centred, quieter, and never shaped like an
  /// assistant bubble, so a failure notice cannot read as clinical advice.
  Widget _systemLine(_Message message) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.92,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(
              alpha: 0.7,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  /// Static on purpose. An endlessly repeating animation here would make every
  /// widget test that settles the tree hang, and the word carries the meaning.
  Widget _typingBubble() {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.circle,
                  size: 6,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.35 + i * 0.2,
                  ),
                ),
              ),
            const AppSpacing.hxs(),
            Text(
              'writing…',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Only ever on screen for the moment the guideline corpus takes to load. The
  /// old spinner sat here for the whole Gemini round trip.
  Widget _openingState() {
    final theme = Theme.of(context);

    return AppCenteredScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_loadingBrief)
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
              strokeWidth: 3,
            ),
          const AppSpacing.vlg(),
          Text(
            _loadingBrief
                ? 'Reading the guidelines on this phone…'
                : 'Nothing to explain yet.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    final theme = Theme.of(context);
    final configured = ref.watch(geminiServiceProvider).isConfigured;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingSm,
            AppTheme.spacingSm,
            AppTheme.spacingSm,
            AppTheme.spacingSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_blockedQuestion != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.cloud_outlined, size: 18),
                    label: const Text('Allow online AI and send'),
                    onPressed: _allowAndResend,
                  ),
                ),
                const AppSpacing.vxs(),
              ],
              // The model's own suggested questions, made tappable. They used to
              // be printed in a list a worker had to retype from.
              if (_suggestions.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    children: [
                      for (final suggestion in _suggestions)
                        Padding(
                          padding: const EdgeInsets.only(
                            right: AppTheme.spacingSm,
                          ),
                          child: ActionChip(
                            label: Text(suggestion),
                            onPressed: _sending ? null : () => _ask(suggestion),
                          ),
                        ),
                    ],
                  ),
                ),
                const AppSpacing.vxs(),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _question,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        hintText: configured
                            ? 'Ask about this result…'
                            : 'Add an AI key in Settings to ask',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _sending ? null : _ask,
                    ),
                  ),
                  const AppSpacing.hsm(),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _sending ? null : () => _ask(_question.text),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
}
