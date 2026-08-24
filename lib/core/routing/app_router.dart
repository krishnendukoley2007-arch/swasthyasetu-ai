import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';
import 'package:swasthyasetu_ai/features/auth/screens/splash_screen.dart';
import 'package:swasthyasetu_ai/features/auth/screens/login_screen.dart';
import 'package:swasthyasetu_ai/features/community/screens/community_dashboard_screen.dart';
import 'package:swasthyasetu_ai/features/dashboard/screens/home_screen.dart';
import 'package:swasthyasetu_ai/features/devices/screens/device_scan_screen.dart';
import 'package:swasthyasetu_ai/features/devices/screens/device_connection_screen.dart';
import 'package:swasthyasetu_ai/features/devices/screens/device_diagnostics_screen.dart';
import 'package:swasthyasetu_ai/features/emergency/screens/emergency_contacts_screen.dart';
import 'package:swasthyasetu_ai/features/emergency/screens/sos_screen.dart';
import 'package:swasthyasetu_ai/features/patients/screens/patient_list_screen.dart';
import 'package:swasthyasetu_ai/features/patients/screens/add_patient_screen.dart';
import 'package:swasthyasetu_ai/features/patients/screens/patient_profile_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/new_screening_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/live_vitals_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/ecg_live_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/symptoms_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/triage_result_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/ai_explanation_screen.dart';
import 'package:swasthyasetu_ai/features/history/screens/screening_history_screen.dart';
import 'package:swasthyasetu_ai/features/history/screens/screening_details_screen.dart';
import 'package:swasthyasetu_ai/features/sync/screens/pending_sync_screen.dart';
import 'package:swasthyasetu_ai/features/settings/screens/settings_screen.dart';
import 'package:swasthyasetu_ai/features/settings/screens/storage_settings_screen.dart';
import 'package:swasthyasetu_ai/features/debug/screens/ui_showcase_screen.dart';

final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/devices/scan',
      builder: (context, state) => const DeviceScanScreen(),
    ),
    GoRoute(
      path: '/devices/connect',
      // The scan screen passes the chosen radio through `extra`. Unpacked here
      // rather than read from GoRouterState inside the screen so the screen can
      // be built directly in a test with no router above it.
      builder: (context, state) {
        final extra = state.extra;
        final args = extra is Map ? extra : const <Object?, Object?>{};
        return DeviceConnectionScreen(
          remoteId: args['remoteId'] as String?,
          deviceName: args['name'] as String?,
          demo: args['demo'] == true,
        );
      },
    ),
    GoRoute(
      path: '/devices/diagnostics',
      builder: (context, state) => const DeviceDiagnosticsScreen(),
    ),
    GoRoute(
      path: '/patients',
      builder: (context, state) => const PatientListScreen(),
    ),
    GoRoute(
      path: '/patients/add',
      builder: (context, state) => const AddPatientScreen(),
    ),
    GoRoute(
      path: '/patients/:id',
      builder: (context, state) => PatientProfileScreen(
        patientId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/screening/new',
      builder: (context, state) => const NewScreeningScreen(),
    ),
    GoRoute(
      path: '/screening/live',
      builder: (context, state) => const LiveVitalsScreen(),
    ),
    GoRoute(
      path: '/screening/ecg',
      builder: (context, state) => const EcgLiveScreen(),
    ),
    GoRoute(
      path: '/screening/symptoms',
      builder: (context, state) => const SymptomsScreen(),
    ),
    GoRoute(
      path: '/screening/triage',
      builder: (context, state) => const TriageResultScreen(),
    ),
    GoRoute(
      path: '/screening/ai-explanation',
      builder: (context, state) => const AiExplanationScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const ScreeningHistoryScreen(),
    ),
    GoRoute(
      path: '/history/:id',
      builder: (context, state) => ScreeningDetailsScreen(
        screeningId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/sync',
      builder: (context, state) => const PendingSyncScreen(),
    ),
    GoRoute(
      path: '/emergency/contacts',
      builder: (context, state) => const EmergencyContactsScreen(),
    ),
    GoRoute(
      path: '/emergency/sos',
      // Query parameters rather than a path segment: every field is optional.
      // A manual SOS from the dashboard carries none of them; one raised by a
      // high-risk reading carries the patient and the screening it came from.
      builder: (context, state) {
        final q = state.uri.queryParameters;
        return SosScreen(
          patientId: q['patientId'],
          screeningId: q['screeningId'],
          trigger: SosTrigger.fromStorage(q['trigger'] ?? ''),
          autoStart: q['autoStart'] == 'true',
        );
      },
    ),
    GoRoute(
      path: '/community',
      builder: (context, state) => const CommunityDashboardScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/storage',
      builder: (context, state) => const StorageSettingsScreen(),
    ),
    GoRoute(
      path: '/debug/ui-showcase',
      builder: (context, state) => const UIShowcaseScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.error}'),
    ),
  ),
);