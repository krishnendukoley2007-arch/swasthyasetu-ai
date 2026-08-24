import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/storage_manager.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/patient_repository.dart';

/// Storage accounting, space reclamation, export and deletion.
///
/// The three destructive-or-outbound actions on this screen (export, delete one
/// patient, wipe everything) are all behind an explicit confirmation and none of
/// them can be reached by anything but a tap — no timer, no sync, no background
/// task calls into them.
class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() =>
      _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends ConsumerState<StorageSettingsScreen> {
  bool _busy = false;
  String? _busyLabel;

  @override
  Widget build(BuildContext context) {
    final usage = ref.watch(storageUsageProvider);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Storage & Data'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recount',
            onPressed: () => ref.invalidate(storageUsageProvider),
          ),
        ],
      ),
      body: Stack(
        children: [
          usage.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorState(
              message: 'Could not measure storage.',
              onRetry: () => ref.invalidate(storageUsageProvider),
            ),
            data: (data) => ListView(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingXxl),
              children: [
                _BudgetCard(usage: data),
                _BreakdownCard(usage: data),
                _ReclaimCard(onRun: _runReclaim),
                _ExportCard(onExport: _exportPatient),
                _DeletionCard(
                  onDeletePatient: _deletePatient,
                  onWipe: _wipeEverything,
                ),
              ],
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context)
                    .colorScheme
                    .scrim
                    .withValues(alpha: 0.45),
                child: Center(
                  child: AppCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const AppSpacing.vmd(),
                        Text(_busyLabel ?? 'Working…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────── Actions ───────────────────────────────

  Future<T?> _guard<T>(String label, Future<T> Function() action) async {
    if (_busy) return null;
    setState(() {
      _busy = true;
      _busyLabel = label;
    });
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
        ref.invalidate(storageUsageProvider);
      }
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? scheme.errorContainer : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _runReclaim() async {
    final options = await showModalBottomSheet<_ReclaimOptions>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ReclaimSheet(),
    );
    if (options == null) return;

    final report = await _guard<ReclaimReport>(
      'Reclaiming space…',
      () => ref.read(storageManagerProvider).freeUpSpace(
            downsampleOldWaveforms: options.downsample,
            removeOrphans: options.removeOrphans,
            clearMapCache: options.clearMapTiles,
          ),
    );
    if (report == null) return;

    _toast(
      report.reclaimedAnything
          ? 'Freed ${formatBytes(report.total)}.'
          : 'Nothing to reclaim — storage is already tidy.',
    );
  }

  Future<void> _exportPatient() async {
    final patient = await _pickPatient(
      title: 'Export a patient',
      subtitle:
          'This writes that person\'s screening history to a file and opens the '
          'share sheet. Nothing is sent until you choose where to send it.',
    );
    if (patient == null) return;
    if (!mounted) return;

    final format = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSpacing.vsm(),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('CSV'),
              subtitle: const Text('Opens in any spreadsheet app'),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.data_object_rounded),
              title: const Text('JSON'),
              subtitle: const Text('Complete record, including triage rules'),
              onTap: () => Navigator.pop(ctx, 'json'),
            ),
            const AppSpacing.vsm(),
          ],
        ),
      ),
    );
    if (format == null) return;

    final file = await _guard<File>('Writing export…', () {
      final manager = ref.read(storageManagerProvider);
      return format == 'csv'
          ? manager.exportPatientCsv(patient.patient.id)
          : manager.exportPatientJson(patient.patient.id);
    });
    if (file == null) return;

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'SwasthyaSetu export — ${patient.patient.name}',
          text: 'Screening history for ${patient.patient.name}. '
              'Contains health data — share only with the intended recipient.',
        ),
      );
    } catch (_) {
      // No share target on this device. The file is still written, so say where.
      _toast('Saved to ${file.path}', isError: true);
    }
  }

  Future<void> _deletePatient() async {
    final patient = await _pickPatient(
      title: 'Delete a patient',
      subtitle:
          'Removes the person, every screening, and every waveform file. This '
          'cannot be undone.',
    );
    if (patient == null || !mounted) return;

    final confirmed = await _confirmDestructive(
      title: 'Delete ${patient.patient.name}?',
      body: 'Their ${patient.screeningCount} screening'
          '${patient.screeningCount == 1 ? '' : 's'} and all recorded waveforms '
          'will be deleted from this phone. Anything already synced to a server '
          'is not affected.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;

    await _guard<void>(
      'Deleting…',
      () =>
          ref.read(storageManagerProvider).deletePatientData(patient.patient.id),
    );
    _toast('${patient.patient.name} deleted.');
  }

  Future<void> _wipeEverything() async {
    final choice = await showModalBottomSheet<_WipeOptions>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _WipeSheet(),
    );
    if (choice == null || !mounted) return;

    final typed = await _confirmTyped();
    if (!typed) return;

    await _guard<void>(
      'Wiping all data…',
      () => ref.read(storageManagerProvider).wipeAllData(
            includeGuidelineCorpus: choice.includeGuidelines,
            includeMapTiles: choice.includeMapTiles,
            includeSettings: choice.includeSettings,
          ),
    );
    // Every list on the app is derived from these, so invalidate broadly rather
    // than leaving stale rows on screens the user navigates back to.
    ref.invalidate(patientSummariesProvider);
    ref.invalidate(communityAggregateProvider);
    _toast('All patient data wiped.');
  }

  // ─────────────────────────────── Pickers ───────────────────────────────

  Future<PatientSummary?> _pickPatient({
    required String title,
    required String subtitle,
  }) async {
    final summaries = ref.read(patientSummariesProvider).valueOrNull ?? const [];
    if (summaries.isEmpty) {
      _toast('There are no patients on this device.');
      return null;
    }
    return showModalBottomSheet<PatientSummary>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PatientPickerSheet(
        title: title,
        subtitle: subtitle,
        patients: summaries,
      ),
    );
  }

  Future<bool> _confirmDestructive({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// A typed confirmation, not just a second tap.
  ///
  /// A full wipe destroys every screening on the phone including ones that have
  /// not synced yet, and those are unrecoverable. Making the worker type the word
  /// is the difference between an accident and a decision.
  Future<bool> _confirmTyped() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final matches = controller.text.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            title: const Text('Wipe all patient data?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Every patient, screening and waveform on this phone will be '
                  'deleted, including anything not yet synced. Type DELETE to '
                  'confirm.',
                ),
                const AppSpacing.vmd(),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'DELETE',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                ),
                onPressed: matches ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Wipe everything'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return result == true;
  }
}

// ─────────────────────────────── Cards ───────────────────────────────

class _BudgetCard extends StatelessWidget {
  final StorageUsage usage;

  const _BudgetCard({required this.usage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final near = usage.isNearCapacity;
    final tint = near ? theme.colorScheme.error : theme.colorScheme.primary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sd_storage_outlined, size: 20, color: tint),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'On this phone',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${(usage.fractionOfBudget * 100).round()}%',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: tint),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          // A Baseline-free Wrap: at 2.0x the two figures cannot share a row.
          Wrap(
            spacing: AppTheme.spacingXs,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                usage.formattedTotal,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: tint),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'of ${usage.formattedBudget} budget',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: LinearProgressIndicator(
              value: usage.fractionOfBudget,
              minHeight: 10,
              color: tint,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const AppSpacing.vsm(),
          Text(
            near
                ? 'Nearly full. Free up space below before the next round of '
                    'screenings.'
                : 'Room for about ${usage.projectedRemainingScreenings} more '
                    'screenings at full waveform resolution.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: near ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final StorageUsage usage;

  const _BreakdownCard({required this.usage});

  /// Category ids are storage keys. Nothing raw reaches a `Text`.
  static const _labels = <String, ({String name, IconData icon, String unit})>{
    'patients': (name: 'Patients', icon: Icons.people_outline_rounded, unit: 'people'),
    'screenings': (
      name: 'Screenings',
      icon: Icons.assignment_outlined,
      unit: 'records'
    ),
    'waveforms': (
      name: 'ECG / PPG waveforms',
      icon: Icons.monitor_heart_outlined,
      unit: 'files'
    ),
    'guidelines': (
      name: 'Offline guidelines',
      icon: Icons.menu_book_outlined,
      unit: 'passages'
    ),
    'explanations': (
      name: 'Cached explanations',
      icon: Icons.chat_bubble_outline_rounded,
      unit: ''
    ),
    'mapTiles': (name: 'Offline map tiles', icon: Icons.map_outlined, unit: ''),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What is using it',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const AppSpacing.vsm(),
          for (final category in usage.breakdown)
            _BreakdownRow(
              label: _labels[category.id]?.name ?? category.id,
              icon: _labels[category.id]?.icon ?? Icons.folder_outlined,
              bytes: category.bytes,
              detail: category.itemCount > 0
                  ? '${category.itemCount} '
                      '${_labels[category.id]?.unit ?? 'items'}'
                  : null,
            ),
          const AppSpacing.vsm(),
          Text(
            'The database file measures ${formatBytes(usage.databaseFile)} on '
            'disk. Row sizes above are logical, so they will not add up to it.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final int bytes;
  final String? detail;

  const _BreakdownRow({
    required this.label,
    required this.icon,
    required this.bytes,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const AppSpacing.hsm(),
          // Expanded so a long category name wraps rather than pushing the size
          // off the right edge at large text scales.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                if (detail != null)
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const AppSpacing.hsm(),
          Text(
            formatBytes(bytes),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ReclaimCard extends StatelessWidget {
  final Future<void> Function() onRun;

  const _ReclaimCard({required this.onRun});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cleaning_services_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Free up space',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            'Older waveforms are reduced to a 5-second summary instead of being '
            'deleted, so the trend survives. No patient record is removed.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const AppSpacing.vmd(),
          AppOutlinedButton(
            label: 'Choose what to clear',
            icon: const Icon(Icons.tune_rounded),
            onPressed: onRun,
          ),
        ],
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final Future<void> Function() onExport;

  const _ExportCard({required this.onExport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.ios_share_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Export a patient',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            'Nothing is exported automatically. Data leaves this phone only '
            'when you pick a patient here and choose a destination.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const AppSpacing.vmd(),
          AppOutlinedButton(
            label: 'Export screening history',
            icon: const Icon(Icons.download_rounded),
            onPressed: onExport,
          ),
        ],
      ),
    );
  }
}

class _DeletionCard extends StatelessWidget {
  final Future<void> Function() onDeletePatient;
  final Future<void> Function() onWipe;

  const _DeletionCard({required this.onDeletePatient, required this.onWipe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      border: BorderSide(color: theme.colorScheme.error, width: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: theme.colorScheme.error,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Delete data',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            'Deletion removes database rows and the waveform files on disk. '
            'There is no recycle bin.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const AppSpacing.vmd(),
          AppOutlinedButton(
            label: 'Delete one patient',
            icon: const Icon(Icons.person_remove_outlined),
            onPressed: onDeletePatient,
          ),
          const AppSpacing.vsm(),
          AppOutlinedButton(
            label: 'Wipe all patient data',
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: onWipe,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Sheets ───────────────────────────────

class _ReclaimOptions {
  final bool downsample;
  final bool removeOrphans;
  final bool clearMapTiles;

  const _ReclaimOptions({
    required this.downsample,
    required this.removeOrphans,
    required this.clearMapTiles,
  });
}

class _ReclaimSheet extends StatefulWidget {
  const _ReclaimSheet();

  @override
  State<_ReclaimSheet> createState() => _ReclaimSheetState();
}

class _ReclaimSheetState extends State<_ReclaimSheet> {
  bool _downsample = true;
  bool _orphans = true;
  // Off by default: map tiles cannot be re-downloaded in the field, which is
  // the whole reason they were imported.
  bool _mapTiles = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Free up space',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const AppSpacing.vmd(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _downsample,
              onChanged: (v) => setState(() => _downsample = v),
              title: const Text('Summarise old waveforms'),
              subtitle: const Text(
                'Keeps the newest per patient at full resolution; older ones '
                'become a 5-second min/max/average trace.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _orphans,
              onChanged: (v) => setState(() => _orphans = v),
              title: const Text('Remove orphaned files'),
              subtitle: const Text(
                'Waveform files with no screening left to belong to.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _mapTiles,
              onChanged: (v) => setState(() => _mapTiles = v),
              title: const Text('Clear offline map tiles'),
              subtitle: const Text(
                'Frees the most space, but the map stops working offline until '
                'tiles are imported again.',
              ),
            ),
            const AppSpacing.vlg(),
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const AppSpacing.hmd(),
                Expanded(
                  child: AppButton(
                    label: 'Run',
                    onPressed: (_downsample || _orphans || _mapTiles)
                        ? () => Navigator.pop(
                              context,
                              _ReclaimOptions(
                                downsample: _downsample,
                                removeOrphans: _orphans,
                                clearMapTiles: _mapTiles,
                              ),
                            )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WipeOptions {
  final bool includeGuidelines;
  final bool includeMapTiles;
  final bool includeSettings;

  const _WipeOptions({
    required this.includeGuidelines,
    required this.includeMapTiles,
    required this.includeSettings,
  });
}

class _WipeSheet extends StatefulWidget {
  const _WipeSheet();

  @override
  State<_WipeSheet> createState() => _WipeSheetState();
}

class _WipeSheetState extends State<_WipeSheet> {
  bool _guidelines = false;
  bool _mapTiles = true;
  bool _settings = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Wipe all patient data',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
            ),
            const AppSpacing.vsm(),
            Text(
              'Patients, screenings and waveforms always go. These three are '
              'optional because losing them costs offline capability, not '
              'privacy.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const AppSpacing.vmd(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _guidelines,
              onChanged: (v) => setState(() => _guidelines = v),
              title: const Text('Also clear offline guidelines'),
              subtitle: const Text(
                'Offline explanations stop working until the app reseeds them.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _mapTiles,
              onChanged: (v) => setState(() => _mapTiles = v),
              title: const Text('Also clear map tiles'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _settings,
              onChanged: (v) => setState(() => _settings = v),
              title: const Text('Also reset settings'),
              subtitle: const Text(
                'Language, contrast, worker name, emergency contacts and '
                'consent choices return to defaults.',
              ),
            ),
            const AppSpacing.vlg(),
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const AppSpacing.hmd(),
                Expanded(
                  child: AppButton(
                    label: 'Continue',
                    onPressed: () => Navigator.pop(
                      context,
                      _WipeOptions(
                        includeGuidelines: _guidelines,
                        includeMapTiles: _mapTiles,
                        includeSettings: _settings,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientPickerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<PatientSummary> patients;

  const _PatientPickerSheet({
    required this.title,
    required this.subtitle,
    required this.patients,
  });

  @override
  State<_PatientPickerSheet> createState() => _PatientPickerSheetState();
}

class _PatientPickerSheetState extends State<_PatientPickerSheet> {
  final _search = TextEditingController();

  /// First letter of the first two words, so "Ratna Devi" reads "RD".
  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.patients
        : widget.patients
            .where((p) => p.patient.name.toLowerCase().contains(query))
            .toList();

    // Capped at 70% of the screen so the sheet never grows past the viewport at
    // large text scales with a long roster behind it.
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      widget.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const AppSpacing.vmd(),
                    AppSearchField(
                      controller: _search,
                      hint: 'Search by name',
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final summary = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(_initials(summary.patient.name)),
                      ),
                      title: Text(summary.patient.name),
                      subtitle: Text(
                        '${summary.screeningCount} screening'
                        '${summary.screeningCount == 1 ? '' : 's'}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(context, summary),
                    );
                  },
                ),
              ),
              const AppSpacing.vsm(),
            ],
          ),
        ),
      ),
    );
  }
}
