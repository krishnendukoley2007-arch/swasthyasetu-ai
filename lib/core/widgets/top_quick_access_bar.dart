import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/features/devices/widgets/phone_fall_simulator_sheet.dart';

/// A sleek, high-visibility quick-access bar mounted at the top of main screens.
///
/// Gives frontline workers instant 1-tap control over:
/// 1. Demo / Live mode toggle
/// 2. Offline / Cloud status
/// 3. Language switcher (English / हिन्दी / বাংলা)
/// 4. Phone Accelerometer Fall Detection Simulator
class TopQuickAccessBar extends ConsumerWidget implements PreferredSizeWidget {
  const TopQuickAccessBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(42);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final link = ref.watch(bleLinkProvider);
    final settings = ref.watch(settingsProvider);
    final isLive = link.isLive;
    final currentLang = settings.locale.languageCode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // 1. Demo / Live mode pill — the text can shrink rather than push
          // the bar past the right edge at 2.0x text scale.
          Flexible(
            flex: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isLive
                          ? 'Connected to real hardware board (LIVE).'
                          : 'Running in Virtual Patient Simulator Mode (DEMO).',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLive ? AppTheme.riskGreenContainer : theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isLive ? AppTheme.riskGreen : theme.colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isLive ? 'LIVE' : 'DEMO',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isLive ? AppTheme.riskGreen : theme.colorScheme.onSecondaryContainer,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 2. Offline indicator — icon-only with tooltip. A worded chip
          // overflowed the bar at 2.0x text scale, and the icon carries the
          // same meaning at every scale.
          Tooltip(
            message: 'Works fully offline',
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),

          const Spacer(),

          // 3. Phone Accelerometer Fall Simulator Button
          IconButton(
            icon: const Icon(Icons.screen_rotation_alt_rounded, size: 18),
            tooltip: 'Phone IMU Fall Detector Test',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              PhoneFallSimulatorSheet.show(context);
            },
          ),

          const SizedBox(width: 4),

          // 4. Quick Language Switcher Dropdown
          PopupMenuButton<String>(
            tooltip: 'Change Language / भाषा बदलें',
            initialValue: currentLang,
            padding: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.language_rounded, size: 14, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 4),
                  Text(
                    switch (currentLang) {
                      'hi' => 'हिन्दी',
                      'bn' => 'বাংলা',
                      _ => 'EN',
                    },
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 14, color: theme.colorScheme.onPrimaryContainer),
                ],
              ),
            ),
            onSelected: (langCode) {
              ref.read(settingsProvider.notifier).setLocale(Locale(langCode));
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'en',
                child: Row(
                  children: [
                    Text('🇺🇸 English'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'hi',
                child: Row(
                  children: [
                    Text('🇮🇳 हिन्दी (Hindi)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'bn',
                child: Row(
                  children: [
                    Text('🇮🇳 বাংলা (Bengali)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
