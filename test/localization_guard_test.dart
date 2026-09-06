// Guards the localization sweep: user-facing strings in lib/features must go
// through AppLocalizations, not hardcoded literals.
//
// The sweep is incremental. [remainingAllowance] records how many raw
// literals each unfinished file still had when the guard was introduced.
// A file may only ever DECREASE its count — never increase. New files with
// violations fail outright: either localize them or consciously allowlist
// them here (with a comment why).
//
// Completed regressions also fail: if a file drops to zero, remove it from
// the map so it becomes permanently guarded.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _pattern =
    r"(?:Text|label|title|subtitle|hint|hintText|message|confirmLabel|tooltip|value|blurb)\s*[:(]\s*'[^'`\$]{3,}'";

/// Per-file allowance of remaining hardcoded literals.
/// Lower is better; zero entries should be deleted from this map.
const remainingAllowance = <String, int>{
  'auth/screens/login_screen.dart': 22,
  'auth/screens/otp_verification_screen.dart': 6,
  'auth/screens/patient_registration_screen.dart': 21,
  'auth/screens/splash_screen.dart': 1,
  'community/screens/community_dashboard_screen.dart': 20,
  'dashboard/screens/general_ai_chat_screen.dart': 10,
  'dashboard/screens/home_screen.dart': 15,
  'devices/screens/device_connection_screen.dart': 14,
  'devices/screens/device_diagnostics_screen.dart': 3,
  'devices/screens/device_scan_screen.dart': 13,
  'devices/widgets/phone_fall_simulator_sheet.dart': 8,
  'emergency/screens/emergency_contacts_screen.dart': 28,
  'environment/screens/advisories_screen.dart': 9,
  'environment/widgets/environment_card.dart': 11,
  'history/screens/screening_details_screen.dart': 26,
  'history/screens/screening_history_screen.dart': 15,
  'patients/screens/add_patient_screen.dart': 12,
  'patients/screens/patient_list_screen.dart': 21,
  'patients/screens/patient_profile_screen.dart': 22,
  'patient_home/screens/patient_home_screen.dart': 25,
  'screening/screens/ai_explanation_screen.dart': 14,
  'screening/screens/ecg_live_screen.dart': 9,
  'screening/screens/live_vitals_screen.dart': 28,
  'screening/screens/mutually_exclusive_screening_screen.dart': 17,
  'screening/screens/new_screening_screen.dart': 20,
  'screening/screens/triage_result_screen.dart': 4,
  'screening/widgets/abha_qr_card.dart': 7,
  'screening/widgets/clarke_error_grid_widget.dart': 4,
  'screening/widgets/doctor_referral_dialog.dart': 10,
  'screening/widgets/dual_waveform_sweep_monitor.dart': 12,
  'screening/widgets/poincare_plot_widget.dart': 4,
  'screening/widgets/screening_mode_dialog.dart': 9,
  'screening/widgets/vascular_elasticity_gauge.dart': 3,
  'settings/screens/settings_screen.dart': 61,
  'settings/screens/storage_settings_screen.dart': 49,
  'sync/screens/pending_sync_screen.dart': 8,
  'trends/screens/trends_screen.dart': 9,
};

// Dev-only surfaces are exempt from user-facing localization.
const _exemptDirs = {'debug'};

void main() {
  final regex = RegExp(_pattern);
  final featuresDir = Directory('lib/features');

  test('feature files contain no NEW hardcoded user-facing literals', () {
    if (!featuresDir.existsSync()) {
      fail('lib/features not found — run tests from the repo root');
    }

    final failures = <String>[];
    for (final entity in featuresDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path
          .replaceAll('\\', '/')
          .replaceFirst('lib/features/', '');
      if (_exemptDirs.contains(relative.split('/').first)) continue;

      final count = regex.allMatches(File(entity.path).readAsStringSync()).length;
      final allowance = remainingAllowance[relative];
      if (allowance == null) {
        if (count > 0) {
          failures.add('$relative: $count literal(s) — new file must be '
              'localized or consciously allowlisted');
        }
      } else if (count > allowance) {
        failures.add('$relative: $count literal(s), allowance was $allowance '
            '— the count may only go DOWN');
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
