/// ROUTING RULES (project-wide, not negotiable per screen):
///
/// * `context.go(...)` — shell/branch switches and guard-driven redirects
///   only. Never for a destination the user might want to go BACK from.
/// * `context.push(...)` — anything the user should be able to back out of:
///   detail screens, /settings, /sync, /devices/*, SOS, chat, trends, and
///   entering the screening funnel.
/// * The screening funnel (/screening/*) is deliberately full-screen — no
///   bottom bar — but every wizard step carries the trailing
///   ScreeningExitButton as its one consistent exit. Back arrows between
///   steps still use go() because a funnel step is a sibling of the next,
///   not a child to return to.
/// * Role-neutral destinations (/devices/*, /settings, /sync, /emergency/*)
///   live at top level so they never wear the wrong role's tab bar — see the
///   comment above those routes. A route belongs in a shell only if it is
///   genuinely role-specific.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
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
import 'package:swasthyasetu_ai/features/screening/screens/mutually_exclusive_screening_screen.dart';
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
import 'package:swasthyasetu_ai/features/dashboard/screens/general_ai_chat_screen.dart';

/// The tab bar used by both role shells: a hairline-topped bar with a teal
/// sliding pill behind the active tab. Tabs tick the haptic engine on change
/// — navigation is physical, not implied. A teal dot rides on a destination
/// that holds something live (e.g. a streaming device).
class _ClinicalNavBar extends StatelessWidget {
  const _ClinicalNavBar({
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
    this.liveDotIndex,
  });

  final List<({IconData icon, String label})> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// Tab that holds a live connection; gets the small teal dot.
  final int? liveDotIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final ink = theme.colorScheme.onSurface;
    final n = destinations.length;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          top: BorderSide(color: ClinicalPalette.hairline(context)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, cons) {
              final slot = cons.maxWidth / n;
              return Stack(
                children: [
                  // Sliding pill behind the active tab.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 340),
                    curve: const Cubic(0.34, 1.25, 0.64, 1),
                    left: slot * currentIndex + 8,
                    width: slot - 16,
                    top: 10,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: ClinicalPalette.teal.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.16
                              : 0.10,
                        ),
                        border: Border.all(
                          color: ClinicalPalette.teal.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          child: _NavTab(
                            icon: destinations[i].icon,
                            label: destinations[i].label,
                            selected: i == currentIndex,
                            liveDot: i == liveDotIndex,
                            ink: ink,
                            onTap: () {
                              if (i != currentIndex) {
                                HapticFeedback.selectionClick();
                              }
                              onSelected(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.liveDot,
    required this.ink,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool liveDot;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ClinicalPalette.teal : ink.withValues(alpha: 0.55);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(icon, size: 21, color: color),
              ),
              if (liveDot)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ClinicalPalette.tealBright,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Persistent bottom navigation shell for clinician mode.
class _ClinicianShell extends ConsumerWidget {
  const _ClinicianShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSyncCountProvider);
    return Scaffold(
      body: shell,
      bottomNavigationBar: _ClinicalNavBar(
        currentIndex: shell.currentIndex,
        onSelected: (i) =>
            // Re-tapping the current tab pops that branch back to its root,
            // which is what every Android user expects from a bottom bar.
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        // History carries the live dot while rows sit in the sync queue —
        // the tab holds pending work, not just a list.
        liveDotIndex: pending > 0 ? 2 : null,
        destinations: const [
          (icon: Icons.space_dashboard_rounded, label: 'Home'),
          (icon: Icons.people_alt_rounded, label: 'Patients'),
          (icon: Icons.history_rounded, label: 'History'),
          (icon: Icons.groups_rounded, label: 'Community'),
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
    // The device tab shows the teal dot while a board is streaming — the tab
    // is live, not just reachable.
    final streaming =
        ref.watch(bleLinkProvider).status == BleLinkStatus.streaming;
    return Scaffold(
      body: shell,
      bottomNavigationBar: _ClinicalNavBar(
        currentIndex: shell.currentIndex,
        onSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        liveDotIndex: streaming ? 2 : null,
        destinations: const [
          (icon: Icons.favorite_rounded, label: 'My Health'),
          (icon: Icons.wb_sunny_rounded, label: 'Advisories'),
          (icon: Icons.developer_board_rounded, label: 'Device'),
          (icon: Icons.call_rounded, label: 'Help'),
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
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
          // My Device — the patient's own tab. The shared /devices/* routes
          // live top-level (below) because clinicians and demo users reach
          // them too, and they must not inherit the patient tab bar.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-device',
                builder: (context, state) => const DeviceScanScreen(),
              ),
            ],
          ),
          // Help
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-help',
                builder: (context, state) => const EmergencyContactsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ─── All other routes (top-level, no persistent bottom bar) ───
      // Device setup is shared by every role, so it cannot sit inside a
      // role-specific shell: a clinician tapping "Connect device" on Home was
      // landing here wearing the patient tab bar, and the guard then bounced
      // them back out when they tapped one of those patient tabs.
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
      GoRoute(
        path: '/emergency/contacts',
        builder: (context, state) => const EmergencyContactsScreen(),
      ),
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
        builder: (context, state) => const MutuallyExclusiveScreeningScreen(),
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
        path: '/general-chat',
        builder: (context, state) => const GeneralAiChatScreen(),
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
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.error}'))),
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
    // Patient-shell tabs: reaching them would show the patient bottom bar
    // over a demo session that has no patient identity behind it.
    if (loc == '/my-device' || loc == '/my-help') return '/home';
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
      case '/register/patient':
        // The registration page doubles as "edit profile". A completed
        // profile being re-SAVED flips auth state while sitting here, so
        // this redirect sends the refresh onward to home instead of leaving
        // the worker stranded on a form that already saved.
        return account.profileComplete ? '/my-health' : null;
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
    case '/my-device':
    case '/my-help':
    case '/register/patient':
      return '/home';
    default:
      return null;
  }
}
