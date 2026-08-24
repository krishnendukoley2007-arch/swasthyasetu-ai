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
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
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

  /// Offline first, online second, and nothing blocking on the network.
  Future<void> _start({bool refresh = false}) async {
    final assessment = _assessment;
    if (assessment == null) return;

    final settings = ref.read(settingsProvider);
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
      shown = await _attempt(() => repo.cached(id));
    }

    shown ??= await _attempt(
      () => repo.explainOffline(
        assessment: assessment,
        screeningId: _screeningId,
        patientName: _patientName,
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
            text: 'The written explanation could not be built on this phone. '
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
    final canUpgrade = settings.aiConsent &&
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

    final sections = <(String, String, _Tone?)>[
      ('What this reading showed', explanation.summary, null),
      ('Why this level', explanation.whyThisLevel, null),
      ('What to do now', explanation.safeNextSteps, null),
      ('Go immediately if', explanation.whenToEscalate, _Tone.danger),
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
        _Message(
          author: _Author.system,
          text: notes.join('\n\n'),
          at: now,
        ),
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
      ExplanationSource.gemini => 'Explained online by ${GeminiService.model}'
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
      setState(() {
        _sending = false;
        _blockedQuestion = text;
        _chat.add(
          _Message(
            author: _Author.system,
            text: 'Online AI is switched off, so nothing left this phone. The '
                'explanation above did not need it.',
            at: DateTime.now(),
          ),
        );
      });
      _scrollToEnd();
      return;
    }

    setState(() => _typing = true);
    _scrollToEnd();

    final answer = await _attempt(
      () => ref.read(explanationRepositoryProvider).answerQuestion(
            assessment: assessment,
            question: text,
          ),
    );

    if (!mounted) return;
    setState(() {
      _typing = false;
      _sending = false;
      final trimmed = answer?.trim() ?? '';
      _chat.add(
        trimmed.isNotEmpty
            // Null is the designed offline answer, not a crash: a free-text
            // clinical question is never answered from a template. But *why* it
            // failed decides what the worker should do next, so read it off the
            // service instead of always blaming the connection — a rejected key
            // looked identical to no signal, and sent people hunting for bars
            // they already had.
            ? _Message(
                author: _Author.assistant,
                text: trimmed,
                at: DateTime.now(),
                footnote: 'Answered online by ${GeminiService.model}',
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
    context.push(Uri(path: '/emergency/sos', queryParameters: query).toString());
  }

  @override
  Widget build(BuildContext context) {
    final assessment = _assessment;
    final messages = <_Message>[..._brief, ..._chat];
    // Red bands offer the SOS on the result screen. This screen opens on top of
    // that one automatically, so it has to carry the same affordance or the
    // convenience would have cost a worker the emergency button.
    final offerSos = assessment?.band == RiskBand.red &&
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
                    itemCount: messages.length + (_typing ? 1 : 0),
                    itemBuilder: (context, index) => index < messages.length
                        ? _bubble(messages[index])
                        : _typingBubble(),
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
  }) {
    final theme = Theme.of(context);

    return Container(
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
  }

  Widget _bubble(_Message message) {
    if (message.author == _Author.system) return _systemLine(message);

    final theme = Theme.of(context);
    final mine = message.author == _Author.worker;
    final danger = message.tone == _Tone.danger;

    final background = mine
        ? theme.colorScheme.primaryContainer
        : danger
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.6)
            : theme.colorScheme.surfaceContainerHighest;
    final foreground = mine
        ? theme.colorScheme.onPrimaryContainer
        : danger
            ? theme.colorScheme.onErrorContainer
            : theme.colorScheme.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.heading != null) ...[
                Text(
                  message.heading!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: danger
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              // bodyLarge, not bodyMedium: this is the text a worker reads
              // standing in a doorway, and the old bodyMedium at 1.6 line
              // height was the readability complaint.
              Text(
                message.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: foreground,
                  height: 1.45,
                ),
              ),
              if (message.footnote != null) ...[
                const SizedBox(height: 6),
                Text(
                  message.footnote!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground.withValues(alpha: 0.75),
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _clock(message.at),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
