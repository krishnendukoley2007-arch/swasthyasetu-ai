import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/core/services/permission_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/device_repository.dart';
import 'package:swasthyasetu_ai/domain/models/device.dart';

/// Find a sensor board — or decide not to use one.
///
/// The organising principle is that a simulated reading and a measured reading
/// must never be one tap apart in the same list. The previous version of this
/// screen put "SwasthyaSetu Demo Device" in the scan results alongside real
/// radios, which makes choosing demo mode something a worker can do by accident
/// and then not notice. Here the demo path is a separate, differently-coloured
/// section at the bottom, under its own heading, with its own copy saying the
/// numbers are invented.
///
/// The three sections, in the order a worker needs them:
///
/// 1. **Previously used** — boards from the local database. Instant reconnect,
///    no scan required, and the one a health worker will use every day.
/// 2. **Nearby** — live scan results. Everything the radio can see, with the
///    boards this app recognises sorted to the top and badged, because a scan
///    that silently hides an unrecognised board is indistinguishable from a
///    scan that found nothing.
/// 3. **Demo mode** — no hardware, clearly labelled as simulated.
class DeviceScanScreen extends ConsumerStatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  ConsumerState<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends ConsumerState<DeviceScanScreen> {
  /// Cached rather than read through `ref` on demand: `dispose` cannot use
  /// `ref`, and the scan has to be stopped when the screen goes away or the
  /// radio keeps burning battery in the background.
  BleService? _ble;

  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: reading a provider during initState throws, and
    // starting a radio scan before the screen is painted means the spinner
    // appears late.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ble = ref.read(bleServiceProvider);
      _scan();
    });
  }

  @override
  void dispose() {
    _ble?.stopScan();
    super.dispose();
  }

  Future<void> _scan() async {
    final ble = _ble;
    if (ble == null) return;

    // Runtime permissions must come first. On Android 12+ the OS reports the
    // adapter state as "unknown" to an app holding no Bluetooth permission,
    // and BleService maps that to the "Bluetooth is off" banner — so a missing
    // permission looks exactly like a switched-off radio. Asking at the moment
    // of need is also the only thing that makes the permission appear in the
    // system's app-permissions page at all.
    final bluetooth = await PermissionService.requestBluetoothPermissions();
    if (!bluetooth.isGranted) {
      if (mounted) {
        PermissionService.showPermissionSnackBar(
          context: context,
          message:
              'Bluetooth and location access are needed to find the board.',
          permission: Permission.bluetoothConnect,
          onOpenSettings: PermissionService.openAppSettings,
        );
      }
      return;
    }

    setState(() => _scanning = true);
    await ble.startScan();
    if (mounted) setState(() => _scanning = false);
  }

  /// Hand off to the connection screen, which owns the handshake.
  ///
  /// The board is not connected here: doing it on this screen would mean the
  /// worker watches a spinner on a list row with nowhere to show a firmware
  /// warning or a retry countdown.
  void _openConnection({String? remoteId, String? name, bool demo = false}) {
    context.go(
      '/devices/connect',
      extra: {
        if (remoteId != null) 'remoteId': remoteId,
        if (name != null) 'name': name,
        'demo': demo,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final link = ref.watch(bleLinkProvider);
    final candidates = ref.watch(bleCandidatesProvider).maybeWhen(
          data: (list) => list,
          orElse: () => const <BleCandidate>[],
        );
    final paired = ref.watch(pairedDevicesProvider).maybeWhen(
          data: (list) => list.where((d) => !d.isDemo).toList(),
          orElse: () => const <Device>[],
        );

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Find device'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            tooltip: 'Rescan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _scanning ? null : _scan,
          ),
        ],
      ),
      // One scrollable for the whole page. Each section is taller than a short
      // screen at 2.0x text scale, so none of them can be a fixed-height child.
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingXl),
        children: [
          if (!link.isRadioUsable) _RadioUnavailableBanner(state: link),
          if (paired.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Previously used',
              subtitle: 'Boards this phone has connected to before.',
              icon: Icons.history_rounded,
            ),
            ...paired.map(
              (d) => _PairedDeviceCard(
                device: d,
                onConnect: () => _openConnection(
                  remoteId: d.macAddress,
                  name: d.name,
                ),
              ),
            ),
          ],
          _SectionHeader(
            title: 'Nearby',
            subtitle: link.isRadioUsable
                ? 'Everything Bluetooth can see right now.'
                : 'Unavailable until Bluetooth is on.',
            icon: Icons.bluetooth_searching_rounded,
            trailing: _scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          if (!link.isRadioUsable)
            const SizedBox.shrink()
          else if (candidates.isEmpty)
            _NearbyEmptyState(scanning: _scanning, onRescan: _scan)
          else
            ...candidates.map(
              (c) => _CandidateCard(
                candidate: c,
                onConnect: () =>
                    _openConnection(remoteId: c.id, name: c.displayName),
              ),
            ),
          const AppSpacing.vlg(),
          // Deliberately last, deliberately a different colour, deliberately not
          // in the list above.
          _DemoModeSection(onStart: () => _openConnection(demo: true)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingLg,
        AppTheme.spacingMd,
        AppTheme.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (trailing != null) ...[
                const AppSpacing.hsm(),
                trailing!,
              ],
            ],
          ),
          const AppSpacing.vxs(),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Shown when the radio cannot be used at all — off, unsupported, or refused.
///
/// Worth its own banner because the three causes need three different actions,
/// and "no devices found" would be a lie for all of them.
class _RadioUnavailableBanner extends StatelessWidget {
  final BleLinkState state;

  const _RadioUnavailableBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.bluetooth_disabled_rounded,
            color: theme.colorScheme.error,
            size: 22,
          ),
          const AppSpacing.hmd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const AppSpacing.vxs(),
                Text(state.detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A board from the local database.
///
/// Everything on this card is a stored fact — the last connection time and
/// firmware come from the row the app wrote when it last talked to this board.
/// The previous version of this screen invented both, which meant the list
/// looked identical whether or not the phone had ever seen a device.
class _PairedDeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onConnect;

  const _PairedDeviceCard({required this.device, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compatibility =
        DeviceRepository.checkFirmware(device.firmwareVersion);

    return AppCard(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        0,
        AppTheme.spacingMd,
        AppTheme.spacingSm,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DeviceAvatar(
                icon: Icons.memory_rounded,
                color: theme.colorScheme.primary,
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      _lastSeen(device.lastConnectedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          // Wrap, not Row: at 2.0x text scale three pills do not fit on a line,
          // and a Row would clip the firmware warning — the one thing here a
          // worker most needs to see.
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingXs,
            children: [
              _Pill(
                icon: Icons.battery_std_rounded,
                label: '${device.batteryPercent}%',
                tone: device.batteryPercent <= 20
                    ? _PillTone.warning
                    : _PillTone.neutral,
              ),
              _Pill(
                icon: Icons.developer_board_rounded,
                label: device.firmwareVersion == 'UNKNOWN'
                    ? 'Firmware unknown'
                    : 'v${device.firmwareVersion}',
                tone: compatibility.needsWarning
                    ? _PillTone.warning
                    : _PillTone.neutral,
              ),
              if (device.calibrationDate != null)
                const _Pill(
                  icon: Icons.tune_rounded,
                  label: 'BP calibrated',
                  tone: _PillTone.neutral,
                ),
            ],
          ),
          if (compatibility.needsWarning) ...[
            const AppSpacing.vsm(),
            Text(
              compatibility.detail,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const AppSpacing.vmd(),
          AppButton(
            label: 'Connect',
            icon: const Icon(Icons.bluetooth_connected_rounded, size: 20),
            minHeight: 48,
            onPressed: onConnect,
          ),
        ],
      ),
    );
  }

  /// Relative where relative is useful, absolute once it stops being.
  static String _lastSeen(DateTime at) {
    final delta = DateTime.now().difference(at);
    if (delta.inMinutes < 1) return 'Connected moments ago';
    if (delta.inMinutes < 60) return 'Connected ${delta.inMinutes} min ago';
    if (delta.inHours < 24) return 'Connected ${delta.inHours} h ago';
    if (delta.inDays == 1) return 'Connected yesterday';
    if (delta.inDays < 30) return 'Connected ${delta.inDays} days ago';
    return 'Last connected ${at.day}/${at.month}/${at.year}';
  }
}

/// A live scan result.
class _CandidateCard extends StatelessWidget {
  final BleCandidate candidate;
  final VoidCallback onConnect;

  const _CandidateCard({required this.candidate, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recognised = candidate.isSensorBoard;

    return AppCard(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        0,
        AppTheme.spacingMd,
        AppTheme.spacingSm,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Row(
        children: [
          _DeviceAvatar(
            icon: recognised
                ? Icons.monitor_heart_rounded
                : Icons.bluetooth_rounded,
            color: recognised
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const AppSpacing.hmd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: recognised ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const AppSpacing.vxs(),
                Text(
                  recognised
                      ? 'SwasthyaSetu board • signal ${candidate.signalBars}/4'
                      : 'Not a SwasthyaSetu board • signal ${candidate.signalBars}/4',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: recognised
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const AppSpacing.hsm(),
          // An unrecognised radio still gets a button. The recognition rule is a
          // heuristic over an advertisement packet, and a board with the wrong
          // name should not be unreachable — the handshake will reject it
          // clearly if it really is someone's headphones.
          AppOutlinedButton(
            label: 'Connect',
            isExpanded: false,
            minWidth: 108,
            minHeight: 44,
            onPressed: onConnect,
          ),
        ],
      ),
    );
  }
}

class _NearbyEmptyState extends StatelessWidget {
  final bool scanning;
  final VoidCallback onRescan;

  const _NearbyEmptyState({required this.scanning, required this.onRescan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingLg,
      ),
      child: Column(
        children: [
          Icon(
            scanning
                ? Icons.bluetooth_searching_rounded
                : Icons.search_off_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const AppSpacing.vmd(),
          Text(
            scanning ? 'Searching…' : 'Nothing nearby',
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vxs(),
          Text(
            scanning
                ? 'Hold the board within a metre of the phone.'
                : 'Check the board is switched on and its light is blinking, '
                    'then scan again.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (!scanning) ...[
            const AppSpacing.vmd(),
            AppOutlinedButton(
              label: 'Scan again',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              isExpanded: false,
              minWidth: 150,
              minHeight: 48,
              onPressed: onRescan,
            ),
          ],
        ],
      ),
    );
  }
}

/// The demo path, kept visually and physically apart from the real one.
///
/// Dashed border, tertiary colour, its own heading, and copy that says the word
/// "invented". A worker who lands in demo mode should know it before the first
/// number appears, not after they have written it in a register.
class _DemoModeSection extends StatelessWidget {
  final VoidCallback onStart;

  const _DemoModeSection({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.science_outlined,
                color: theme.colorScheme.tertiary,
                size: 22,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'No hardware here?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            'Demo mode walks through a complete screening using invented vital '
            'signs. Nothing is measured. Every reading and result it produces is '
            'labelled as a demo, and it is kept out of the community totals.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const AppSpacing.vmd(),
          AppButton(
            label: 'Start demo screening',
            icon: const Icon(Icons.play_circle_outline_rounded, size: 22),
            minHeight: 52,
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.tertiary,
              foregroundColor: theme.colorScheme.onTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceAvatar extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _DeviceAvatar({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

enum _PillTone { neutral, warning }

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final _PillTone tone;

  const _Pill({required this.icon, required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tone == _PillTone.warning
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
      // A Wrap gives its children a bounded width, so Flexible here shrinks
      // correctly instead of measuring against infinity the way a plain Row
      // child would.
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
