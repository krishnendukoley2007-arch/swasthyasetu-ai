import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/sos_service.dart';
import 'package:swasthyasetu_ai/core/services/wearable_service.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';

/// The dedicated smartwatch interface for SwasthyaSetu AI.
///
/// Designed to run natively on Wear OS (Samsung Galaxy Watch, Pixel Watch,
/// OnePlus Watch, TicWatch) and render inside the phone's Smartwatch Simulator.
///
/// Mandates enforced:
/// - 2.1 One-Way Provenance: Demo readings display a distinct "DEMO" banner
///   and cannot masquerade as measured clinical readings.
/// - 2.3 No Fabricated Gaps: Missing or unmeasured sensor metrics render as
///   "—" (em dash), never "0" or interpolated placeholders.
/// - 2.5 AI Flags Advisory: Wrist emergency alerts follow deterministic
///   [RiskBand] thresholds.
class WearableScreen extends ConsumerStatefulWidget {
  /// When true, renders in standalone watch mode without outer scaffolds.
  final bool isWatchStandalone;

  const WearableScreen({super.key, this.isWatchStandalone = true});

  @override
  ConsumerState<WearableScreen> createState() => _WearableScreenState();
}

class _WearableScreenState extends ConsumerState<WearableScreen> {
  Color _triageColor(RiskBand band) {
    return switch (band) {
      RiskBand.green => ClinicalPalette.tealBright,
      RiskBand.yellow => ClinicalPalette.amber,
      RiskBand.red => ClinicalPalette.coral,
    };
  }

  void _handleEmergencySos(WearableSnapshot snapshot) async {
    HapticFeedback.heavyImpact();
    final sos = ref.read(sosServiceProvider);

    final payload = SosPayload(
      trigger: SosTrigger.manual,
      workerName: 'Smartwatch Quick SOS',
      riskLabel: snapshot.triageBand.label,
      heartRate: snapshot.heartRate,
      spo2: snapshot.spo2,
      temperature: snapshot.temperature,
      extraNote: 'Dispatched from paired smartwatch wrist interface.',
    );

    final result = await sos.dispatch(payload);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: result.isSuccess
            ? ClinicalPalette.teal
            : ClinicalPalette.coral,
        content: Text(
          result.isSuccess
              ? 'Emergency SOS composer opened'
              : (result.failureReason.isNotEmpty
                    ? result.failureReason
                    : 'SOS dispatch failed'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wearableService = ref.watch(wearableServiceProvider);
    final snapshotAsync = ref.watch(wearableSnapshotProvider);
    final snapshot = snapshotAsync.value ?? wearableService.state;

    final triageColor = _triageColor(snapshot.triageBand);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF070A0E),
                border: Border.all(
                  color: triageColor.withValues(alpha: 0.6),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: triageColor.withValues(
                      alpha: snapshot.triageBand == RiskBand.red ? 0.45 : 0.2,
                    ),
                    blurRadius: snapshot.triageBand == RiskBand.red ? 18 : 10,
                    spreadRadius: snapshot.triageBand == RiskBand.red ? 3 : 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  children: [
                    // Concentric Triage Ring & Vitals Content
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 8.0,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 6),

                                // Top Header: Provenance badge & Connection status
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: snapshot.isDemo
                                            ? ClinicalPalette.amber.withValues(
                                                alpha: 0.25,
                                              )
                                            : ClinicalPalette.teal.withValues(
                                                alpha: 0.25,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: snapshot.isDemo
                                              ? ClinicalPalette.amber
                                              : ClinicalPalette.tealBright,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            snapshot.isDemo
                                                ? Icons.science_outlined
                                                : Icons.bluetooth_connected,
                                            size: 10,
                                            color: snapshot.isDemo
                                                ? ClinicalPalette.amber
                                                : ClinicalPalette.tealBright,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            snapshot.isDemo ? 'DEMO' : 'LIVE',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.6,
                                              color: snapshot.isDemo
                                                  ? ClinicalPalette.amber
                                                  : ClinicalPalette.tealBright,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      snapshot.watchBatteryText,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Primary Metric: Heart Rate
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    const Icon(
                                      Icons.favorite,
                                      size: 18,
                                      color: ClinicalPalette.cardiacCoralBright,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      snapshot.heartRateText,
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1.0,
                                        color: Colors.white,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Text(
                                      'BPM',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            ClinicalPalette.cardiacCoralBright,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 2),

                                // Secondary Metrics: SpO2 & Temperature
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // SpO2
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0E1A24),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: ClinicalPalette.cyan
                                              .withValues(alpha: 0.4),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.water_drop,
                                            size: 11,
                                            color: ClinicalPalette.cyan,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            snapshot.spo2Text,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              fontFeatures: [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Temperature
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E170A),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: ClinicalPalette.amber
                                              .withValues(alpha: 0.4),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.thermostat,
                                            size: 11,
                                            color: ClinicalPalette.amber,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            snapshot.temperatureText,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              fontFeatures: [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Bottom Action: Wrist Emergency SOS Button
                                SizedBox(
                                  width: 128,
                                  height: 34,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ClinicalPalette.coral,
                                      foregroundColor: Colors.white,
                                      elevation: 4,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _handleEmergencySos(snapshot),
                                    child: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            size: 14,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'SOS ALERT',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Active Emergency Wrist Alert Overlay (Pulsing Red Banner)
                    if (snapshot.isEmergencyAlertActive)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.88),
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 240,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.crisis_alert,
                                      size: 36,
                                      color: ClinicalPalette.coral,
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'CRITICAL ALERT',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: ClinicalPalette.coral,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      snapshot.lastAlertReason ??
                                          'Abnormal vitals',
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white70,
                                            side: const BorderSide(
                                              color: Colors.white30,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            minimumSize: const Size(54, 28),
                                          ),
                                          onPressed: () {
                                            wearableService.dismissWristAlert();
                                          },
                                          child: const Text(
                                            'MUTE',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                ClinicalPalette.coral,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            minimumSize: const Size(54, 28),
                                          ),
                                          onPressed: () =>
                                              _handleEmergencySos(snapshot),
                                          child: const Text(
                                            'SOS',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
