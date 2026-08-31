import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:swasthyasetu_ai/features/auth/screens/splash_screen.dart';
import 'package:swasthyasetu_ai/features/auth/screens/login_screen.dart';
import 'package:swasthyasetu_ai/features/auth/screens/patient_registration_screen.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';
import 'package:swasthyasetu_ai/features/community/screens/community_dashboard_screen.dart';
import 'package:swasthyasetu_ai/features/dashboard/screens/home_screen.dart';
import 'package:swasthyasetu_ai/features/environment/screens/advisories_screen.dart';
import 'package:swasthyasetu_ai/features/trends/screens/trends_screen.dart';
import 'package:swasthyasetu_ai/features/devices/screens/device_scan_screen.dart';
import 'package:swasthyasetu_ai/features/devices/screens/device_connection_screen.dart';
import 'package:swasthyasetu_ai/features/devices/screens/device_diagnostics_screen.dart';
import 'package:swasthyasetu_ai/features/emergency/screens/emergency_contacts_screen.dart';
import 'package:swasthyasetu_ai/features/emergency/screens/sos_screen.dart';
import 'package:swasthyasetu_ai/features/patient_home/screens/patient_home_screen.dart';
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

/// Persistent bottom navigation shell for clinician mode.
class _ClinicianShell extends ConsumerWidget {
  const _ClinicianShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            selectedIcon: Icon(Icons.home_rounded, fill: 1.0),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_rounded),
            selectedIcon: Icon(Icons.people_alt_rounded, fill: 1.0),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded, fill: 1.0),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_rounded),
            selectedIcon: Icon(Icons.groups_rounded, fill: 1.0),
            label: 'Community',
          ),
        ],
      ),
    );
  }
}

/// Persistent bottom navigation shell for patient mode.
class _PatientShell extends ConsumerWidget {
  const _PatientShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.favorite_rounded),
            selectedIcon: Icon(Icons.favorite_rounded, fill: 1.0),
            label: 'My Health',
          ),
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_rounded),
            selectedIcon: Icon(Icons.wb_sunny_rounded, fill: 1.0),
            label: 'Advisories',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching_rounded),
            selectedIcon: Icon(Icons.bluetooth_searching_rounded, fill: 1.0),
            label: 'My Device',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_rounded),
            selectedIcon: Icon(Icons.call_rounded, fill: 1.0),
            label: 'Help',
          ),
        ],
      ),
    );
  }
}

/// The router is a provider, not a top-level field: its redirect reads
/// [authStateProvider], and `refreshListenable` re-runs that redirect the
/// moment the session changes. Sign-in/out therefore never calls `context.go`
/// — the state change alone re-homes the phone.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => _guard(ref.read(authStateProvider), state),
    routes: [
      // ─── Public / auth routes (no shell) ───
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register/patient',
        builder: (context, state) => const PatientRegistrationScreen(),
      ),

      // ─── Clinician shell ───
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _ClinicianShell(shell: navigationShell),
        branches: [
          // Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Patients
          StatefulShellBranch(
            routes: [
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
            ],
          ),
          // History
          StatefulShellBranch(
            routes: [
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
            ],
          ),
          // Community
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (context, state) => const CommunityDashboardScreen(),
              ),
            ],
          ),
        ],
      ),

      // ─── Patient shell ───
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _PatientShell(shell: navigationShell),
        branches: [
          // My Health
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-health',
                builder: (context, state) => const PatientHomeScreen(),
              ),
            ],
          ),
          // Advisories
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/advisories',
                builder: (context, state) => const AdvisoriesScreen(),
              ),
            ],
          ),
          // My Device
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/devices/scan',
                builder: (context, state) => const DeviceScanScreen(),
              ),
              GoRoute(
                path: '/devices/connect',
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
            ],
          ),
          // Help
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/emergency/contacts',
                builder: (context, state) => const EmergencyContactsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ─── All other routes (top-level, no persistent bottom bar) ───
      GoRoute(
        path: '/trends',
        builder: (context, state) => TrendsScreen(
          patientId: state.uri.queryParameters['patientId'] ?? '',
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
        path: '/sync',
        builder: (context, state) => const PendingSyncScreen(),
      ),
      GoRoute(
        path: '/emergency/sos',
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

  ref.onDispose(router.dispose);
  return router;
});

/// The single rulebook for who may be where.
///
/// Everyone's default follows their role: patients at /my-health, clinicians
/// and demo at /home. The patient-mode blocks on the workforce routes
/// (`/patients`, `/community`, the shared whole-clinic `/history`) exist
/// because those screens list *other people* — a screening of a stranger is a
/// privacy breach waiting on a shared camp phone, not a feature gap in the
/// patient experience.
///
/// Returns null to allow, a location to force.
String? _guard(AuthState auth, GoRouterState state) {
  final loc = state.matchedLocation;

  // While the session row is still being read, nothing is trustworthy —
  // hold everyone on the splash (which is also the launch route).
  if (auth.status == AuthStatus.unknown) {
    return loc == '/splash' ? null : '/splash';
  }

  if (auth.status == AuthStatus.signedOut) {
    return (loc == '/login' || loc == '/splash') ? null : '/login';
  }

  // A patient without body measurements gets scored against defaults the app
  // cannot defend — registration is not optional for them.
  if (auth.status == AuthStatus.needsProfile) {
    return loc == '/register/patient' ? null : '/register/patient';
  }

  if (auth.status == AuthStatus.demo) {
    if (loc == '/splash' || loc == '/login' || loc == '/') return '/home';
    if (loc == '/my-health' || loc == '/register/patient') return '/home';
    return null;
  }

  // signedIn
  final account = auth.account;
  if (account == null) return '/login';

  if (account.role == UserRole.patient) {
    switch (loc) {
      case '/':
      case '/splash':
      case '/login':
      case '/home':
        return '/my-health';
      case '/patients':
      case '/patients/add':
      case '/community':
      case '/history':
      case '/screening/new':
        // Workforce surfaces — see the doc comment.
        return '/my-health';
      case '/trends':
        // A patient's trends are their own. An id that is not theirs is a
        // route typo or worse — home is the honest answer.
        final qid = state.uri.queryParameters['patientId'];
        if (qid == null || qid != account.patientId) return '/my-health';
        return null;
      default:
        // Block any detail routes under workforce namespaces.
        if (loc.startsWith('/patients/') || loc.startsWith('/history/')) {
          return '/my-health';
        }
        return null;
    }
  }

  // Clinician
  switch (loc) {
    case '/':
    case '/splash':
    case '/login':
      return '/home';
    case '/my-health':
    case '/register/patient':
      return '/home';
    default:
      return null;
  }
}
