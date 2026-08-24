import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/triage_result.dart';
import 'package:swasthyasetu_ai/domain/rules/ecg_classifier.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/features/screening/state/screening_draft.dart';
import 'package:uuid/uuid.dart';

/// The end of a screening: the band, why it was assigned, and — the part that
/// was missing — the record being written to the local database.
class TriageResultScreen extends ConsumerStatefulWidget {
  const TriageResultScreen({super.key});

  @override
  ConsumerState<TriageResultScreen> createState() => _TriageResultScreenState();
}

/// How the save went, so the screen can say so instead of implying success.
enum _SaveState { notApplicable, saving, saved, failed }

class _TriageResultScreenState extends ConsumerState<TriageResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _scoreController;
  late AnimationController _particleController;
  late AnimationController _ringController;

  late Animation<double> _entranceFade;
  late Animation<double> _ringProgress;

  TriageResult? _triageResult;
  Map<String, dynamic>? _extraData;

  /// Guards the write. `didChangeDependencies` fires again on every theme or
  /// text-scale change, and a screening that saved itself three times because
  /// the worker rotated the phone would be a data-integrity bug.
  bool _persistStarted = false;
  _SaveState _saveState = _SaveState.notApplicable;
  String? _saveError;
  String? _savedId;
  Patient? _patient;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _ringController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _entranceFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.6, curve: AppTheme.curveDecelerate)),
    );

    _ringProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ringController, curve: AppTheme.curveDecelerate),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _scoreController.dispose();
    _particleController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Two ways in. Normally the draft carries a real patient through from the
    // first step, and the band must be scored against *that* patient — an
    // 82-year-old's SpO2 of 92 is not the same finding as a 30-year-old's. The
    // route extra is the fallback for the demo walkthrough, which opens this
    // screen directly with nobody attached.
    final draft = ref.read(screeningDraftProvider);
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;

    if (draft.hasPatient && draft.sample != null) {
      _patient = draft.patient;
      _triageResult = RiskEngine.evaluateWithPatient(
        sample: draft.sample!,
        symptoms: draft.symptoms,
        patient: draft.patient!,
      );
      _extraData = {
        'sample': draft.sample!.toJson(),
        'symptoms': draft.symptoms,
        'duration': draft.symptomDuration,
        'notes': draft.symptomNotes,
        'patientId': draft.patient!.id,
        'patientName': draft.patient!.name,
      };

      if (!_persistStarted) {
        _persistStarted = true;
        _saveState = _SaveState.saving;
        // After the frame: this runs inside didChangeDependencies, where a
        // provider write would rebuild mid-build.
        WidgetsBinding.instance.addPostFrameCallback((_) => _persist(draft));
      }
    } else {
      _extraData = extra ?? _defaultDemoExtra();
      _triageResult = _generateDemoTriage(_extraData!);
      _saveState = _SaveState.notApplicable;
    }

    _mainController.forward();
    _ringController.forward();
    _scoreController.forward();
    _particleController.repeat();
  }

  /// Writes the screening — row, waveform blob, sync-queue entry — exactly once.
  ///
  /// This is the step the flow was missing entirely: every reading was displayed
  /// and then discarded, so patient history, the community dashboard and the
  /// sync queue all fed off seed data. The screen reports the outcome instead of
  /// showing a "Save & Exit" button that never saved anything.
  Future<void> _persist(ScreeningDraft draft) async {
    final result = _triageResult;
    final sample = draft.sample;
    final patient = draft.patient;
    if (result == null || sample == null || patient == null) return;

    // Already written on a previous visit to this screen (back-navigation).
    if (draft.isSaved) {
      if (mounted) {
        setState(() {
          _saveState = _SaveState.saved;
          _savedId = draft.savedScreeningId;
        });
      }
      return;
    }

    final id = const Uuid().v4();
    final settings = ref.read(settingsProvider);

    // Best-effort, and only with consent. Returns null on a cold GPS rather
    // than delaying the save — an untagged screening is fine, a lost one is not.
    final fix = await ref
        .read(locationServiceProvider)
        .currentFix(consented: settings.locationConsent);

    final screening = Screening(
      id: id,
      patientId: patient.id,
      deviceId: draft.deviceId,
      // HealthSample carries epoch millis; the screening row wants a DateTime.
      timestamp: draft.startedAt ??
          DateTime.fromMillisecondsSinceEpoch(sample.timestamp),
      heartRate: sample.heartRateBpm,
      spo2: sample.spo2Percent,
      temperature: sample.temperatureC,
      ecgRhythm: EcgClassifier.classify(
        heartRate: sample.heartRateBpm,
        quality: sample.ecgSignalQuality,
        rrIntervalMs: sample.rrIntervalMs,
      ),
      ecgQualityScore: sample.ecgSignalQuality,
      rrIntervalMs: sample.rrIntervalMs,
      pttMs: sample.pttMs,
      estimatedSystolic: sample.estimatedSystolic,
      estimatedDiastolic: sample.estimatedDiastolic,
      bpConfidence: sample.bpConfidence,
      symptoms: draft.symptoms,
      symptomDuration: draft.symptomDuration,
      symptomNotes: draft.symptomNotes,
      riskLevel: result.level,
      riskScore: result.score,
      triggeredRules: result.triggeredRules,
      recommendedAction: result.recommendedAction,
      escalationLevel: result.escalationLevel,
      // Location only when the worker consented, and only then. An unconsented
      // screening carries no coordinates at all rather than nulls-in-a-column.
      latitude: fix?.latitude,
      longitude: fix?.longitude,
      isDemo: draft.isDemoDevice,
    );

    try {
      await ref.read(screeningRepositoryProvider).save(
            screening,
            ecgSamples: draft.ecgSamples,
            ecgSampleRate: draft.ecgSampleRate,
          );
      ref.read(screeningDraftProvider.notifier).markSaved(id);
      if (!mounted) return;
      setState(() {
        _saveState = _SaveState.saved;
        _savedId = id;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saveState = _SaveState.failed;
        _saveError = error.toString();
      });
    }
  }

  Future<void> _retrySave() async {
    setState(() {
      _saveState = _SaveState.saving;
      _saveError = null;
    });
    await _persist(ref.read(screeningDraftProvider));
  }

  TriageResult _generateDemoTriage(Map<String, dynamic> extra) {
    final symptoms = extra['symptoms'] as List<String>? ?? [];
    final sampleJson = extra['sample'] as Map<String, dynamic>?;
    final sample = sampleJson != null
        ? HealthSample.fromJson(sampleJson)
        : HealthSample.demo(
            heartRateBpm: 108,
            spo2Percent: 94,
            temperatureC: 38.3,
            ecgSignalQuality: 0.88,
            rrIntervalMs: 556,
          );

    return RiskEngine.evaluate(sample: sample, symptoms: symptoms);
  }

  Map<String, dynamic> _defaultDemoExtra() {
    return {
      'sample': HealthSample.demo(
        heartRateBpm: 108,
        spo2Percent: 94,
        temperatureC: 38.3,
        ecgSignalQuality: 0.88,
        rrIntervalMs: 556,
      ).toJson(),
      'symptoms': ['Fever', 'Dizziness'],
      'duration': '1-3 days',
      'notes': 'Default demo screening opened directly.',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_triageResult == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final riskColor = AppTheme.getRiskColor(context, _triageResult!.level);
    final riskIcon = AppTheme.getRiskIcon(_triageResult!.level);
    final riskContainer = AppTheme.getRiskContainerColor(context, _triageResult!.level);
    final riskOnContainer = AppTheme.getRiskOnContainerColor(context, _triageResult!.level);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Triage Result'),
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (_triageResult!.isDemo)
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
      body: AnimatedBuilder(
        animation: _particleController,
        builder: (context, child) {
          return Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _TriageParticlePainter(
                  animationValue: _particleController.value,
                  color: riskColor,
                ),
              ),
              _buildContent(riskColor, riskIcon, riskContainer, riskOnContainer),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(Color riskColor, IconData riskIcon, Color containerColor, Color onContainerColor) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildRiskCard(riskColor, riskIcon, containerColor, onContainerColor)
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(duration: 600.ms, curve: AppTheme.curveDecelerate)
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), curve: AppTheme.curveSpring)
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildScoreCard(riskColor, containerColor, onContainerColor)
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(duration: 600.ms, delay: 200.ms, curve: AppTheme.curveDecelerate)
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildTriggeredRulesCard(riskColor, containerColor, onContainerColor)
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(duration: 600.ms, delay: 400.ms, curve: AppTheme.curveDecelerate)
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildVitalsSummaryCard()
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(duration: 600.ms, delay: 600.ms, curve: AppTheme.curveDecelerate)
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildSymptomsCard(riskColor, containerColor)
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(duration: 600.ms, delay: 800.ms, curve: AppTheme.curveDecelerate)
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildActionButtons(riskColor)
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(duration: 600.ms, delay: 1000.ms, curve: AppTheme.curveDecelerate)
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildDisclaimerCard()
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(duration: 600.ms, delay: 1200.ms, curve: AppTheme.curveDecelerate)
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              const AppSpacing.vxl(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRiskCard(Color riskColor, IconData riskIcon, Color containerColor, Color onContainerColor) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: AppCard(
        color: containerColor.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        border: BorderSide(color: riskColor.withValues(alpha: 0.3), width: 2),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_pulseController, _ringController]),
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: riskColor.withValues(alpha: 0.2 * _ringProgress.value),
                          width: 4,
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + _pulseController.value * 0.08,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  riskColor.withValues(alpha: 0.25),
                                  riskColor.withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: riskColor.withValues(alpha: 0.4 * (1 + _pulseController.value * 0.5)),
                                  blurRadius: 32,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(riskIcon, size: 64, color: riskColor),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            const AppSpacing.vlg(),
            AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Opacity(
                  opacity: _entranceFade.value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _entranceFade.value)),
                    child: Column(
                      children: [
                        // "NEEDS ATTENTION" in displayLarge with 3px letter
                        // spacing is far wider than a 360px screen at 2.0x text
                        // scale, so it scales down to fit rather than clipping.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            // Never the raw stored band. `_triageResult!.level`
                            // is the string `"RED"`, which is not a thing you
                            // show a worker standing in front of a patient.
                            RiskStyle.ofStorage(_triageResult!.level, context.l10n)
                                .label
                                .toUpperCase(),
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: riskColor,
                              letterSpacing: 3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const AppSpacing.vsm(),
                        Text(
                          _getLevelDescription(_triageResult!.level),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ); // return
              }, // builder
            ), // AnimatedBuilder
            const AppSpacing.vlg(),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    riskColor.withValues(alpha: 0.15),
                    riskColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: riskColor.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.medical_services_rounded, color: riskColor, size: 22),
                  const AppSpacing.hmd(),
                  Expanded(
                    child: Text(
                      _triageResult!.recommendedAction,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: riskColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            if (_triageResult!.isDemo) ...[
              const AppSpacing.vmd(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingXs),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  'Demo mode — simulated result',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(Color riskColor, Color containerColor, Color onContainerColor) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: AppElevatedCard(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_rounded, color: theme.colorScheme.primary, size: 22),
                const AppSpacing.hsm(),
                Expanded(
                  child: Text('Risk Score', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const AppSpacing.vlg(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _scoreController,
                        builder: (context, child) {
                          // displayLarge at 2x text scale is far wider than a
                          // third of a 360px screen, so the number scales down
                          // to fit rather than pushing the row apart.
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: AppAnimatedCounter(
                              value: (_triageResult!.score * _scoreController.value).round(),
                              duration: Duration.zero,
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: riskColor,
                              ),
                              suffix: ' / 100',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const AppSpacing.hlg(),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Wrap, not Row: at large text scales the label and the
                      // badge cannot share one line, and a `Flexible` here was
                      // being laid out against an unbounded height, which threw
                      // before it ever got a size.
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppTheme.spacingXs,
                        runSpacing: AppTheme.spacingXs,
                        children: [
                          Text(
                            'Escalation:',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          AppAnimatedBadge(
                            label: escalationLabel(
                              _triageResult!.escalationLevel,
                              context.l10n,
                            ),
                            color: riskColor,
                            backgroundColor: riskColor.withValues(alpha: 0.15),
                            textColor: riskColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                      const AppSpacing.vsm(),
                      AnimatedBuilder(
                        animation: _scoreController,
                        builder: (context, child) {
                          return AppLinearProgress(
                            value: (_triageResult!.score / 100) * _scoreController.value,
                            height: 12,
                            color: riskColor,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const AppSpacing.vmd(),
            _buildScoreThresholds(riskColor),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreThresholds(Color riskColor) {
    final theme = Theme.of(context);
    // Read from the engine, never restated here: the legend was hardcoded to
    // 0-39/40-69/70-100 while the engine bands at 30 and 60, so the screen told
    // the health worker a score of 35 was Green when it had been triaged Yellow.
    const greenMax = RiskEngine.greenMax;
    const yellowMax = RiskEngine.yellowMax;

    return AppStaggeredList(
      axis: Axis.horizontal,
      spacing: AppTheme.spacingMd,
      duration: AppTheme.durationMd,
      delay: const Duration(milliseconds: 80),
      children: [
        _buildThresholdItem('0-$greenMax', 'Green', theme.colorScheme.primary, _triageResult!.score <= greenMax),
        _buildThresholdItem('${greenMax + 1}-$yellowMax', 'Yellow', theme.colorScheme.tertiary, _triageResult!.score > greenMax && _triageResult!.score <= yellowMax),
        _buildThresholdItem('${yellowMax + 1}-100', 'Red', theme.colorScheme.error, _triageResult!.score > yellowMax),
      ],
    );
  }

  Widget _buildThresholdItem(String range, String label, Color color, bool isActive) {
    final theme = Theme.of(context);

    return Expanded(
      child: AnimatedContainer(
        duration: AppTheme.durationMd,
        curve: AppTheme.curveSpring,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: isActive ? Border.all(color: color, width: 2) : null,
          boxShadow: isActive ? [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
          ] : null,
        ),
        child: Column(
          children: [
            Text(range, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: isActive ? color : theme.colorScheme.onSurfaceVariant)),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: isActive ? color : theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggeredRulesCard(Color riskColor, Color containerColor, Color onContainerColor) {
    final theme = Theme.of(context);

    if (_triageResult!.triggeredRules.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
        child: AppCard(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 24),
              const AppSpacing.hmd(),
              Expanded(
                child: Text(
                  'No risk rules triggered. All vitals within normal screening thresholds.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: AppCard(
        color: containerColor.withValues(alpha: 0.2),
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        border: BorderSide(color: riskColor.withValues(alpha: 0.2), width: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_rounded, color: riskColor, size: 22),
                const AppSpacing.hsm(),
                Expanded(
                  child: Text('Triggered Rules', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: riskColor)),
                ),
              ],
            ),
            const AppSpacing.vmd(),
            AppStaggeredList(
              duration: AppTheme.durationMd,
              delay: const Duration(milliseconds: 80),
              children: _triageResult!.triggeredRules.asMap().entries.map((entry) {
                final index = entry.key;
                final rule = entry.value;
                return _buildRuleItem(rule, index, riskColor);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String rule, int index, Color riskColor) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: AppRippleEffect(
        color: riskColor.withValues(alpha: 0.1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: riskColor),
                ),
              ),
            ),
            const AppSpacing.hmd(),
            Expanded(
              child: Text(rule, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsSummaryCard() {
    final theme = Theme.of(context);
    final vitals = _triageResult!.vitals;

    final vitalItems = [
      _VitalSummaryItem('Heart Rate', '${vitals['heart_rate'] ?? 0} BPM', Icons.favorite_rounded, theme.colorScheme.primary, alert: (vitals['heart_rate'] ?? 0) > 100 || (vitals['heart_rate'] ?? 0) < 50),
      _VitalSummaryItem('SpO\u2082', '${vitals['spo2'] ?? 0}%', Icons.air_rounded, theme.colorScheme.secondary, alert: (vitals['spo2'] ?? 100) < 95),
      _VitalSummaryItem('Temperature', '${vitals['temperature'] ?? 0}\u00b0C', Icons.thermostat_rounded, theme.colorScheme.tertiary, alert: (vitals['temperature'] ?? 0) >= 38.0),
      if (vitals['ecg_quality'] != null)
        _VitalSummaryItem('ECG Quality', '${(vitals['ecg_quality'] * 100).round()}%', Icons.monitor_heart_rounded, theme.colorScheme.primary.withValues(alpha: 0.8), alert: (vitals['ecg_quality'] ?? 1.0) < 0.5),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: AppElevatedCard(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart_rounded, color: theme.colorScheme.primary, size: 22),
                const AppSpacing.hsm(),
                Expanded(
                  child: Text('Measured Vitals', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const AppSpacing.vlg(),
            AppStaggeredList(
              axis: Axis.horizontal,
              spacing: AppTheme.spacingMd,
              duration: AppTheme.durationMd,
              delay: const Duration(milliseconds: 80),
              children: vitalItems.map((item) => Expanded(child: _buildAnimatedVitalSummaryItem(item))).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedVitalSummaryItem(_VitalSummaryItem item) {
    final theme = Theme.of(context);
    final displayColor = item.alert ? theme.colorScheme.error : item.color;

    return AppRippleEffect(
      color: item.color.withValues(alpha: 0.2),
      child: Column(
        children: [
          AppPulseAnimation(
            minScale: 0.95,
            maxScale: 1.05,
            duration: const Duration(milliseconds: 1500),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(color: item.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
              child: Icon(item.icon, color: item.color, size: 28),
            ),
          ),
          const AppSpacing.vsm(),
          Text(item.value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: displayColor)),
          Text(item.label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          if (item.alert) ...[
            const AppSpacing.vxs(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
              decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
              child: Text('Out of range', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onErrorContainer)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSymptomsCard(Color riskColor, Color containerColor) {
    final theme = Theme.of(context);
    final symptoms = _triageResult!.symptoms;

    if (symptoms.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: AppCard(
        color: containerColor.withValues(alpha: 0.15),
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        border: BorderSide(color: riskColor.withValues(alpha: 0.2), width: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.healing_rounded, color: riskColor, size: 22),
                const AppSpacing.hsm(),
                Expanded(
                  child: Text('Reported Symptoms', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: riskColor)),
                ),
              ],
            ),
            const AppSpacing.vmd(),
            AppStaggeredList(
              duration: AppTheme.durationMd,
              delay: const Duration(milliseconds: 80),
              children: symptoms.asMap().entries.map((entry) {
                final index = entry.key;
                final symptom = entry.value;
                return Chip(
                  label: Text(symptom),
                  avatar: CircleAvatar(radius: 10, backgroundColor: riskColor.withValues(alpha: 0.2), child: Text('${index + 1}', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: riskColor, fontSize: 10))),
                  backgroundColor: riskColor.withValues(alpha: 0.1),
                  labelStyle: TextStyle(color: riskColor, fontWeight: FontWeight.w500),
                  side: BorderSide(color: riskColor.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Color riskColor) {
    final theme = Theme.of(context);
    final band = RiskBand.fromStorage(_triageResult!.level);
    final settings = ref.watch(settingsProvider);

    // The escalation the whole app exists for. Offered — never sent — because
    // the worker is the one who can see the patient; the SOS screen still holds
    // its own cancel window on top of this.
    final offerSos = band == RiskBand.red && settings.autoSuggestSos;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Column(
        children: [
          if (offerSos) ...[
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Send emergency SOS',
                icon: const Icon(Icons.sos_rounded),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                ),
                onPressed: _openSos,
              ),
            ),
            const AppSpacing.vsm(),
            Text(
              'You will get ${settings.sosCountdownSeconds} seconds to cancel '
              'before anything is sent.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const AppSpacing.vmd(),
          ],
          // Wrap, not Row: two buttons with icons and full labels cannot share
          // one 360px line at 2.0x text scale.
          Row(
            children: [
              Expanded(
                child: AppOutlinedButton(
                  label: 'Explain this',
                  icon: const Icon(Icons.psychology_rounded),
                  // The saved id travels with it so the explanation can be
                  // cached against the row instead of regenerated every visit.
                  onPressed: () => context.go(
                    '/screening/ai-explanation',
                    extra: {
                      ...?_extraData,
                      if (_savedId != null) 'screeningId': _savedId,
                    },
                  ),
                  borderColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: AppButton(
                  // Named for what it does. The record is written the moment
                  // this screen opens; this button only leaves.
                  label: _saveState == _SaveState.notApplicable
                      ? 'Finish'
                      : 'Done',
                  icon: const Icon(Icons.check_rounded),
                  onPressed: _finish,
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          _buildSaveStatus(),
        ],
      ),
    );
  }

  void _openSos() {
    final query = <String, String>{
      'trigger': SosTrigger.highRisk.storageValue,
      if (_patient != null) 'patientId': _patient!.id,
      if (_savedId != null) 'screeningId': _savedId!,
    };
    context.push(
      Uri(path: '/emergency/sos', queryParameters: query).toString(),
    );
  }

  void _finish() {
    // The draft is cleared on the way out so the next household visit starts
    // empty. Leaving it would carry this patient's symptoms into the next one.
    ref.read(screeningDraftProvider.notifier).clear();
    context.go('/home');
  }

  /// Says plainly whether the record reached the database.
  ///
  /// A screening app that silently drops a reading is worse than one that admits
  /// it, because the worker walks away believing the visit is on file.
  Widget _buildSaveStatus() {
    final theme = Theme.of(context);

    return switch (_saveState) {
      _SaveState.notApplicable => const SizedBox.shrink(),
      _SaveState.saving => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const AppSpacing.hsm(),
            Flexible(
              child: Text(
                'Saving to this phone…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      _SaveState.saved => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: AppTheme.riskGreen,
            ),
            const AppSpacing.hsm(),
            Flexible(
              child: Text(
                _patient == null
                    ? 'Saved on this phone'
                    : 'Saved to ${_patient!.name}’s record. Will upload when '
                        'there is a connection.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      _SaveState.failed => AppCard(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const AppSpacing.hsm(),
                  Expanded(
                    child: Text(
                      'This screening was NOT saved. Retry before leaving, or '
                      'the reading is lost.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
              if (_saveError != null) ...[
                const AppSpacing.vxs(),
                Text(
                  _saveError!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const AppSpacing.vsm(),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _retrySave,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry save'),
                ),
              ),
            ],
          ),
        ),
    };
  }

  Widget _buildDisclaimerCard() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: AppCard(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.15),
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        border: BorderSide(color: theme.colorScheme.tertiary.withValues(alpha: 0.3), width: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: theme.colorScheme.tertiary, size: 20),
            const AppSpacing.hmd(),
            Expanded(
              child: Text(
                'This is a screening/triage assessment tool, NOT a medical diagnosis. Results should be reviewed by a qualified healthcare professional. The risk level is determined by deterministic rules, not AI.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLevelDescription(String level) {
    switch (level.toUpperCase()) {
      case 'RED': case 'URGENT': case 'HIGH': return 'HIGH RISK - Immediate Attention Required';
      case 'YELLOW': case 'AMBER': case 'ATTENTION': case 'MEDIUM': return 'MODERATE RISK - Clinical Review Recommended';
      case 'GREEN': case 'LOW': case 'NORMAL': return 'LOW RISK - Routine Monitoring';
      default: return 'Unknown Risk Level';
    }
  }
}

class _VitalSummaryItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool alert;

  _VitalSummaryItem(this.label, this.value, this.icon, this.color, {this.alert = false});
}

class _TriageParticlePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _TriageParticlePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 15; i++) {
      final x = (i * 0.3 + animationValue * 0.2) % 1.2;
      final y = (i * 0.2 + animationValue * 0.15) % 1.1;
      final opacity = (1.0 - (animationValue + i * 0.05) % 1.0) * 0.15;

      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x * size.width, y * size.height), 3 + (i % 3) * 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _TriageParticlePainter && oldDelegate.animationValue != animationValue;
  }
}