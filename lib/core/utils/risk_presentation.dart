/// Presentation helpers for the triage vocabulary.
///
/// Nothing in the UI should interpolate a raw enum or storage string into a
/// `Text()`. `RiskBand.red.toString()` is `"RiskBand.red"` and the stored value
/// is `"RED"` — neither belongs in front of a health worker. Every screen goes
/// through this file instead, so the wording is consistent and translatable
/// from one place.
///
/// Every wording helper takes an optional [AppLocalizations]. Passing it returns
/// the worker's language; omitting it returns English. The parameter is optional
/// rather than required because these are also called from contextless code
/// (exports, logs, tests) where there is no locale to consult — and because a
/// call site that has not been localized yet must still render a real word.
library;

import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/l10n/generated/app_localizations.dart';

/// Colour, label and icon for one risk band.
@immutable
class RiskStyle {
  final RiskBand band;
  final Color color;
  final Color onColor;
  final Color containerColor;
  final String label;
  final String shortLabel;
  final IconData icon;

  const RiskStyle({
    required this.band,
    required this.color,
    required this.onColor,
    required this.containerColor,
    required this.label,
    required this.shortLabel,
    required this.icon,
  });

  static RiskStyle _base(RiskBand band) => switch (band) {
        RiskBand.green => const RiskStyle(
            band: RiskBand.green,
            color: AppTheme.riskGreen,
            onColor: Colors.white,
            containerColor: AppTheme.riskGreenContainer,
            label: 'Normal',
            shortLabel: 'Normal',
            icon: Icons.check_circle_outline_rounded,
          ),
        RiskBand.yellow => const RiskStyle(
            band: RiskBand.yellow,
            color: AppTheme.riskYellow,
            onColor: Colors.black,
            containerColor: AppTheme.riskYellowContainer,
            label: 'Needs attention',
            shortLabel: 'Attention',
            icon: Icons.error_outline_rounded,
          ),
        RiskBand.red => const RiskStyle(
            band: RiskBand.red,
            color: AppTheme.riskRed,
            onColor: Colors.white,
            containerColor: AppTheme.riskRedContainer,
            label: 'Urgent',
            shortLabel: 'Urgent',
            icon: Icons.warning_amber_rounded,
          ),
      };

  static RiskStyle of(RiskBand band, [AppLocalizations? l10n]) {
    final base = _base(band);
    if (l10n == null) return base;
    return RiskStyle(
      band: base.band,
      color: base.color,
      onColor: base.onColor,
      containerColor: base.containerColor,
      label: l10n.riskBandLabel(band),
      shortLabel: l10n.riskBandShortLabel(band),
      icon: base.icon,
    );
  }

  /// Accepts the stored `GREEN`/`YELLOW`/`RED` form used in the database.
  static RiskStyle ofStorage(String raw, [AppLocalizations? l10n]) =>
      of(RiskBand.fromStorage(raw), l10n);
}

/// Plain-language sync state. The stored values are `PENDING`, `SYNCED`,
/// `FAILED`, `SYNCING`.
@immutable
class SyncStyle {
  final String label;
  final IconData icon;
  final Color color;

  const SyncStyle({
    required this.label,
    required this.icon,
    required this.color,
  });

  static SyncStyle _base(String raw) => switch (raw.toUpperCase()) {
        'SYNCED' => const SyncStyle(
            label: 'Uploaded',
            icon: Icons.cloud_done_outlined,
            color: AppTheme.riskGreen,
          ),
        'SYNCING' => const SyncStyle(
            label: 'Uploading',
            icon: Icons.cloud_sync_outlined,
            color: AppTheme.infoBlue,
          ),
        'FAILED' => const SyncStyle(
            label: 'Upload failed',
            icon: Icons.cloud_off_outlined,
            color: AppTheme.riskRed,
          ),
        _ => const SyncStyle(
            label: 'Waiting to upload',
            icon: Icons.cloud_queue_outlined,
            color: AppTheme.riskYellow,
          ),
      };

  static SyncStyle of(String raw, [AppLocalizations? l10n]) {
    final base = _base(raw);
    if (l10n == null) return base;
    return SyncStyle(
      label: l10n.syncStatusLabel(raw),
      icon: base.icon,
      color: base.color,
    );
  }
}

/// Human wording for the escalation levels the rule engine emits.
String escalationLabel(String raw, [AppLocalizations? l10n]) =>
    l10n != null ? l10n.escalationText(raw) : switch (raw.toUpperCase()) {
      'EMERGENCY' => 'Seek care now',
      'CLINIC_VISIT' => 'Clinic review',
      'FOLLOW_UP' => 'Follow up',
      _ => 'Routine monitoring',
    };

/// Human wording for the ECG rhythm classes stored on a screening.
String ecgRhythmLabel(String raw, [AppLocalizations? l10n]) =>
    l10n != null ? l10n.ecgRhythmText(raw) : switch (raw.toUpperCase()) {
      'SINUS_RHYTHM' => 'Regular rhythm',
      'TACHYCARDIA' => 'Fast rhythm',
      'BRADYCARDIA' => 'Slow rhythm',
      'IRREGULAR' => 'Irregular rhythm',
      'NOISY' => 'Signal too noisy',
      _ => 'Not classified',
    };

/// Human wording for the cuffless BP confidence tag.
String bpConfidenceLabel(String raw, [AppLocalizations? l10n]) =>
    l10n != null ? l10n.bpConfidenceText(raw) : switch (raw.toUpperCase()) {
      'CALIBRATED' => 'Calibrated estimate',
      'ESTIMATED' => 'Uncalibrated estimate',
      _ => 'Experimental — not for clinical use',
    };

/// Initials for an avatar, safe on empty and single-word names.
String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

/// Compact relative time, e.g. `just now`, `3 h ago`, `12 Aug`.
///
/// Takes [now] so it can be tested without touching the clock.
String relativeTime(DateTime when, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(when);

  if (diff.isNegative) return 'scheduled';
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${when.day} ${_monthNames[when.month - 1]}';
}

/// Absolute, unambiguous timestamp for record views: `12 Aug 2026, 14:05`.
String absoluteDateTime(DateTime when) {
  final hh = when.hour.toString().padLeft(2, '0');
  final mm = when.minute.toString().padLeft(2, '0');
  return '${when.day} ${_monthNames[when.month - 1]} ${when.year}, $hh:$mm';
}

String absoluteDate(DateTime when) =>
    '${when.day} ${_monthNames[when.month - 1]} ${when.year}';

const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
