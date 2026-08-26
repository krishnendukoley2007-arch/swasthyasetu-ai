import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/constants/app_constants.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/gemini_service.dart'
    show GeminiFailureText;
import 'package:swasthyasetu_ai/core/services/storage_manager.dart' show formatBytes;
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/device_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/settings_repository.dart';
import 'package:swasthyasetu_ai/domain/models/audience.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';

/// The one screen where the app's behaviour is actually configured.
///
/// Every control here is bound to [settingsProvider] and lands in SQLite, so a
/// choice survives the process being killed between household visits. Nothing on
/// this screen is decorative: a toggle that does not change behaviour has been
/// removed rather than left in place looking functional.
///
/// Consolidates what §8 asked for in one place — storage usage, data export and
/// wipe, language, BLE device management, emergency contacts, BP calibration
/// date — plus the consent switches, which belong next to the data they govern.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          const _WorkerCard(),
          const AppSpacing.vlg(),

          _Section('Who is using this app', [
            _AudienceTile(selected: settings.audience),
          ]),

          _Section('Language', [
            _ChoiceTile(
              icon: Icons.language_rounded,
              title: 'App language',
              value: _AppLanguage.of(settings.locale).nativeName,
              onTap: () => _pickLanguage(context, ref, settings.locale),
            ),
          ]),

          _Section('Display', [
            _ThemeTile(mode: settings.themeMode),
            _Toggle(
              icon: Icons.contrast_rounded,
              title: 'High contrast',
              // The real reason this exists, stated plainly so nobody removes it
              // as a duplicate of dark mode.
              subtitle: 'Stronger borders and darker text for direct sunlight',
              value: settings.highContrast,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setHighContrast(v),
            ),
            _Toggle(
              icon: Icons.motion_photos_off_rounded,
              title: 'Reduce motion',
              subtitle: 'Turns off animated transitions and pulsing indicators',
              value: settings.reducedMotion,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setReducedMotion(v),
            ),
          ]),

          _Section('Device', [
            const _DeviceTile(),
            _Toggle(
              icon: Icons.science_outlined,
              title: 'Demo mode',
              subtitle: 'Simulated vitals, so the app is usable with no hardware',
              value: settings.demoMode,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setDemoMode(v),
            ),
            const _CalibrationTile(),
            _NavTile(
              icon: Icons.build_rounded,
              title: 'Run diagnostics',
              subtitle: 'Check each sensor and the BLE link',
              onTap: () => context.push('/devices/diagnostics'),
            ),
          ]),

          _Section('Emergency', [
            const _ContactsTile(),
            _Toggle(
              icon: Icons.personal_injury_outlined,
              title: 'Fall detection',
              subtitle: 'Watch the accelerometer and raise an SOS after a fall',
              value: settings.fallDetection,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setFallDetection(v),
            ),
            _Toggle(
              icon: Icons.crisis_alert_rounded,
              title: 'Offer SOS on high risk',
              subtitle: 'Suggest — never send — an SOS after a red triage band',
              value: settings.autoSuggestSos,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setAutoSuggestSos(v),
            ),
            _ChoiceTile(
              icon: Icons.timer_outlined,
              title: 'Cancel window',
              value: '${settings.sosCountdownSeconds} seconds',
              subtitle: 'How long you get to stop an automatic SOS',
              onTap: () =>
                  _pickCountdown(context, ref, settings.sosCountdownSeconds),
            ),
          ]),

          _Section('Data & privacy', [
            const _StorageTile(),
            _NavTile(
              icon: Icons.cloud_upload_outlined,
              title: 'Pending uploads',
              subtitle: 'Screenings waiting for a connection',
              onTap: () => context.push('/sync'),
            ),
            _Toggle(
              icon: Icons.sync_rounded,
              title: 'Upload screenings',
              subtitle: 'Send clinical records to the server when online',
              value: settings.syncConsent,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setSyncConsent(v),
            ),
            _Toggle(
              icon: Icons.my_location_rounded,
              title: 'Tag screenings with location',
              // Off by default. Saying so is part of the consent.
              subtitle: 'Off by default. Adds a coordinate to new screenings '
                  'and to any SOS you send',
              value: settings.locationConsent,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setLocationConsent(v),
            ),
            _Toggle(
              icon: Icons.cloud_outlined,
              title: 'Online AI explanations',
              subtitle: 'When off, explanations come from the on-device '
                  'guideline library instead',
              value: settings.aiConsent,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setAiConsent(v),
            ),
            const _GeminiKeyTile(),
          ]),

          _Section('About', [
            const _InfoTile(
              icon: Icons.info_outline_rounded,
              title: 'Version',
              value: '${AppConstants.appVersion} '
                  '(build ${AppConstants.appBuildNumber})',
            ),
            _NavTile(
              icon: Icons.tune_rounded,
              title: 'Triage thresholds',
              subtitle: 'The fixed rules that decide the risk band',
              onTap: () => _showThresholds(context),
            ),
            _NavTile(
              icon: Icons.description_outlined,
              title: 'Open source licences',
              subtitle: 'Third-party packages in this build',
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
              ),
            ),
          ]),

          const _DisclaimerCard(),
          const AppSpacing.vxl(),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    Locale current,
  ) async {
    final chosen = await showModalBottomSheet<_AppLanguage>(
      context: context,
      // Without this the sheet caps itself at 9/16 of the screen and clips its
      // last option; the real cap lives in [_PickerSheet].
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _PickerSheet(
        title: 'App language',
        children: [
          for (final lang in _AppLanguage.values)
            _OptionTile(
              // The native name first, because a worker looking for Bengali is
              // looking for "বাংলা", not for the English word.
              title: lang.nativeName,
              subtitle: lang.englishName,
              selected: lang == _AppLanguage.of(current),
              onTap: () => Navigator.pop(sheetContext, lang),
            ),
        ],
      ),
    );
    if (chosen != null) {
      await ref.read(settingsProvider.notifier).setLocale(chosen.locale);
    }
  }

  Future<void> _pickCountdown(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    const options = [5, 10, 15, 30];
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _PickerSheet(
        title: 'Cancel window',
        blurb: 'A detected fall waits this long before the SOS goes out, so a '
            'dropped phone does not alarm the family.',
        children: [
          for (final seconds in options)
            _OptionTile(
              title: '$seconds seconds',
              selected: seconds == current,
              onTap: () => Navigator.pop(sheetContext, seconds),
            ),
        ],
      ),
    );
    if (chosen != null) {
      await ref
          .read(settingsProvider.notifier)
          .setSosCountdownSeconds(chosen);
    }
  }

  void _showThresholds(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Triage thresholds'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fixed in this build. The rules engine decides the band; the '
                  'AI only explains it.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const AppSpacing.vmd(),
                for (final entry in AppConstants.riskThresholds.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingXs,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Flexible on both sides: the label wraps and the value
                        // keeps its digits at any text scale.
                        Flexible(
                          child: Text(
                            _humaniseThresholdKey(entry.key),
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const AppSpacing.hsm(),
                        Text(
                          '${entry.value}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

/// Threshold keys are camelCase map keys, not display strings. §8's rule is that
/// nothing raw reaches a `Text`, and that includes these.
String _humaniseThresholdKey(String key) {
  final spaced = key
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
      .toLowerCase();
  final fixed = spaced
      .replaceAll('spo2', 'SpO2')
      .replaceAll('hr', 'HR')
      .replaceAll('bp', 'BP')
      .replaceAll('ecg', 'ECG');
  return fixed[0].toUpperCase() + fixed.substring(1);
}

/// The three shipped locales, paired with the names a worker will look for.
///
/// A closed enum rather than a list of codes: an unknown language code from a
/// restored database resolves to English instead of rendering an empty tile.
enum _AppLanguage {
  english(Locale('en'), 'English', 'English'),
  hindi(Locale('hi'), 'हिन्दी', 'Hindi'),
  bengali(Locale('bn'), 'বাংলা', 'Bengali');

  const _AppLanguage(this.locale, this.nativeName, this.englishName);

  final Locale locale;
  final String nativeName;
  final String englishName;

  static _AppLanguage of(Locale locale) => values.firstWhere(
        (l) => l.locale.languageCode == locale.languageCode,
        orElse: () => english,
      );
}

// ───────────────────────────── Section shell ─────────────────────────────

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            bottom: AppTheme.spacingSm,
            left: AppTheme.spacingXs,
          ),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        AppElevatedCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
        const AppSpacing.vlg(),
      ],
    );
  }
}

/// Who the explanations are written for.
///
/// Two rows rather than a picker sheet, because this is the one setting a
/// first-time user has to get right and burying it behind a tap would leave a
/// patient reading nurse instructions without ever knowing there was a choice.
///
/// It changes the wording and what the AI may suggest. It does not change the
/// screening, the sensors, the rule engine or the risk band — all of which are
/// identical for both, and the tile says so rather than leaving anyone to guess
/// whether "patient mode" measures something different.
///
/// Read-only for a signed-in account. The mode used to be freely tappable here,
/// which meant a nurse account could switch to the patient prompt — the one that
/// deliberately drops the ban on naming medicines and home remedies — without
/// signing in as anybody. The role picked at sign-up decides now, and the rows
/// only show what that decision was. Demo mode has no account, so there the
/// choice is still the user's.
class _AudienceTile extends ConsumerWidget {
  const _AudienceTile({required this.selected});

  final Audience selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canChoose = ref.watch(canChooseAudienceProvider);
    // What the app will actually speak in, which for an account is its role and
    // not whatever `selected` was left at.
    final effective = ref.watch(effectiveAudienceProvider);
    final shown = canChoose ? selected : effective;

    return Column(
      children: [
        for (final option in Audience.values)
          _OptionTile(
            title: option.label,
            subtitle: option.description,
            selected: option == shown,
            locked: !canChoose,
            onTap: canChoose
                ? () => ref.read(settingsProvider.notifier).setAudience(option)
                : null,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            0,
            AppTheme.spacingMd,
            AppTheme.spacingMd,
          ),
          child: Text(
            canChoose
                ? 'This only changes how results are explained. The screening, '
                    'the sensors and the risk level are the same either way.'
                : 'Set by the account you signed in with, and not changeable '
                    'here — the wording a result is explained in has to match '
                    'who the account belongs to. Sign in with a different '
                    'account to change it. Either way the screening, the '
                    'sensors and the risk level are identical.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// One selectable row in a picker sheet.
///
/// Hand-rolled rather than a `RadioListTile` because that widget's `groupValue`
/// and `onChanged` are deprecated in this Flutter in favour of a `RadioGroup`
/// ancestor, and a tick on the selected row reads the same to the worker.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.locked = false,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  /// Dims the rows that are not in force and shows a lock on the one that is,
  /// so a read-only tile reads as "decided" rather than as a control that has
  /// stopped responding to taps.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimmed = locked && !selected;

    return ListTile(
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected
              ? theme.colorScheme.primary
              : dimmed
                  ? theme.colorScheme.onSurfaceVariant
                  : null,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: dimmed
                  ? theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                  : null,
            ),
      trailing: selected
          ? Icon(
              locked ? Icons.lock_rounded : Icons.check_rounded,
              color: theme.colorScheme.primary,
            )
          : null,
      onTap: onTap,
    );
  }
}

/// The body of every picker sheet on this screen.
///
/// Exists because a plain `Column` inside `showModalBottomSheet` overflows:
/// the sheet caps itself at 9/16 of the screen, and four options plus a title
/// and a blurb already exceed that once the system font is turned up. Capping
/// the height and scrolling means the last option stays reachable at 2.0x text
/// scale instead of being clipped off the bottom edge.
class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.children,
    this.blurb,
  });

  final String title;
  final String? blurb;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetTitle(title),
              if (blurb != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLg,
                  ),
                  child: Text(blurb!, textAlign: TextAlign.center),
                ),
              if (blurb != null) const AppSpacing.vmd(),
              ...children,
              const AppSpacing.vmd(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
}

// ───────────────────────────── Tiles ─────────────────────────────

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // No activeColor override: the switch already picks up the scheme, and the
    // explicit one that used to be here is deprecated.
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      secondary: Icon(icon, color: theme.colorScheme.primary),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
    );
  }
}

/// A tile whose current value lives under the title rather than in `trailing`.
///
/// Deliberate: a trailing value competes with the title for a 360 px row, and at
/// 2.0x text scale one of the two always loses. Below the title, both wrap.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null)
            Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: theme.textTheme.bodySmall),
          if (badge != null) ...[
            const AppSpacing.vxs(),
            badge!,
          ],
        ],
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: Text(
        value,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Where the Gemini credential is entered.
///
/// Exists because the key was previously a compile-time constant, which meant a
/// lapsed or revoked credential could only be replaced by rebuilding the APK —
/// no use to someone in a field office. Stored in the local settings table and
/// pushed into [GeminiService] on the next request.
///
/// The key is masked by default and never logged. "Test" makes one real
/// round-trip so a bad paste is caught here rather than discovered halfway
/// through a screening.
class _GeminiKeyTile extends ConsumerStatefulWidget {
  const _GeminiKeyTile();

  @override
  ConsumerState<_GeminiKeyTile> createState() => _GeminiKeyTileState();
}

class _GeminiKeyTileState extends ConsumerState<_GeminiKeyTile> {
  bool _editing = false;
  bool _testing = false;
  String? _result;

  /// Eagerly constructed, not `late`. A lazily-initialised field whose
  /// initialiser touches `ref` blows up in `dispose()` when the tile scrolled
  /// out of view without ever building — the initialiser runs for the first time
  /// against a disposed element.
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(settingsProvider).geminiApiKey;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Enough to recognise which key is in place, not enough to leak it over a
  /// shoulder or into a screenshot.
  static String _mask(String key) {
    if (key.isEmpty) return '';
    if (key.length <= 10) return '•' * key.length;
    return '${key.substring(0, 6)}…${key.substring(key.length - 4)}';
  }

  Future<void> _save() async {
    await ref
        .read(settingsProvider.notifier)
        .setGeminiApiKey(_controller.text);
    if (!mounted) return;
    setState(() {
      _editing = false;
      _result = null;
    });
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    // Save first: the service reads the stored value, so testing an unsaved
    // field would test the previous key and report a misleading result.
    await ref
        .read(settingsProvider.notifier)
        .setGeminiApiKey(_controller.text);
    final failure = await ref.read(geminiServiceProvider).testKey();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _result = failure == null
          ? 'Key works. Online explanations and follow-up questions are '
              'available.'
          : '${failure.label}. ${failure.detail}';
      if (failure == null) _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = ref.watch(geminiServiceProvider);
    final stored = ref.watch(settingsProvider).geminiApiKey;
    final active = service.apiKey;

    final subtitle = switch (true) {
      _ when active.isEmpty =>
        'Not set. Explanations will come from the on-device guideline library.',
      _ when stored.isEmpty =>
        'Using the key built into this app (${_mask(active)}). Paste your own to '
            'replace it.',
      _ => 'Your key: ${_mask(stored)}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
          leading: Icon(Icons.key_rounded, color: theme.colorScheme.primary),
          title: Text('Gemini API key', style: theme.textTheme.bodyLarge),
          subtitle: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: TextButton(
            onPressed: () => setState(() => _editing = !_editing),
            child: Text(_editing ? 'Cancel' : 'Change'),
          ),
        ),
        if (service.keyIsLegacyStandard && !_editing)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMd,
              0,
              AppTheme.spacingMd,
              AppTheme.spacingSm,
            ),
            child: Text(
              'This is an old-style "AIza" Standard key. Google stops accepting '
              'those for the Gemini API in September 2026. Make a replacement '
              'at aistudio.google.com/apikey — new keys start "AQ." — and '
              'paste it here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
        if (_editing)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMd,
              0,
              AppTheme.spacingMd,
              AppTheme.spacingMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: theme.textTheme.bodyMedium,
                  decoration: const InputDecoration(
                    labelText: 'Paste key',
                    hintText: 'AQ.…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const AppSpacing.vsm(),
                // Wrap, not Row: two buttons plus a progress indicator do not
                // fit a 360 px line at 2.0x text scale.
                Wrap(
                  spacing: AppTheme.spacingSm,
                  runSpacing: AppTheme.spacingSm,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _testing ? null : _save,
                      child: const Text('Save'),
                    ),
                    FilledButton(
                      onPressed: _testing ? null : _test,
                      child: Text(_testing ? 'Testing…' : 'Save & test'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMd,
              0,
              AppTheme.spacingMd,
              AppTheme.spacingMd,
            ),
            child: Text(
              _result!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // The segmented control sits under the tile, not in `trailing`: three
    // labelled segments need more width than a 360 px row has left over, and at
    // large text scales they were being laid out with no size at all.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
          leading: Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
          title: Text('Theme', style: theme.textTheme.bodyLarge),
          subtitle: Text(
            'Light, dark, or follow the phone',
            style: theme.textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.spacingMd,
            right: AppTheme.spacingMd,
            bottom: AppTheme.spacingMd,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AppSegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_rounded, size: 18),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (value) =>
                  ref.read(settingsProvider.notifier).setThemeMode(value.first),
            ),
          ),
        ),
      ],
    );
  }
}

/// Worker identity, shown at the top because it is what goes out on an SOS.
class _WorkerCard extends ConsumerWidget {
  const _WorkerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final named = settings.hasWorkerProfile;

    return AppElevatedCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.badge_outlined,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const AppSpacing.hmd(),
          // Expanded, not a bare Text: a long facility name in a Row with no
          // flex gets unbounded width and overflows before it can wrap.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  named ? settings.workerName : 'Health worker',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const AppSpacing.vxs(),
                Text(
                  [
                    if (settings.workerId.trim().isNotEmpty) settings.workerId,
                    if (settings.facility.trim().isNotEmpty) settings.facility,
                  ].join(' · ').ifEmpty('Add your name so it appears on an SOS'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const AppSpacing.hsm(),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context, ref, settings),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    AppSettingsSnapshot settings,
  ) async {
    final name = TextEditingController(text: settings.workerName);
    final id = TextEditingController(text: settings.workerId);
    final facility = TextEditingController(text: settings.facility);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        // The keyboard inset, so the last field is not under the keyboard.
        padding: EdgeInsets.only(
          left: AppTheme.spacingMd,
          right: AppTheme.spacingMd,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom +
              AppTheme.spacingMd,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetTitle('Your details'),
              AppTextField(controller: name, label: 'Name'),
              const AppSpacing.vmd(),
              AppTextField(controller: id, label: 'Worker ID'),
              const AppSpacing.vmd(),
              AppTextField(controller: facility, label: 'Facility'),
              const AppSpacing.vlg(),
              AppButton(
                label: 'Save',
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
              const AppSpacing.vmd(),
            ],
          ),
        ),
      ),
    );

    if (saved == true) {
      await ref.read(settingsProvider.notifier).setWorkerProfile(
            name: name.text.trim(),
            id: id.text.trim(),
            facility: facility.text.trim(),
          );
    }
    name.dispose();
    id.dispose();
    facility.dispose();
  }
}

class _StorageTile extends ConsumerWidget {
  const _StorageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(storageUsageProvider);
    return _NavTile(
      icon: Icons.storage_rounded,
      title: 'Storage, export & deletion',
      subtitle: usage.when(
        data: (u) => '${formatBytes(u.total)} used · '
            '${u.screeningCount} screenings',
        loading: () => 'Measuring…',
        // A failed measurement must not read as "0 bytes used".
        error: (_, __) => 'Usage unavailable',
      ),
      onTap: () => context.push('/settings/storage'),
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(pairedDevicesProvider);
    return _NavTile(
      icon: Icons.devices_rounded,
      title: 'Paired devices',
      subtitle: devices.when(
        data: (list) => switch (list.length) {
          0 => 'None paired yet',
          1 => list.first.name,
          final n => '$n devices',
        },
        loading: () => 'Loading…',
        error: (_, __) => 'Could not read paired devices',
      ),
      onTap: () => context.push('/devices/scan'),
    );
  }
}

class _ContactsTile extends ConsumerWidget {
  const _ContactsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsProvider);
    final count = contacts.valueOrNull?.length ?? 0;
    final reachable = ref.watch(hasReachableContactProvider);

    return _NavTile(
      icon: Icons.contact_phone_outlined,
      title: 'Emergency contacts',
      subtitle: count == 0
          ? 'None yet — an SOS has nowhere to go'
          : '$count ${count == 1 ? 'contact' : 'contacts'} saved',
      // A warning rather than a silent zero: a worker who thinks SOS is armed
      // when it is not is worse off than one who knows it is not.
      badge: reachable
          ? null
          : AppPillLabel(
              label: 'SOS not armed',
              leadingIcon: Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
      onTap: () => context.push('/emergency/contacts'),
    );
  }
}

class _CalibrationTile extends ConsumerWidget {
  const _CalibrationTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calibration = ref.watch(bpCalibrationProvider);

    return calibration.when(
      loading: () => const _InfoTile(
        icon: Icons.monitor_heart_outlined,
        title: 'BP calibration',
        value: 'Checking…',
      ),
      error: (_, __) => const _InfoTile(
        icon: Icons.monitor_heart_outlined,
        title: 'BP calibration',
        value: 'Unavailable',
      ),
      data: (c) => _InfoTile(
        icon: Icons.monitor_heart_outlined,
        title: 'BP calibration',
        // c.label is already humanised ('Not calibrated' / 'Calibration
        // expired'), so the enum never reaches the screen.
        value: switch (c.state) {
          CalibrationState.never =>
            '${c.label} — cuffless BP stays hidden until it is',
          CalibrationState.valid =>
            '${c.label} · ${_ago(c.daysSince!)} · ${c.systolic}/${c.diastolic}',
          CalibrationState.stale =>
            '${c.label} · last done ${_ago(c.daysSince!)}',
        },
      ),
    );
  }

  static String _ago(int days) => switch (days) {
        0 => 'today',
        1 => 'yesterday',
        final d when d < 30 => '$d days ago',
        final d => '${d ~/ 30} months ago',
      };
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.15),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      border: BorderSide(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.tertiary),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'What this app is not',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          Text(
            'SwasthyaSetu AI is a screening and decision-support tool. It is not '
            'a certified medical device and it does not diagnose. The '
            'deterministic rules engine decides the risk band; the AI only puts '
            'that result into words. Cuffless blood pressure is experimental and '
            'is not clinically validated. Every result needs a qualified '
            'clinician to confirm it.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

extension _FallbackString on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
