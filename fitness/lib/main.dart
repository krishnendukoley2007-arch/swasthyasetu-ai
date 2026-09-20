import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/bluetooth/ble_service.dart';
import 'core/theme/fitness_theme.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/motion_lab/motion_lab_screen.dart';
import 'features/pairing/ble_pairing_screen.dart';
import 'features/readiness/readiness_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FitPulseApp()));
}

class FitPulseApp extends StatelessWidget {
  const FitPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitPulse AI',
      debugShowCheckedModeBanner: false,
      theme: FitnessTheme.darkTheme,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FitnessBleService().autoConnect();
    });
  }

  final List<Widget> _pages = const [
    DashboardScreen(),
    MotionLabScreen(),
    ReadinessScreen(),
    BlePairingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: FitnessTheme.surface,
          indicatorColor: FitnessTheme.neonLime.withValues(alpha: 0.2),
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: FitnessTheme.neonLime,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              );
            }
            return const TextStyle(
              color: FitnessTheme.textSecondary,
              fontSize: 12,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                  color: FitnessTheme.neonLime, size: 24);
            }
            return const IconThemeData(
                color: FitnessTheme.textSecondary, size: 22);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) {
            setState(() {
              _currentIndex = idx;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.flash_on),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.threed_rotation),
              label: 'Motion Lab',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite),
              label: 'Readiness',
            ),
            NavigationDestination(
              icon: Icon(Icons.bluetooth),
              label: 'Wearable',
            ),
          ],
        ),
      ),
    );
  }
}
