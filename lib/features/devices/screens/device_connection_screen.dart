/// The handshake screen.
///
/// It reports what the radio is actually doing. The previous version ran a
/// `Timer.periodic` that ticked seven invented sensor checks to green over two
/// and a half seconds, regardless of whether a board existed — so a worker with
/// a flat sensor board saw "ESP32 Connection ✓ MAX30102 ✓ AD8232 ✓" and then a
/// screening with no readings. Everything on this screen now comes from
/// [BleLinkState], which comes from GATT.
///
/// Three paths, kept apart:
///
/// * **Demo** — no radio touched. Says so, in the tertiary colour used for demo
///   everywhere else in the app.
/// * **A chosen device** — connect, then mirror the real stages: link, service
///   discovery, handshake, streaming. A failure is a failure on screen.
/// * **Nothing chosen** — someone reached this route directly. Offer the scan
///   rather than pretending to connect to nothing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/device_repository.dart';

class DeviceConnectionScreen extends ConsumerStatefulWidget {
  /// The radio to connect to, as reported by the scan. Null when the worker
  /// chose demo mode, or when this route was opened without a device.
  final String? remoteId;

  /// The advertised name, so the screen can say who it is talking to before the
  /// handshake has read anything back.
  final String? deviceName;

  final bool demo;

  const DeviceConnectionScreen({
    super.key,
    this.remoteId,
    this.deviceName,
    this.demo = false,
  });

  @override
  ConsumerState<DeviceConnectionScreen> createState() =>
      _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState
    extends ConsumerState<DeviceConnectionScreen> {
  /// Set once the board has been written to the local device table, so a
  /// reconnect mid-session does not rewrite the row on every state change.
  bool _remembered = false;

  @override
  void initState() {
    super.initState();
    if (widget.demo || widget.remoteId == null) return;
    // Post-frame: `ref.read` during initState throws, and starting a connect
    // before the first paint means the worker stares at a blank screen while
    // the GATT negotiation runs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _connect();
    });
  }

  Future<void> _connect() async {
    final remoteId = widget.remoteId;
    if (remoteId == null) return;
    await ref
        .read(bleServiceProvider)
        .connect(remoteId, name: widget.deviceName);
  }

  /// Write the board into the local table once it is genuinely streaming.
  ///
  /// Deliberately not on `connecting`: a device that never completes the
  /// handshake should not appear under "Previously used" as though it worked.
  Future<void> _remember(BleLinkState link) async {
    if (_remembered || !link.isLive) return;
    final id = link.deviceId;
    if (id == null) return;
    _remembered = true;

    final devices = ref.read(deviceRepositoryProvider);
    await devices.remember(
      id: id,
      name: link.deviceName ?? widget.deviceName ?? 'Sensor board',
      macAddress: id,
      firmwareVersion: link.firmwareVersion ?? 'UNKNOWN',
    );
    await devices.markConnected(
      id,
      battery: link.batteryPercent,
      firmware: link.firmwareVersion,
    );
    await ref.read(settingsProvider.notifier).setLastDeviceId(id);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.demo) return _scaffold(const _DemoReadyView());

    if (widget.remoteId == null) return _scaffold(const _NoDeviceChosenView());

    final link = ref.watch(bleLinkProvider);

    // Fire-and-forget, guarded by `_remembered`. Persisting from build is not
    // ideal, but the alternative — a listener that has to be torn down — buys
    // nothing here, and a single idempotent write is cheaper than the ceremony.
    if (link.isLive && !_remembered) {
      _remember(link);
    }

    return _scaffold(
      switch (link.status) {
        BleLinkStatus.unsupported ||
        BleLinkStatus.adapterOff ||
        BleLinkStatus.permissionDenied =>
          _RadioUnusableView(link: link),
        BleLinkStatus.streaming => _ConnectedView(
            link: link,
            onScreening: () => context.go('/screening/new'),
            onDiagnostics: () => context.go('/devices/diagnostics'),
          ),
        BleLinkStatus.failed => _FailedView(link: link, onRetry: _connect),
        _ => _ConnectingView(link: link, fallbackName: widget.deviceName),
      },
    );
  }

  Widget _scaffold(Widget body) => AppPageScaffold(
        appBar: AppBar(
          title: Text(widget.demo ? 'Demo mode' : 'Device connection'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/devices/scan'),
          ),
        ),
        body: body,
      );
}

// ───────────────────────────── Connecting ─────────────────────────────

/// The stages a link actually goes through, in order.
///
/// Four, not seven: these are the four transitions the GATT layer reports.
/// Individual sensor chips are not enumerated here because nothing on the
/// connection path tells us whether an MLX90614 is present — the board's own
/// status frame does, and that is the diagnostics screen's job.
enum _Stage {
  link('Bluetooth link', 'Pairing with the board'),
  services('Device services', 'Finding out what the board offers'),
  handshake('Sensors', 'Asking the board to start measuring'),
  streaming('Readings', 'Frames arriving');

  const _Stage(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

enum _StageState { pending, active, done }

_StageState _stageState(_Stage stage, BleLinkStatus status) {
  int rank(BleLinkStatus s) => switch (s) {
        BleLinkStatus.connecting => 0,
        BleLinkStatus.discovering => 1,
        BleLinkStatus.handshaking => 2,
        BleLinkStatus.streaming => 3,
        // Reconnecting re-runs the link stage from the start.
        BleLinkStatus.reconnecting => 0,
        _ => -1,
      };

  final current = rank(status);
  final mine = stage.index;
  if (current < 0) return _StageState.pending;
  if (mine < current) return _StageState.done;
  if (mine == current) {
    return status == BleLinkStatus.streaming
        ? _StageState.done
        : _StageState.active;
  }
  return _StageState.pending;
}

class _ConnectingView extends StatelessWidget {
  final BleLinkState link;
  final String? fallbackName;

  const _ConnectingView({required this.link, this.fallbackName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = link.deviceName ?? fallbackName ?? 'Sensor board';

    return AppCenteredScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Icon(
                link.isInterrupted
                    ? Icons.bluetooth_searching_rounded
                    : Icons.bluetooth_connected_rounded,
                size: 52,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const AppSpacing.vlg(),
          Text(
            link.label,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vxs(),
          Text(
            name,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vsm(),
          Text(
            link.detail,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vxl(),
          for (final stage in _Stage.values)
            _StageRow(stage: stage, state: _stageState(stage, link.status)),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  final _Stage stage;
  final _StageState state;

  const _StageRow({required this.stage, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (state) {
      _StageState.pending => (
          Icons.radio_button_unchecked_rounded,
          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      _StageState.active => (Icons.sync_rounded, theme.colorScheme.primary),
      _StageState.done => (
          Icons.check_circle_rounded,
          theme.colorScheme.primary,
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const AppSpacing.hmd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: state == _StageState.pending
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
                Text(
                  stage.subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (state == _StageState.active) ...[
            const AppSpacing.hsm(),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── Connected ─────────────────────────────

class _ConnectedView extends StatelessWidget {
  final BleLinkState link;
  final VoidCallback onScreening;
  final VoidCallback onDiagnostics;

  const _ConnectedView({
    required this.link,
    required this.onScreening,
    required this.onDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compatibility =
        DeviceRepository.checkFirmware(link.firmwareVersion ?? 'UNKNOWN');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            border: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
            // Column, not Row: the battery pill and the device name together
            // overflow a 360 px line once the system font is turned up, and this
            // card is the first thing a worker reads.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg),
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const AppSpacing.hmd(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connected',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const AppSpacing.vxs(),
                          Text(
                            link.deviceName ?? 'Sensor board',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const AppSpacing.vmd(),
                Wrap(
                  spacing: AppTheme.spacingSm,
                  runSpacing: AppTheme.spacingXs,
                  children: [
                    // Only shown when the board actually reported it. A
                    // hardcoded "85%" was worse than no number at all.
                    if (link.batteryPercent != null)
                      _Fact(
                        icon: Icons.battery_std_rounded,
                        label: 'Battery ${link.batteryPercent}%',
                        isWarning: link.batteryPercent! <= 20,
                      ),
                    _Fact(
                      icon: Icons.developer_board_rounded,
                      label: link.firmwareVersion == null
                          ? 'Firmware unknown'
                          : 'v${link.firmwareVersion}',
                      isWarning: compatibility.needsWarning,
                    ),
                    _Fact(
                      icon: Icons.monitor_heart_rounded,
                      label: link.hasEcgChannel
                          ? 'ECG available'
                          : 'No ECG channel',
                      isWarning: !link.hasEcgChannel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (compatibility.needsWarning) ...[
            const AppSpacing.vmd(),
            _Notice(
              icon: Icons.warning_amber_rounded,
              tone: theme.colorScheme.error,
              title: compatibility.label,
              body: compatibility.detail,
            ),
          ],
          if (link.leadOff || link.fingerOff) ...[
            const AppSpacing.vmd(),
            _Notice(
              icon: Icons.touch_app_outlined,
              tone: theme.colorScheme.tertiary,
              title: 'Contact not detected',
              body: [
                if (link.fingerOff)
                  'The pulse sensor sees no finger — readings will be blank '
                      'until one is resting on it.',
                if (link.leadOff)
                  'The ECG electrodes are not making contact, so no trace will '
                      'be recorded.',
              ].join(' '),
            ),
          ],
          const AppSpacing.vlg(),
          AppButton(
            label: 'Start screening',
            icon: const Icon(Icons.play_arrow_rounded),
            minHeight: 52,
            onPressed: onScreening,
          ),
          const AppSpacing.vsm(),
          AppOutlinedButton(
            label: 'Run diagnostics',
            icon: const Icon(Icons.medical_services_outlined),
            minHeight: 48,
            onPressed: onDiagnostics,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Failure paths ─────────────────────────────

class _FailedView extends StatelessWidget {
  final BleLinkState link;
  final Future<void> Function() onRetry;

  const _FailedView({required this.link, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCenteredScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.bluetooth_disabled_rounded,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const AppSpacing.vlg(),
          Text(
            link.label,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vsm(),
          Text(
            link.detail,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vxl(),
          AppButton(
            label: 'Try again',
            icon: const Icon(Icons.refresh_rounded),
            minHeight: 52,
            onPressed: onRetry,
          ),
          const AppSpacing.vsm(),
          AppOutlinedButton(
            label: 'Choose another device',
            minHeight: 48,
            onPressed: () => context.go('/devices/scan'),
          ),
        ],
      ),
    );
  }
}

class _RadioUnusableView extends StatelessWidget {
  final BleLinkState link;

  const _RadioUnusableView({required this.link});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCenteredScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.bluetooth_disabled_rounded,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const AppSpacing.vlg(),
          Text(
            link.label,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vsm(),
          Text(
            link.detail,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vxl(),
          // Demo mode is the one thing that still works with no radio, so it is
          // offered here rather than leaving a dead end.
          AppOutlinedButton(
            label: 'Use demo mode instead',
            icon: const Icon(Icons.science_outlined),
            minHeight: 48,
            onPressed: () => context.go(
              '/devices/connect',
              extra: const {'demo': true},
            ),
          ),
        ],
      ),
    );
  }
}

class _NoDeviceChosenView extends StatelessWidget {
  const _NoDeviceChosenView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCenteredScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.devices_other_rounded,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const AppSpacing.vlg(),
          Text(
            'No device chosen',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vsm(),
          Text(
            'Pick a sensor board from the scan, or start a demo screening.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vxl(),
          AppButton(
            label: 'Find a device',
            icon: const Icon(Icons.bluetooth_searching_rounded),
            minHeight: 52,
            onPressed: () => context.go('/devices/scan'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Demo ─────────────────────────────

/// The demo entry point. No radio is touched, and the screen says so before the
/// first invented number appears.
class _DemoReadyView extends StatelessWidget {
  const _DemoReadyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCenteredScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Icon(
                Icons.science_outlined,
                size: 52,
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
          const AppSpacing.vlg(),
          Text(
            'Demo mode ready',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.tertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vsm(),
          Text(
            'No sensor board is connected. Every vital sign in this screening '
            'is invented, each reading and result is labelled as a demo, and '
            'none of it reaches the community totals.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vxl(),
          AppButton(
            label: 'Start demo screening',
            icon: const Icon(Icons.play_circle_outline_rounded),
            minHeight: 52,
            onPressed: () => context.go('/screening/new'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.tertiary,
              foregroundColor: theme.colorScheme.onTertiary,
            ),
          ),
          const AppSpacing.vsm(),
          AppOutlinedButton(
            label: 'Look for a real device',
            icon: const Icon(Icons.bluetooth_searching_rounded),
            minHeight: 48,
            onPressed: () => context.go('/devices/scan'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Small parts ─────────────────────────────

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isWarning;

  const _Fact({
    required this.icon,
    required this.label,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isWarning
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const AppSpacing.hxs(),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;
  final String body;

  const _Notice({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 22),
          const AppSpacing.hmd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const AppSpacing.vxs(),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
