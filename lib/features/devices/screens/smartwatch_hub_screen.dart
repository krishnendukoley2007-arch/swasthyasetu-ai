import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/core/services/wearable_service.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/features/wearable/screens/wearable_screen.dart';

/// Smartwatch Management and Interactive Companion Hub.
///
/// Bridges the phone app with Wear OS, watchOS, and BLE smartwatch companions.
/// Allows field doctors and patients to manage wrist alert preferences,
/// inspect background smartwatch sensor metrics, and preview the live
/// watch interface through an interactive hardware simulator.
class SmartwatchHubScreen extends ConsumerStatefulWidget {
  const SmartwatchHubScreen({super.key});

  @override
  ConsumerState<SmartwatchHubScreen> createState() =>
      _SmartwatchHubScreenState();
}

class _SmartwatchHubScreenState extends ConsumerState<SmartwatchHubScreen> {
  bool _syncWithEsp32 = true;

  @override
  void initState() {
    super.initState();
    // Auto-connect default companion in standby if not already connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wearable = ref.read(wearableServiceProvider);
      if (!wearable.state.isConnected) {
        wearable.connectToWearable(
          deviceName: 'Galaxy Watch 6 (Wear OS)',
          platform: WearablePlatform.wearOs,
          isDemo: false,
        );
      }
    });
  }

  void _testWristHaptic() {
    HapticFeedback.heavyImpact();
    ref
        .read(wearableServiceProvider)
        .triggerWristAlert('Test Wrist Haptic Alert', isEmergency: false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        content: Text('Dispatched haptic pulse to paired smartwatch'),
      ),
    );
  }

  void _injectNormalDemo() {
    HapticFeedback.lightImpact();
    ref
        .read(wearableServiceProvider)
        .updateFromVitals(
          heartRate: 72,
          spo2: 98,
          temperature: 36.6,
          battery: 92,
          isDemo: true,
        );
  }

  void _injectCriticalDemo() {
    HapticFeedback.mediumImpact();
    ref
        .read(wearableServiceProvider)
        .updateFromVitals(
          heartRate: 146,
          spo2: 87,
          temperature: 39.2,
          battery: 74,
          isDemo: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final wearable = ref.watch(wearableServiceProvider);
    final snapshotAsync = ref.watch(wearableSnapshotProvider);
    final snapshot = snapshotAsync.value ?? wearable.state;

    // Listen to live BLE telemetry if enabled
    ref.listen(bleServiceProvider, (prev, next) {
      if (_syncWithEsp32 && next.state.status == BleLinkStatus.streaming) {
        // BLE link frames will update wearable service
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smartwatch Companion Hub'),
        actions: [
          IconButton(
            tooltip: 'Full-Screen Watch Mode',
            icon: const Icon(Icons.watch),
            onPressed: () => context.push('/wearable'),
          ),
          IconButton(
            tooltip: 'Test Wrist Haptics',
            icon: const Icon(Icons.vibration),
            onPressed: _testWristHaptic,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Section 1: Interactive Smartwatch Hardware Simulator ──
            Center(
              child: Column(
                children: [
                  Text(
                    'LIVE SMARTWATCH DISPLAY',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Photorealistic Watch Bezel & Casing
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          isDark
                              ? const Color(0xFF262C36)
                              : const Color(0xFFD6DBE4),
                          isDark
                              ? const Color(0xFF10141C)
                              : const Color(0xFF8A93A4),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.6 : 0.25,
                          ),
                          blurRadius: 24,
                          spreadRadius: 4,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3F4858)
                            : const Color(0xFFBBC3D2),
                        width: 3.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(8.0),
                    child: const ClipOval(
                      child: WearableScreen(isWatchStandalone: false),
                    ),
                  ),
                  const SizedBox(height: 8),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TextButton.icon(
                      icon: const Icon(Icons.fullscreen, size: 18),
                      label: const Text('Open Watch Full-Screen'),
                      onPressed: () => context.push('/wearable'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Section 2: Paired Smartwatch Status ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: ClinicalPalette.hairline(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ClinicalPalette.teal.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.watch_outlined,
                            color: ClinicalPalette.teal,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                snapshot.deviceName ?? 'No Watch Connected',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: snapshot.isConnected
                                          ? ClinicalPalette.tealBright
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      snapshot.status.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.battery_charging_full,
                                  size: 16,
                                  color: ClinicalPalette.teal,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  snapshot.watchBatteryText,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              snapshot.platform.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Quick pairing action buttons
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(
                            snapshot.isConnected ? 'Disconnect' : 'Connect',
                          ),
                          onPressed: () {
                            if (snapshot.isConnected) {
                              wearable.disconnect();
                            } else {
                              wearable.connectToWearable(
                                deviceName: 'Galaxy Watch 6 (Wear OS)',
                                platform: WearablePlatform.wearOs,
                              );
                            }
                          },
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.devices, size: 16),
                          label: const Text('Change Model'),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.watch),
                                      title: const Text(
                                        'Samsung Galaxy Watch (Wear OS)',
                                      ),
                                      onTap: () {
                                        wearable.connectToWearable(
                                          deviceName: 'Galaxy Watch 6',
                                          platform: WearablePlatform.wearOs,
                                        );
                                        Navigator.pop(ctx);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.watch),
                                      title: const Text(
                                        'Google Pixel Watch (Wear OS)',
                                      ),
                                      onTap: () {
                                        wearable.connectToWearable(
                                          deviceName: 'Pixel Watch 2',
                                          platform: WearablePlatform.wearOs,
                                        );
                                        Navigator.pop(ctx);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.apple),
                                      title: const Text(
                                        'Apple Watch (watchOS Companion)',
                                      ),
                                      onTap: () {
                                        wearable.connectToWearable(
                                          deviceName: 'Apple Watch Ultra',
                                          platform: WearablePlatform.watchOs,
                                        );
                                        Navigator.pop(ctx);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Section 3: Smartwatch Sensor Baseline Data ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: ClinicalPalette.hairline(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          size: 20,
                          color: ClinicalPalette.cardiacCoral,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Background Watch Sensor Baseline',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Passively ingested via Health Connect / Watch Sensors to provide 24/7 clinical baseline context.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 280;
                        final card1 = Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ClinicalPalette.cardiacContainer(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resting Heart Rate',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: ClinicalPalette.cardiacAccent(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                snapshot.restingHeartRateText,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '24h daily average',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );

                        final card2 = Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ClinicalPalette.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Activity',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: ClinicalPalette.teal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                snapshot.dailyStepsText,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Watch Pedometer',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              card1,
                              const SizedBox(height: 10),
                              card2,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: card1),
                            const SizedBox(width: 12),
                            Expanded(child: card2),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Section 4: Live Simulator Controls (Testing & Demo) ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: ClinicalPalette.hairline(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.tune,
                          size: 20,
                          color: ClinicalPalette.teal,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Telemetry & Simulator Controls',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Test watch screen transitions and emergency haptic alerts.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),

                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mirror SSAI-SENSE ESP32 Telemetry'),
                      subtitle: const Text(
                        'Automatically pipe live hardware vitals to the smartwatch.',
                      ),
                      value: _syncWithEsp32,
                      onChanged: (val) {
                        setState(() => _syncWithEsp32 = val);
                      },
                    ),

                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                          ),
                          label: const Text('Normal (Green)'),
                          onPressed: _injectNormalDemo,
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClinicalPalette.coral,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.warning, size: 16),
                          label: const Text('Critical (Red)'),
                          onPressed: _injectCriticalDemo,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Section 5: Wrist Haptic & Alert Preferences ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: ClinicalPalette.hairline(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          size: 20,
                          color: ClinicalPalette.coral,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Wrist Haptic Alerts',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Vibrate on Critical Triage (RED)'),
                      subtitle: const Text(
                        'Immediate heavy pulse on life-threatening vitals.',
                      ),
                      value: snapshot.vibrateOnCriticalTriage,
                      onChanged: (val) {
                        wearable.setPreferences(vibrateOnCriticalTriage: val);
                      },
                    ),
                    const Divider(height: 8),

                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Vibrate on Arrhythmia / Tachycardia'),
                      subtitle: const Text(
                        'Pulse when HR exceeds 130 or drops below 45 BPM.',
                      ),
                      value: snapshot.vibrateOnArrhythmia,
                      onChanged: (val) {
                        wearable.setPreferences(vibrateOnArrhythmia: val);
                      },
                    ),
                    const Divider(height: 8),

                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Vibrate on Fall Detection'),
                      subtitle: const Text(
                        'Buzz wrist when MPU6050 accelerometer detects fall impact.',
                      ),
                      value: snapshot.vibrateOnFall,
                      onChanged: (val) {
                        wearable.setPreferences(vibrateOnFall: val);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
