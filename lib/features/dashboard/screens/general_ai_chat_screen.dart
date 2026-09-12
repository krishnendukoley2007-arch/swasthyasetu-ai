import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/gemini_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:swasthyasetu_ai/domain/rules/offline_explainer.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';

enum _Author { assistant, worker, system }

@immutable
class _Message {
  const _Message({
    required this.author,
    required this.text,
    required this.at,
    this.footnote,
  });

  final _Author author;
  final String text;
  final DateTime at;
  final String? footnote;
}

class GeneralAiChatScreen extends ConsumerStatefulWidget {
  const GeneralAiChatScreen({super.key});

  @override
  ConsumerState<GeneralAiChatScreen> createState() =>
      _GeneralAiChatScreenState();
}

class _GeneralAiChatScreenState extends ConsumerState<GeneralAiChatScreen> {
  final List<_Message> _chat = [];
  bool _typing = false;
  bool _sending = false;
  String? _blockedQuestion;

  final TextEditingController _question = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _grounded = false;

  /// Ground the answer in what this phone actually knows. Facts only — the
  /// prompt instructs the model to treat these as context, never as
  /// instructions, and not to invent details beyond them.
  String? _contextBlock() {
    final account = ref.read(authStateProvider).account;
    if (account == null) return null;

    final buf = StringBuffer();
    final isPatient = account.role == UserRole.patient;
    if (isPatient) {
      buf.writeln('Asker: patient, ${account.displayName}.');
      if (account.age != null) buf.write('Age ${account.age} yrs');
      if (account.sex.isNotEmpty) buf.write(', sex ${account.sex}');
      if (account.heightCm != null) {
        buf.write(', height ${account.heightCm!.toStringAsFixed(0)} cm');
      }
      if (account.weightKg != null) {
        buf.write(', weight ${account.weightKg!.toStringAsFixed(1)} kg');
      }
      final bmi = account.bmi;
      if (bmi != null) {
        final band = account.bmiBand != null ? ' (${account.bmiBand})' : '';
        buf.write(', BMI ${bmi.toStringAsFixed(1)}$band');
      }
      if (buf.length > 30 && !buf.toString().endsWith('\n')) buf.writeln('.');
      if (account.conditions.isNotEmpty) {
        buf.writeln('Known conditions: ${account.conditions.join(', ')}.');
      }
      if (account.problems != null && account.problems!.trim().isNotEmpty) {
        buf.writeln('Reported complaints: "${account.problems!.trim()}".');
      }
    }

    final screenings = isPatient
        ? (account.patientId == null
              ? null
              : ref
                    .read(patientScreeningsProvider(account.patientId!))
                    .valueOrNull)
        : ref.read(recentScreeningsProvider).valueOrNull;
    final latest = (screenings == null || screenings.isEmpty)
        ? null
        : screenings.first;

    if (latest != null) {
      final whose = isPatient
          ? 'the patient'
          : (ref.read(patientNamesProvider)[latest.patientId] ?? 'a patient');
      buf.writeln(
        'Latest screening of $whose (${relativeTime(latest.timestamp)}): '
        'HR ${latest.heartRate} bpm, SpO2 ${latest.spo2}%, '
        'temp ${latest.temperature.toStringAsFixed(1)}°C, '
        'risk band ${latest.riskLevel}, score ${latest.riskScore}/100'
        '${latest.symptoms.isEmpty ? '' : '; symptoms: ${latest.symptoms.join(', ')}'}.',
      );
    }

    if (!isPatient) {
      buf.writeln('The asker is a community health worker.');
    }

    final out = buf.toString().trim();
    return out.isEmpty ? null : out;
  }

  @override
  void initState() {
    super.initState();
    _chat.add(
      _Message(
        author: _Author.assistant,
        text:
            'Hi! I am the SwasthyaSetu AI assistant. How can I help you today?',
        at: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;

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
      final account = ref.read(authStateProvider).account;
      Screening? latest;
      if (account != null) {
        final list = account.role == UserRole.patient
            ? (account.patientId == null
                  ? const <Screening>[]
                  : ref
                            .read(patientScreeningsProvider(account.patientId!))
                            .valueOrNull ??
                        const <Screening>[])
            : ref.read(recentScreeningsProvider).valueOrNull ??
                  const <Screening>[];
        if (list.isNotEmpty) latest = list.first;
      }
      setState(() {
        _sending = false;
        _chat.add(
          _Message(
            author: _Author.assistant,
            text: OfflineExplainer.chatFallback(
              latest: latest,
              grounded: false,
              question: text,
            ),
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

    final ctx = _contextBlock();
    _grounded = ctx != null;
    final answer = await ref
        .read(geminiServiceProvider)
        .generalChat(
          question: text,
          audience: ref.read(effectiveAudienceProvider),
          languageCode: ref.read(settingsProvider).locale.languageCode,
          contextBlock: ctx,
        );

    if (!mounted) return;
    setState(() {
      _typing = false;
      _sending = false;
      final trimmed = answer?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        _chat.add(
          _Message(
            author: _Author.assistant,
            text: trimmed,
            at: DateTime.now(),
            footnote:
                'Answered online by ${GeminiService.model}${_grounded ? ' · grounded in the latest screening' : ''}',
          ),
        );
      } else {
        // Online tier fell through. The on-device fallback only does
        // structured triage explanations; for an open question, give a
        // neutral, non-misleading note that names what the phone does know
        // (the latest screening, if any) and points at a clinician.
        final account = ref.read(authStateProvider).account;
        Screening? latest;
        if (account != null) {
          final list = account.role == UserRole.patient
              ? (account.patientId == null
                    ? const <Screening>[]
                    : ref
                              .read(
                                patientScreeningsProvider(account.patientId!),
                              )
                              .valueOrNull ??
                          const <Screening>[])
              : ref.read(recentScreeningsProvider).valueOrNull ??
                    const <Screening>[];
          if (list.isNotEmpty) latest = list.first;
        }
        _chat.add(
          _Message(
            author: _Author.assistant,
            text: OfflineExplainer.chatFallback(
              latest: latest,
              grounded: _grounded,
              question: text,
            ),
            at: DateTime.now(),
            footnote: 'Offline fallback · no online answer came back',
          ),
        );
      }
    });
    _scrollToEnd();
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

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('SwasthyaSetu AI'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingMd,
                AppTheme.spacingMd,
                AppTheme.spacingMd,
                AppTheme.spacingSm,
              ),
              itemCount: _chat.length + (_typing ? 1 : 0),
              itemBuilder: (context, index) => index < _chat.length
                  ? _bubble(_chat[index])
                  : _typingBubble(),
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _bubble(_Message message) {
    if (message.author == _Author.system) return _systemLine(message);

    final theme = Theme.of(context);
    final mine = message.author == _Author.worker;

    final background = mine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surface;
    final foreground = mine
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(mine ? 20 : 4),
              bottomRight: Radius.circular(mine ? 4 : 20),
            ),
            boxShadow: mine ? null : AppTheme.shadowLevel1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _typingBubble() {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: AppTheme.shadowLevel1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    final theme = Theme.of(context);
    final hasKey = ref.watch(geminiServiceProvider).isConfigured;

    if (!hasKey) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        color: theme.colorScheme.surfaceContainer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.key_off_rounded,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const AppSpacing.vsm(),
            Text(
              'No AI key entered',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const AppSpacing.vxs(),
            Text(
              'General chat requires a Gemini API key. Add it in Settings.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const AppSpacing.vmd(),
            FilledButton.tonal(
              onPressed: () => context.push('/settings'),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    if (_blockedQuestion != null) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        color: theme.colorScheme.surfaceContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Consent required',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const AppSpacing.vxs(),
            Text(
              'Sending questions requires your consent to use the internet.',
              style: theme.textTheme.bodyMedium,
            ),
            const AppSpacing.vmd(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _blockedQuestion = null),
                    child: const Text('Cancel'),
                  ),
                ),
                const AppSpacing.hmd(),
                Expanded(
                  child: FilledButton(
                    onPressed: _allowAndResend,
                    child: const Text('Allow & Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingXs,
        AppTheme.spacingMd,
        AppTheme.spacingLg,
      ),
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _question,
                decoration: InputDecoration(
                  hintText: 'Ask a medical question...',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLg,
                    vertical: AppTheme.spacingMd,
                  ),
                ),
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: _sending ? null : _ask,
              ),
            ),
            const AppSpacing.hsm(),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _question,
              builder: (context, value, child) {
                final canSend = value.text.trim().isNotEmpty && !_sending;
                return IconButton.filled(
                  icon: _sending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  onPressed: canSend ? () => _ask(_question.text) : null,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    disabledBackgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.all(12),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
