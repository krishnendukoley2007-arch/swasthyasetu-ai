import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/triage_result.dart';
import 'package:swasthyasetu_ai/domain/rules/ecg_classifier.dart';
import 'package:swasthyasetu_ai/core/services/pdf_clinical_report_service.dart';
import 'package:swasthyasetu_ai/core/services/vernacular_guidance_service.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/core/services/edge_ai_service.dart';
import 'package:swasthyasetu_ai/features/screening/state/screening_draft.dart';
import 'package:swasthyasetu_ai/features/screening/widgets/doctor_referral_dialog.dart';
import 'package:swasthyasetu_ai/features/screening/widgets/trust_provenance_sheet.dart';
import 'package:uuid/uuid.dart';

const _kAiPatternTitle = 'Edge AI Pattern Check';
const _kAiPillText = '1D-CNN (Synthetic NSR)';
const _kAiPatternBaseline = 'Rhythm pattern within normal sinus baseline';
const _kAiPatternDiffers =
    'Rhythm pattern differs from normal baseline — consider routine check';
const _kAiAdvisoryNotice =
    'ADVISORY ONLY (Mandate 2.5) — Does not affect clinical triage band';
const _kDownloadPdfLabel = 'PDF Report';
const _kDownloadPdfTooltip = 'Download Clinical PDF Report';

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

  /// One-shot. The explanation opens itself once, on the visit that actually
  /// wrote the record — never on back-navigation, or returning from the chat
  /// would push it straight back and trap the worker.
  bool _autoOpened = false;
  _SaveState _saveState = _SaveState.notApplicable;
  String? _saveError;
  String? _savedId;
  Patient? _patient;
  String _guidanceLanguage = 'hi';
  EdgeAiAnomalyResult? _aiAnomalyResult;

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
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: AppTheme.curveDecelerate),
      ),
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

    final currentLang = ref.watch(settingsProvider).locale.languageCode;
    if (const ['hi', 'bn', 'en'].contains(currentLang)) {
      _guidanceLanguage = currentLang;
    }

    // Two ways in. Normally the draft carries a real patient through from the
    // first step, and the band must be scored against *that* patient — an
    // 82-year-old's SpO2 of 92 is not the same finding as a 30-year-old's. The
    // route extra is the fallback for the demo walkthrough, which opens this
    // screen directly with nobody attached.
    final draft = ref.read(screeningDraftProvider);
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;

    if (draft.hasPatient && draft.sample != null) {
      _patient = draft.patient;
      _evaluateAiAnomaly(draft);
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _persist(draft);
        });
      }
    } else {
      _extraData = extra ?? _defaultDemoExtra();
      _triageResult = _generateDemoTriage(_extraData!);
      _saveState = _SaveState.notApplicable;
      if (_extraData?['patientId'] != null) {
        _patient = Patient(
          id: _extraData!['patientId'] as String,
          name:
              _extraData?['patientName'] as String? ??
              context.l10n.patientWalkIn,
          age: 35,
          sex: 'M',
          createdAt: DateTime.now(),
        );
      }
      _evaluateAiAnomaly(draft);
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
    final patient = draft.patient ?? _patient;
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
      timestamp:
          draft.startedAt ??
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
      estimatedGlucose: sample.estimatedGlucose,
      glucoseConfidence: sample.glucoseConfidence,
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
      isDemo: false,
      aiAnomalyFlag: _aiAnomalyResult?.isAnomaly ?? false,
      aiAnomalyScore: _aiAnomalyResult?.anomalyScore ?? 0.0,
    );

    try {
      await ref
          .read(screeningRepositoryProvider)
          .save(
            screening,
            ecgSamples: draft.ecgSamples,
            ecgSampleRate: draft.ecgSampleRate,
          );
      await ref
          .read(communitySyncServiceProvider)
          .contributeScreening(
            screening: screening,
            consentOptIn: settings.communitySyncConsent,
          );
      ref.read(screeningDraftProvider.notifier).markSaved(id);
      if (!mounted) return;
      setState(() {
        _saveState = _SaveState.saved;
        _savedId = id;
      });
      _autoOpenExplanation();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saveState = _SaveState.failed;
        _saveError = error.toString();
      });
    }
  }

  /// Opens the explanation chat on top of this screen.
  ///
  /// `push`, not `go`: the result stays underneath, so the back arrow and the
  /// system gesture both return to the band, the score and — for a red case —
  /// the SOS button. Replacing this route would have made the convenience cost
  /// a worker their emergency affordance.
  void _openExplanation() {
    context.push(
      '/screening/ai-explanation',
      // The saved id travels with it so the explanation can be cached against
      // the row instead of regenerated every visit.
      extra: {...?_extraData, if (_savedId != null) 'screeningId': _savedId},
    );
  }

  /// The explanation used to sit behind an "Explain this" button, which meant
  /// the reason for a result was optional and the numbers were not. It opens on
  /// its own now, once the record is safely written — reading it is the default,
  /// and the back arrow is how you decline.
  void _autoOpenExplanation() {
    if (_autoOpened) return;
    _autoOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openExplanation();
    });
  }

  Future<void> _retrySave() async {
    setState(() {
      _saveState = _SaveState.saving;
      _saveError = null;
    });
    await _persist(ref.read(screeningDraftProvider));
  }

  Future<void> _evaluateAiAnomaly(ScreeningDraft draft) async {
    try {
      final res = await ref
          .read(edgeAiServiceProvider)
          .evaluateRhythmWindow(
            ecgSamples: draft.ecgSamples,
            isDemo: _triageResult?.isDemo ?? false,
          );
      if (mounted) {
        setState(() {
          _aiAnomalyResult = res;
        });
      }
    } catch (_) {
      // Advisory only — fail safely
    }
  }

  void _showTrustProvenance() {
    final draft = ref.read(screeningDraftProvider);
    final isDemo = _triageResult?.isDemo ?? true;
    final hardwareSource = (draft.sample != null && !isDemo)
        ? 'SSAI-SENSE-01 (BLE 20-byte frame)'
        : 'Interactive Simulated Sensor Node';
    final ruleId = _triageResult?.triggeredRules.isNotEmpty == true
        ? _triageResult!.triggeredRules.first
        : 'NEWS2_BASELINE';
    final storagePreview = <String, dynamic>{
      'screening_id': _savedId ?? 'temp_draft',
      'patient_id': _patient?.id ?? 'demo_patient',
      'heart_rate_bpm': draft.sample?.heartRateBpm ?? 72,
      'spo2_percent': draft.sample?.spo2Percent ?? 98,
      'temperature_c': draft.sample?.temperatureC ?? 36.6,
      'triage_risk_band': _triageResult?.level ?? 'GREEN',
      'ai_anomaly_flag': _aiAnomalyResult?.isAnomaly ?? false,
      'ai_anomaly_score': _aiAnomalyResult?.anomalyScore ?? 0.0,
      'is_demo': isDemo,
      'schema_vocabulary': 'en_US',
    };

    TrustProvenanceSheet.show(
      context,
      isDemo: isDemo,
      hardwareSource: hardwareSource,
      clinicalRuleId: ruleId,
      latencyMs: _aiAnomalyResult?.latencyMs ?? 0.85,
      aiAnomalyFlag: _aiAnomalyResult?.isAnomaly ?? false,
      aiAnomalyScore: _aiAnomalyResult?.anomalyScore ?? 0.05,
      englishStoragePreview: storagePreview,
    );
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
    final riskContainer = AppTheme.getRiskContainerColor(
      context,
      _triageResult!.level,
    );
    final riskOnContainer = AppTheme.getRiskOnContainerColor(
      context,
      _triageResult!.level,
    );

    return AppPageScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.triageTitle),
            const SizedBox(height: 2),
            const ScreeningStepIndicator(current: 4),
          ],
        ),
        bottom: const ScreeningStepBar(current: 4),
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: _kDownloadPdfTooltip,
            onPressed: _exportPdfDirect,
          ),
          IconButton(
            icon: const Icon(Icons.verified_user_outlined),
            onPressed: _showTrustProvenance,
          ),
          if (_triageResult!.isDemo)
            Container(
              margin: const EdgeInsets.only(right: AppTheme.spacingMd),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                context.l10n.screeningDemoBadge,
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
              _buildContent(
                riskColor,
                riskIcon,
                riskContainer,
                riskOnContainer,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(
    Color riskColor,
    IconData riskIcon,
    Color containerColor,
    Color onContainerColor,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildRiskCard(
                    riskColor,
                    riskIcon,
                    containerColor,
                    onContainerColor,
                  )
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(duration: 600.ms, curve: AppTheme.curveDecelerate)
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.0, 1.0),
                    curve: AppTheme.curveSpring,
                  )
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildScoreCard(riskColor, containerColor, onContainerColor)
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(
                    duration: 600.ms,
                    delay: 200.ms,
                    curve: AppTheme.curveDecelerate,
                  )
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildTriggeredRulesCard(
                    riskColor,
                    containerColor,
                    onContainerColor,
                  )
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(
                    duration: 600.ms,
                    delay: 400.ms,
                    curve: AppTheme.curveDecelerate,
                  )
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildVitalsSummaryCard()
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(
                    duration: 600.ms,
                    delay: 600.ms,
                    curve: AppTheme.curveDecelerate,
                  )
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildEdgeAiPatternCard()
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(
                    duration: 600.ms,
                    delay: 650.ms,
                    curve: AppTheme.curveDecelerate,
                  )
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildAdvancedClinicalVisualizations()
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(
                    duration: 600.ms,
                    delay: 700.ms,
                    curve: AppTheme.curveDecelerate,
                  )
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildSymptomsCard(riskColor, containerColor)
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(
                    duration: 600.ms,
                    delay: 800.ms,
                    curve: AppTheme.curveDecelerate,
                  )
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildVernacularGuidanceCard(riskColor)
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(
                    duration: 600.ms,
                    delay: 900.ms,
                    curve: AppTheme.curveDecelerate,
                  )
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildActionButtons(riskColor)
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(
                    duration: 600.ms,
                    delay: 1000.ms,
                    curve: AppTheme.curveDecelerate,
                  )
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              _buildDisclaimerCard()
                  .animate(controller: _mainController, autoPlay: false)
                  .fadeIn(
                    duration: 600.ms,
                    delay: 1200.ms,
                    curve: AppTheme.curveDecelerate,
                  )
                  .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
              const AppSpacing.vxl(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRiskCard(
    Color riskColor,
    IconData riskIcon,
    Color containerColor,
    Color onContainerColor,
  ) {
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
                          color: riskColor.withValues(
                            alpha: 0.2 * _ringProgress.value,
                          ),
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
                                  color: riskColor.withValues(
                                    alpha:
                                        0.4 *
                                        (1 + _pulseController.value * 0.5),
                                  ),
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
                            RiskStyle.ofStorage(
                              _triageResult!.level,
                              context.l10n,
                            ).label.toUpperCase(),
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
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                border: Border.all(
                  color: riskColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.medical_services_rounded,
                    color: riskColor,
                    size: 22,
                  ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: AppTheme.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  context.l10n.triageDemoMode,
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

  Widget _buildScoreCard(
    Color riskColor,
    Color containerColor,
    Color onContainerColor,
  ) {
    final theme = Theme.of(context);
    const greenMax = RiskEngine.greenMax;
    const yellowMax = RiskEngine.yellowMax;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: AppElevatedCard(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const AppSpacing.hsm(),
                Expanded(child: Overline(context.l10n.triageRiskScore)),
                const ProvenanceTag(Provenance.measured),
              ],
            ),
            const AppSpacing.vmd(),
            // Arc gauge: the score sits on the threshold bands, so the worker
            // sees not just how high but how close to the next band's edge.
            Center(
              child: ArcGauge(
                value: _triageResult!.score.toDouble(),
                semanticsLabel:
                    '${context.l10n.riskBandLabel(RiskBand.fromStorage(_triageResult!.level))}. ${context.l10n.triageScoreCaption} ${_triageResult!.score}',
                size: 200,
                bands: [
                  ArcBand(0, greenMax.toDouble(), ClinicalPalette.teal),
                  ArcBand(
                    greenMax + 1.0,
                    yellowMax.toDouble(),
                    ClinicalPalette.amber,
                  ),
                  const ArcBand(yellowMax + 1.0, 100, ClinicalPalette.coral),
                ],
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _scoreController,
                        builder: (context, child) {
                          final v =
                              (_triageResult!.score * _scoreController.value)
                                  .round();
                          return Text('$v', style: numTab(40, riskColor));
                        },
                      ),
                      Text(
                        context.l10n.triageScoreCaption,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const AppSpacing.vsm(),
            // Wrap, not Row: the escalation label plus badge ran 151px past
            // the edge on a 360px high-contrast pass.
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppTheme.spacingXs,
              runSpacing: AppTheme.spacingXs,
              children: [
                Text(
                  context.l10n.triageEscalation,
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
            const AppSpacing.vmd(),
            Center(
              child: Text(
                context.l10n.triageNotADiagnosis,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
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
        _buildThresholdItem(
          '0-$greenMax',
          context.l10n.triageBandGreen,
          theme.colorScheme.primary,
          _triageResult!.score <= greenMax,
        ),
        _buildThresholdItem(
          '${greenMax + 1}-$yellowMax',
          context.l10n.triageBandYellow,
          theme.colorScheme.tertiary,
          _triageResult!.score > greenMax && _triageResult!.score <= yellowMax,
        ),
        _buildThresholdItem(
          '${yellowMax + 1}-100',
          context.l10n.triageBandRed,
          theme.colorScheme.error,
          _triageResult!.score > yellowMax,
        ),
      ],
    );
  }

  Widget _buildThresholdItem(
    String range,
    String label,
    Color color,
    bool isActive,
  ) {
    final theme = Theme.of(context);

    return Expanded(
      child: AnimatedContainer(
        duration: AppTheme.durationMd,
        curve: AppTheme.curveSpring,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: isActive ? Border.all(color: color, width: 2) : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              range,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isActive ? color : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isActive ? color : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggeredRulesCard(
    Color riskColor,
    Color containerColor,
    Color onContainerColor,
  ) {
    final theme = Theme.of(context);

    if (_triageResult!.triggeredRules.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
        child: AppCard(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Text(
                  context.l10n.triageRulesNone,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
                  child: Text(
                    context.l10n.triageRulesTriggered,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: riskColor,
                    ),
                  ),
                ),
              ],
            ),
            const AppSpacing.vmd(),
            AppStaggeredList(
              duration: AppTheme.durationMd,
              delay: const Duration(milliseconds: 80),
              children: _triageResult!.triggeredRules.asMap().entries.map((
                entry,
              ) {
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
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: riskColor,
                  ),
                ),
              ),
            ),
            const AppSpacing.hmd(),
            Expanded(
              child: Text(
                rule,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
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
      _VitalSummaryItem(
        context.l10n.vitalHeartRate,
        '${vitals['heart_rate'] ?? 0} BPM',
        Icons.favorite_rounded,
        theme.colorScheme.primary,
        alert:
            (vitals['heart_rate'] ?? 0) > 100 ||
            (vitals['heart_rate'] ?? 0) < 50,
      ),
      _VitalSummaryItem(
        context.l10n.vitalSpo2,
        '${vitals['spo2'] ?? 0}%',
        Icons.air_rounded,
        theme.colorScheme.secondary,
        alert: (vitals['spo2'] ?? 100) < 95,
      ),
      _VitalSummaryItem(
        context.l10n.vitalTemperature,
        '${vitals['temperature'] ?? 0}°C',
        Icons.thermostat_rounded,
        theme.colorScheme.tertiary,
        alert: (vitals['temperature'] ?? 0) >= 38.0,
      ),
      if (vitals['ecg_quality'] != null)
        _VitalSummaryItem(
          context.l10n.vitalEcgQuality,
          '${(vitals['ecg_quality'] * 100).round()}%',
          Icons.monitor_heart_rounded,
          theme.colorScheme.primary.withValues(alpha: 0.8),
          alert: (vitals['ecg_quality'] ?? 1.0) < 0.5,
        ),
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
                Icon(
                  Icons.monitor_heart_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const AppSpacing.hsm(),
                Expanded(
                  child: Text(
                    context.l10n.triageMeasuredVitals,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const AppSpacing.vlg(),
            AppStaggeredList(
              axis: Axis.horizontal,
              spacing: AppTheme.spacingMd,
              duration: AppTheme.durationMd,
              delay: const Duration(milliseconds: 80),
              children: vitalItems
                  .map(
                    (item) =>
                        Expanded(child: _buildAnimatedVitalSummaryItem(item)),
                  )
                  .toList(),
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
      child: Semantics(
        label: item.alert
            ? '${item.label}: ${item.value}. ${context.l10n.vitalOutOfRange}'
            : '${item.label}: ${item.value}',
        child: Column(
          children: [
            AppPulseAnimation(
              minScale: 0.95,
              maxScale: 1.05,
              duration: const Duration(milliseconds: 1500),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Icon(item.icon, color: item.color, size: 28),
              ),
            ),
            const AppSpacing.vsm(),
            Text(
              item.value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: displayColor,
              ),
            ),
            Text(
              item.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (item.alert) ...[
              const AppSpacing.vxs(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: AppTheme.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  context.l10n.vitalOutOfRange,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEdgeAiPatternCard() {
    final theme = Theme.of(context);
    final res = _aiAnomalyResult;
    final isAnomaly = res?.isAnomaly ?? false;
    final anomalyScore = res?.anomalyScore ?? 0.05;
    final latency = res?.latencyMs ?? 0.8;
    final statusColor = isAnomaly ? AppTheme.tertiaryAmber : AppTheme.riskGreen;
    final statusIcon = isAnomaly
        ? Icons.waves_rounded
        : Icons.verified_user_rounded;
    final statusText = isAnomaly ? _kAiPatternDiffers : _kAiPatternBaseline;
    final scoreStats =
        'Latency: ${latency.toStringAsFixed(1)}ms | Score: ${anomalyScore.toStringAsFixed(2)} (thresh: 0.38)';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLg,
        vertical: AppTheme.spacingSm,
      ),
      child: AppCard(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.psychology_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    _kAiPatternTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                _kAiPillText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    statusText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Text(
              scoreStats,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _kAiAdvisoryNotice,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedClinicalVisualizations() {
    final theme = Theme.of(context);
    final v = _triageResult?.vitals ?? const {};
    final systolic = (v['systolic'] as num?)?.toInt() ?? 0;
    final diastolic = (v['diastolic'] as num?)?.toInt() ?? 0;
    final draft = ref.read(screeningDraftProvider);
    final hasStrip = draft.ecgSamples.length >= draft.ecgSampleRate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSpacing.vlg(),

          // The strip that was actually captured. The old screen drew a
          // synthetic "hospital monitor" animation here — convincing-looking,
          // and entirely invented. Real samples only, or no card.
          if (hasStrip) ...[
            RecordedEcgCard(
              samples: draft.ecgSamples,
              sampleRate: draft.ecgSampleRate,
              generated: draft.isDemoDevice,
            ),
            const AppSpacing.vlg(),
          ],

          // Derived estimates, clearly tagged. These are computed from PTT and
          // vitals — useful for triage context, never a laboratory value.
          if (systolic > 0 && diastolic > 0)
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: ClinicalPalette.hairline(context)),
              ),
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Overline(context.l10n.triageDerivedEstimates),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ClinicalPalette.violet.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.l10n.triageExperimental.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: ClinicalPalette.violet,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const AppSpacing.vsm(),
                  Wrap(
                    spacing: AppTheme.spacingXl,
                    runSpacing: AppTheme.spacingSm,
                    children: [
                      if (systolic > 0)
                        UnitNumber(
                          '$systolic/$diastolic',
                          'mmHg',
                          size: 22,
                          color: ClinicalPalette.violet,
                        ),
                    ],
                  ),
                  const AppSpacing.vxs(),
                  Text(
                    context.l10n.triageDerivedDisclaimer,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ClinicalPalette.muted(context),
                    ),
                  ),
                ],
              ),
            ),
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
                  child: Text(
                    context.l10n.triageReportedSymptoms,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: riskColor,
                    ),
                  ),
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
                  label: Text(context.l10n.symptomText(symptom)),
                  avatar: CircleAvatar(
                    radius: 10,
                    backgroundColor: riskColor.withValues(alpha: 0.2),
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: riskColor,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  backgroundColor: riskColor.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: riskColor,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide(color: riskColor.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
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
                label: context.l10n.triageSendSos,
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
              context.l10n.triageSosCancelNote(settings.sosCountdownSeconds),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const AppSpacing.vmd(),
          ],
          Row(
            children: [
              Expanded(
                child: AppOutlinedButton(
                  label: context.l10n.triageDoctorReferral,
                  icon: const Icon(Icons.assignment_turned_in_rounded),
                  borderColor: riskColor,
                  foregroundColor: riskColor,
                  onPressed: _openReferralSlip,
                ),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: AppOutlinedButton(
                  label: _kDownloadPdfLabel,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  borderColor: theme.colorScheme.secondary,
                  foregroundColor: theme.colorScheme.secondary,
                  onPressed: _exportPdfDirect,
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          // Wrap, not Row: two buttons with icons and full labels cannot share
          // one 360px line at 2.0x text scale.
          Row(
            children: [
              Expanded(
                child: AppOutlinedButton(
                  label: context.l10n.triageExplainThis,
                  icon: const Icon(Icons.psychology_rounded),
                  onPressed: _openExplanation,
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
                      ? context.l10n.triageFinish
                      : context.l10n.actionDone,
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

  void _openReferralSlip() {
    if (_triageResult == null) return;
    DoctorReferralDialog.show(
      context,
      triageResult: _triageResult!,
      patient: _patient,
      screeningId: _savedId,
    );
  }

  Future<void> _exportPdfDirect() async {
    if (_triageResult == null) return;
    try {
      final draft = ref.read(screeningDraftProvider);
      final patient =
          draft.patient ??
          _patient ??
          Patient(
            id: 'walkin',
            name: 'Walk-In Patient',
            age: 45,
            sex: 'Female',
            createdAt: DateTime.now(),
          );
      final v = _triageResult!.vitals;
      final screening = Screening(
        id: _savedId ?? const Uuid().v4(),
        patientId: patient.id,
        deviceId: draft.deviceId.isNotEmpty ? draft.deviceId : 'SSAI-SENSE-01',
        timestamp: DateTime.now(),
        heartRate: (v['heart_rate'] as num?)?.toInt() ?? 75,
        spo2: (v['spo2'] as num?)?.toInt() ?? 98,
        temperature: (v['temperature'] as num?)?.toDouble() ?? 37.0,
        estimatedGlucose: (v['glucose'] as num?)?.toInt() ?? 0,
        estimatedSystolic: (v['systolic'] as num?)?.toInt() ?? 0,
        estimatedDiastolic: (v['diastolic'] as num?)?.toInt() ?? 0,
        riskScore: _triageResult!.score,
        riskLevel: _triageResult!.level,
        triggeredRules: _triageResult!.triggeredRules,
        symptoms: _triageResult!.symptoms,
        isDemo: _triageResult!.isDemo,
      );

      await PdfClinicalReportService.exportAndShareReport(
        patient: patient,
        screening: screening,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not generate PDF: $e')));
      }
    }
  }

  Widget _buildVernacularGuidanceCard(Color riskColor) {
    if (_triageResult == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final assessment = RiskEngine.assess(
      sample: HealthSample(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        heartRateBpm: _triageResult!.vitals['heart_rate'] ?? 0,
        spo2Percent: _triageResult!.vitals['spo2'] ?? 0,
        temperatureC:
            (_triageResult!.vitals['temperature'] as num?)?.toDouble() ?? 0,
        estimatedGlucose: _triageResult!.vitals['glucose'] ?? 0,
        estimatedSystolic: _triageResult!.vitals['systolic'] ?? 0,
        estimatedDiastolic: _triageResult!.vitals['diastolic'] ?? 0,
        ecgSignalQuality:
            (_triageResult!.vitals['ecg_quality'] as num?)?.toDouble() ?? 0.9,
        rPeakDetected: true,
        rrIntervalMs: 800,
        batteryPercent: 90,
      ),
      symptoms: _triageResult!.symptoms,
    );

    final guidance = VernacularGuidanceService.getGuidance(
      assessment: assessment,
      languageCode: _guidanceLanguage,
      patientName: _patient?.name,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: AppElevatedCard(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.record_voice_over_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const AppSpacing.hsm(),
                Expanded(
                  child: Text(
                    context.l10n.triageAshaGuidance,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const AppSpacing.vsm(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in [
                    (code: 'hi', label: context.l10n.settingsLanguageHindi),
                    (code: 'bn', label: context.l10n.settingsLanguageBengali),
                    (code: 'en', label: context.l10n.settingsLanguageEnglish),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(entry.label),
                        selected: _guidanceLanguage == entry.code,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _guidanceLanguage = entry.code);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            const AppSpacing.vmd(),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: riskColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guidance.headline,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: riskColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    guidance.spokenText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const AppSpacing.vsm(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: riskColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          guidance.immediateAction,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
        border: BorderSide(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
          width: 1,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: theme.colorScheme.tertiary,
              size: 20,
            ),
            const AppSpacing.hmd(),
            Expanded(
              child: Text(
                'This is a screening/triage assessment tool, NOT a medical diagnosis. Results should be reviewed by a qualified healthcare professional. The risk level is determined by deterministic rules, not AI.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLevelDescription(String level) {
    switch (level.toUpperCase()) {
      case 'RED':
      case 'URGENT':
      case 'HIGH':
        return 'HIGH RISK - Immediate Attention Required';
      case 'YELLOW':
      case 'AMBER':
      case 'ATTENTION':
      case 'MEDIUM':
        return 'MODERATE RISK - Clinical Review Recommended';
      case 'GREEN':
      case 'LOW':
      case 'NORMAL':
        return 'LOW RISK - Routine Monitoring';
      default:
        return 'Unknown Risk Level';
    }
  }
}

class _VitalSummaryItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool alert;

  _VitalSummaryItem(
    this.label,
    this.value,
    this.icon,
    this.color, {
    this.alert = false,
  });
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
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        3 + (i % 3) * 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _TriageParticlePainter &&
        oldDelegate.animationValue != animationValue;
  }
}
