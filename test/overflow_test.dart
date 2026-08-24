import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/features/dashboard/screens/home_screen.dart';
import 'package:swasthyasetu_ai/features/devices/screens/device_connection_screen.dart';
import 'package:swasthyasetu_ai/features/devices/screens/device_diagnostics_screen.dart';
import 'package:swasthyasetu_ai/features/devices/screens/device_scan_screen.dart';
import 'package:swasthyasetu_ai/features/history/screens/screening_details_screen.dart';
import 'package:swasthyasetu_ai/features/history/screens/screening_history_screen.dart';
import 'package:swasthyasetu_ai/features/patients/screens/add_patient_screen.dart';
import 'package:swasthyasetu_ai/features/patients/screens/patient_list_screen.dart';
import 'package:swasthyasetu_ai/features/patients/screens/patient_profile_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/ai_explanation_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/ecg_live_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/live_vitals_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/new_screening_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/symptoms_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/triage_result_screen.dart';
import 'package:swasthyasetu_ai/features/settings/screens/settings_screen.dart';
import 'package:swasthyasetu_ai/features/sync/screens/pending_sync_screen.dart';

import 'support/harness.dart';

/// Overflow is the defect class this app kept regressing on, so it gets a
/// systematic sweep rather than spot checks: every reachable screen, on the
/// narrowest supported phone, at the three text scales that matter.
///
/// 1.3 and 2.0 are not hypothetical — a health worker reading a screen outdoors
/// at arm's length is exactly who turns the system font size up.
const List<double> _textScales = [1.0, 1.3, 2.0];

const String _patientId = 'overflow-p1';
const String _screeningId = 'overflow-p1-s1';

Future<void> _seed(AppDatabase db) => seedPatientWithHistory(db, id: _patientId);

/// A screen under test. [frames] is trimmed for screens that run an unbounded
/// simulation loop, so the test observes a bounded window of it.
class _ScreenCase {
  final String name;
  final Widget Function() build;
  final int frames;

  const _ScreenCase(this.name, this.build, {this.frames = 10});
}

final List<_ScreenCase> _cases = [
  _ScreenCase('home', () => const HomeScreen()),
  _ScreenCase('patient list', () => const PatientListScreen()),
  _ScreenCase('add patient', () => const AddPatientScreen()),
  _ScreenCase('patient profile',
      () => const PatientProfileScreen(patientId: _patientId)),
  _ScreenCase('screening history', () => const ScreeningHistoryScreen()),
  _ScreenCase('screening details',
      () => const ScreeningDetailsScreen(screeningId: _screeningId)),
  _ScreenCase('new screening', () => const NewScreeningScreen()),
  _ScreenCase('live vitals', () => const LiveVitalsScreen(), frames: 6),
  _ScreenCase('ecg live', () => const EcgLiveScreen()),
  _ScreenCase('symptoms', () => const SymptomsScreen()),
  _ScreenCase('triage result', () => const TriageResultScreen()),
  _ScreenCase('ai explanation', () => const AiExplanationScreen()),
  _ScreenCase('device scan', () => const DeviceScanScreen()),
  _ScreenCase('device connection', () => const DeviceConnectionScreen()),
  _ScreenCase('device diagnostics', () => const DeviceDiagnosticsScreen()),
  _ScreenCase('pending sync', () => const PendingSyncScreen()),
  _ScreenCase('settings', () => const SettingsScreen()),
];

void main() {
  for (final scale in _textScales) {
    group('text scale ${scale}x on a 360x640 phone', () {
      for (final screen in _cases) {
        testWidgets('${screen.name} does not overflow', (tester) async {
          final harness = await TestHarness.create(seed: _seed);
          await tester.useSmallPhone();

          await expectNoOverflow(
            tester,
            () => harness.wrapRouted(screen.build, textScale: scale),
            frames: screen.frames,
          );
        });
      }
    });
  }

  group('high contrast', () {
    // The high-contrast theme widens borders and drops tonal fills, which
    // changes intrinsic sizes — worth one pass at the largest scale.
    for (final screen in _cases) {
      testWidgets('${screen.name} does not overflow at 2.0x', (tester) async {
        final harness = await TestHarness.create(seed: _seed);
        await tester.useSmallPhone();

        await expectNoOverflow(
          tester,
          () => harness.wrapRouted(
            screen.build,
            textScale: 2.0,
            theme: highContrastLight,
          ),
          frames: screen.frames,
        );
      });
    }
  });
}
