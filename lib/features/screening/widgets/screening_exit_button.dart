import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';

/// The screening wizard's explicit way out.
///
/// The funnel is deliberately full-screen — no bottom bar, and on the result
/// step not even a back arrow — so this trailing ✕ is the one consistent
/// exit, from step 1 through the measurements. It confirms first: captured
/// readings are discarded by leaving before the result screen, and losing a
/// measurement mid-camp by fat-fingering the system back button is the exact
/// failure this app exists to prevent.
class ScreeningExitButton extends ConsumerWidget {
  const ScreeningExitButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return IconButton(
      icon: const Icon(Icons.close_rounded),
      tooltip: l10n.actionClose,
      onPressed: () async {
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.l10n.screeningExitTitle),
            content: Text(ctx.l10n.screeningExitBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(ctx.l10n.screeningExitStay),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(ctx.l10n.screeningExitLeave),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) {
          final account = ref.read(authStateProvider).account;
          context.go(
            account?.role == UserRole.patient ? '/my-health' : '/home',
          );
        }
      },
    );
  }
}
