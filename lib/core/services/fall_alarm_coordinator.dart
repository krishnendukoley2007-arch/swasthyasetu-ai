import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/routing/app_router.dart';
import 'package:swasthyasetu_ai/core/services/fall_detection_service.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';

/// Keeps the accelerometer running exactly as long as the worker asked it to,
/// and turns a detection into a cancellable SOS.
///
/// Mounted once, above the router, rather than on a screen: a fall matters
/// whether or not the SOS screen happens to be open, and a per-screen listener
/// would stop watching the moment the worker navigated away.
///
/// It never sends anything itself. A detection only *navigates* to the SOS
/// screen with the countdown armed, so the ten seconds of cancel window sit
/// between a false positive and a message to the family. That separation is the
/// whole reason fall detection is safe to ship.
class FallAlarmListener extends ConsumerStatefulWidget {
  final Widget child;

  const FallAlarmListener({super.key, required this.child});

  @override
  ConsumerState<FallAlarmListener> createState() => _FallAlarmListenerState();
}

class _FallAlarmListenerState extends ConsumerState<FallAlarmListener> {
  StreamSubscription<FallEvent>? _sub;

  /// Held directly rather than read from `ref` in [dispose]. Riverpod forbids
  /// touching `ref` once the element is unmounted, and the sensor still has to
  /// be released on the way out.
  FallDetectionService? _service;

  /// Set while an alarm is already on screen. Without it, the tumble that
  /// follows a landing can push a second SOS route on top of the first, and the
  /// worker has to cancel twice.
  bool _alarmOpen = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: reading a provider during initState races the
    // bootstrap that loads the persisted setting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applySetting(ref.read(settingsProvider).fallDetection);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    // The service is owned by the provider container, so it is stopped rather
    // than disposed here — another listener may legitimately outlive this one.
    _service?.stop();
    super.dispose();
  }

  Future<void> _applySetting(bool enabled) async {
    final service = ref.read(fallDetectionServiceProvider);
    _service = service;

    if (!enabled) {
      await _sub?.cancel();
      _sub = null;
      await service.stop();
      return;
    }

    if (service.isRunning) return;

    final started = await service.start();
    if (!started) {
      // No accelerometer on this device. Left silent on purpose: the toggle in
      // Settings is the place that explains itself, and a snackbar fired from
      // above the router would appear over whatever screen happened to be open.
      return;
    }
    _sub ??= service.detections.listen(_onFall);
  }

  void _onFall(FallEvent event) {
    if (_alarmOpen) return;
    if (!ref.read(settingsProvider).fallDetection) return;

    _alarmOpen = true;
    ref
        .read(routerProvider)
        .push(
          Uri(
            path: '/emergency/sos',
            queryParameters: {
              'trigger': SosTrigger.fallDetected.storageValue,
              'autoStart': 'true',
            },
          ).toString(),
        )
        .whenComplete(() => _alarmOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    // The subscription follows the setting, so flipping the toggle in Settings
    // arms or disarms the sensor immediately instead of at next launch.
    ref.listen<bool>(
      settingsProvider.select((s) => s.fallDetection),
      (_, enabled) => _applySetting(enabled),
    );
    return widget.child;
  }
}
