import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/services/audio_coach_scripts.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/core/widgets/app_card.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/features/screening/state/audio_coach_controller.dart';

/// An illiterate-friendly, high-contrast interactive Audio Coach Card.
///
/// Prominently answers the core patient question:
/// "Then what is my situation?" / "मेरी स्थिति क्या है?" / "আমার অবস্থা কেমন?"
/// via soothing, human-like voice guidance in Hindi, Bengali, or English.
class WhatIsMySituationCard extends ConsumerStatefulWidget {
  final RiskBand band;
  final HealthSample sample;
  final String? patientName;
  final int? score;
  final List<String> symptoms;
  final double? dehydrationScore;
  final String? trajectorySummary;

  const WhatIsMySituationCard({
    super.key,
    required this.band,
    required this.sample,
    this.patientName,
    this.score,
    this.symptoms = const [],
    this.dehydrationScore,
    this.trajectorySummary,
  });

  @override
  ConsumerState<WhatIsMySituationCard> createState() =>
      _WhatIsMySituationCardState();
}

class _WhatIsMySituationCardState extends ConsumerState<WhatIsMySituationCard>
    with SingleTickerProviderStateMixin {
  bool _showTranscript = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getCardTitle(AudioCoachLanguage lang) {
    return switch (lang) {
      AudioCoachLanguage.hindi => 'बोलकर बताएं: मेरी स्थिति क्या है?',
      AudioCoachLanguage.bengali => 'শুনে নিন: আমার অবস্থা কেমন?',
      AudioCoachLanguage.english => 'Speak: What Is My Situation?',
    };
  }

  String _getSubtitle(AudioCoachLanguage lang) {
    return switch (lang) {
      AudioCoachLanguage.hindi =>
        'सरल व मानवीय आवाज़ में अपनी स्वास्थ्य स्थिति का पूरा विवरण सुनें',
      AudioCoachLanguage.bengali =>
        'সহজ ও মানবিক গলায় নিজের স্বাস্থ্য পরিস্থিতির ব্যাখ্যা শুনুন',
      AudioCoachLanguage.english =>
        'Hear a warm, plain-language audio summary of your current health status',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coachState = ref.watch(audioCoachControllerProvider);
    final coachNotifier = ref.read(audioCoachControllerProvider.notifier);
    final lang = coachState.selectedLanguage;
    final isSpeaking = coachState.isSpeaking;
    final isPaused = coachState.isPaused;

    if (isSpeaking && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isSpeaking && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    const primaryColor = ClinicalPalette.teal;

    return AppCard(
      elevation: 2,
      border: BorderSide(
        color: isSpeaking
            ? primaryColor
            : theme.colorScheme.outline.withValues(alpha: 0.2),
        width: isSpeaking ? 2.0 : 1.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with animated speaker avatar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = isSpeaking
                      ? 1.0 + (_pulseController.value * 0.12)
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(
                          alpha: isSpeaking ? 0.25 : 0.12,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isSpeaking
                            ? Icons.volume_up_rounded
                            : Icons.record_voice_over_rounded,
                        color: primaryColor,
                        size: 26,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getCardTitle(lang),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getSubtitle(lang),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Horizontal Language Selection Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final l in AudioCoachLanguage.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        l.displayName,
                        style: TextStyle(
                          fontWeight: lang == l
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      selected: lang == l,
                      selectedColor: primaryColor.withValues(alpha: 0.18),
                      side: BorderSide(
                        color: lang == l
                            ? primaryColor
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          coachNotifier.setLanguage(l);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Big Main Action Button / Control Bar
          if (!isSpeaking && !isPaused)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                icon: const Icon(Icons.play_circle_fill_rounded, size: 24),
                label: Text(
                  _getPlayButtonLabel(lang),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                onPressed: () {
                  coachNotifier.speakWhatIsMySituation(
                    band: widget.band,
                    sample: widget.sample,
                    patientName: widget.patientName,
                    score: widget.score,
                    symptoms: widget.symptoms,
                    dehydrationScore: widget.dehydrationScore,
                    trajectorySummary: widget.trajectorySummary,
                  );
                },
              ),
            )
          else ...[
            // Active Playback Controls Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isSpeaking
                            ? Icons.graphic_eq_rounded
                            : Icons.pause_circle_outline_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isSpeaking
                              ? _getSpeakingStatus(lang)
                              : _getPausedStatus(lang),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isSpeaking
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: primaryColor,
                        ),
                        tooltip: isSpeaking ? 'Pause' : 'Resume',
                        onPressed: () {
                          if (isSpeaking) {
                            coachNotifier.pause();
                          } else {
                            coachNotifier.resume();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.stop_rounded, color: Colors.red),
                        tooltip: 'Stop',
                        onPressed: () => coachNotifier.stop(),
                      ),
                    ],
                  ),
                  if (coachState.progress > 0.0) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: coachState.progress,
                      backgroundColor: primaryColor.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        primaryColor,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Expandable Live Transcript toggle
          InkWell(
            onTap: () {
              setState(() => _showTranscript = !_showTranscript);
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    _showTranscript
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _getTranscriptToggleLabel(lang),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_showTranscript) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                AudioCoachScripts.whatIsMySituation(
                  lang: lang,
                  band: widget.band,
                  sample: widget.sample,
                  patientName: widget.patientName,
                  score: widget.score,
                  symptoms: widget.symptoms,
                  dehydrationScore: widget.dehydrationScore,
                  trajectorySummary: widget.trajectorySummary,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getPlayButtonLabel(AudioCoachLanguage lang) {
    return switch (lang) {
      AudioCoachLanguage.hindi => 'आवाज़ में सुनें (Speak Situation)',
      AudioCoachLanguage.bengali => 'গলায় শুনুন (Speak Situation)',
      AudioCoachLanguage.english => 'Listen Aloud (Speak Situation)',
    };
  }

  String _getSpeakingStatus(AudioCoachLanguage lang) {
    return switch (lang) {
      AudioCoachLanguage.hindi => 'स्वास्थ्य साथी बोल रहा है...',
      AudioCoachLanguage.bengali => 'স্বাস্থ্য সাথী বলছে...',
      AudioCoachLanguage.english => 'Health companion is speaking...',
    };
  }

  String _getPausedStatus(AudioCoachLanguage lang) {
    return switch (lang) {
      AudioCoachLanguage.hindi => 'आवाज़ रुकी हुई है',
      AudioCoachLanguage.bengali => 'কথা সাময়িক স্থগিত',
      AudioCoachLanguage.english => 'Speech paused',
    };
  }

  String _getTranscriptToggleLabel(AudioCoachLanguage lang) {
    return switch (lang) {
      AudioCoachLanguage.hindi =>
        _showTranscript
            ? 'बोले गए शब्द छुपाएं'
            : 'बोले गए शब्द देखें (View Text)',
      AudioCoachLanguage.bengali =>
        _showTranscript ? 'লেখা বন্ধ করুন' : 'বক্তব্য লেখা দেখুন (View Text)',
      AudioCoachLanguage.english =>
        _showTranscript ? 'Hide transcript' : 'View full transcript text',
    };
  }
}
