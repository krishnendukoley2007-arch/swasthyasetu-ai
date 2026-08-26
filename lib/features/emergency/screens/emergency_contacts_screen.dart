import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';
import 'package:uuid/uuid.dart';

/// Manages the people an SOS reaches.
///
/// Contacts live only on this device and are never part of a sync payload — the
/// uploaded data is aggregate and clinical, and a family member's phone number
/// has no place in it.
class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final contacts = ref.watch(emergencyContactsProvider);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editContact(context, ref, null),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Add contact'),
      ),
      body: contacts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState(
          message: 'Could not load contacts.',
          onRetry: () => ref.invalidate(emergencyContactsProvider),
        ),
        data: (list) => ListView(
          // Room for the FAB to sit over empty space rather than over the last
          // contact's delete button.
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _PrivacyNote(),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingXl),
                child: AppEmptyState(
                  icon: Icons.contact_phone_outlined,
                  title: 'No contacts yet',
                  subtitle:
                      'SOS needs at least one number. Add a supervisor, a PHC, '
                      'or a local ambulance line (108).',
                  action: AppButton(
                    label: 'Add first contact',
                    icon: const Icon(Icons.person_add_alt_rounded),
                    isExpanded: false,
                    onPressed: () => _editContact(context, ref, null),
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingLg,
                  AppTheme.spacingMd,
                  AppTheme.spacingLg,
                  AppTheme.spacingXs,
                ),
                child: Text(
                  '${list.length} contact${list.length == 1 ? '' : 's'} '
                  '• all are messaged on SOS',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ...list.map(
                (c) => _ContactCard(
                  contact: c,
                  onEdit: () => _editContact(context, ref, c),
                  onDelete: () => _confirmDelete(context, ref, c),
                  onMakePrimary: c.isPrimary
                      ? null
                      : () => ref
                          .read(emergencyRepositoryProvider)
                          .saveContact(c.copyWith(isPrimary: true)),
                  onCall: () => ref.read(sosServiceProvider).call(c.phone),
                ),
              ),
            ],
            const AppSpacing.vlg(),
            _QuickAddSection(
              onAdd: (name, phone, relation) =>
                  ref.read(emergencyRepositoryProvider).saveContact(
                        EmergencyContact(
                          id: const Uuid().v4(),
                          name: name,
                          phone: phone,
                          relation: relation,
                          isPrimary: list.isEmpty,
                          sortOrder: list.length,
                        ),
                      ),
              existingPhones: list.map((c) => c.phone).toSet(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editContact(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact? existing,
  ) async {
    final result = await showModalBottomSheet<EmergencyContact>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContactEditor(existing: existing),
    );
    if (result == null) return;
    await ref.read(emergencyRepositoryProvider).saveContact(result);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact contact,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        title: const Text('Remove contact?'),
        content: Text(
          '${contact.name} will no longer be messaged when you send an SOS.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(emergencyRepositoryProvider).deleteContact(contact.id);
  }
}

class _PrivacyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: BorderSide.none,
      elevation: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const AppSpacing.hsm(),
          Expanded(
            child: Text(
              'Contacts stay on this phone. They are never uploaded and never '
              'included in sync. SOS uses SMS, so it works with no internet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMakePrimary;
  final VoidCallback onCall;

  const _ContactCard({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
    required this.onMakePrimary,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reachable = EmergencyRepository.isDiallable(contact.phone);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: contact.isPrimary
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  contact.initials,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: contact.isPrimary
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      contact.phone,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          // A Wrap, so the badges drop onto extra lines at large text scales
          // instead of running past the card edge.
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (contact.isPrimary)
                AppPillLabel(
                  label: 'Primary',
                  leadingIcon: Icons.star_rounded,
                  color: theme.colorScheme.primary,
                ),
              if (contact.relation.trim().isNotEmpty)
                AppPillLabel(
                  label: contact.relation,
                  leadingIcon: Icons.people_outline_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              if (!reachable)
                AppPillLabel(
                  label: 'Number looks wrong',
                  leadingIcon: Icons.error_outline_rounded,
                  color: theme.colorScheme.error,
                ),
            ],
          ),
          const AppSpacing.vsm(),
          // Also a Wrap: three labelled actions cannot share a 360 px row once
          // the system font is scaled up.
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingXs,
            children: [
              if (reachable)
                TextButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Call'),
                ),
              if (onMakePrimary != null)
                TextButton.icon(
                  onPressed: onMakePrimary,
                  icon: const Icon(Icons.star_outline_rounded, size: 18),
                  label: const Text('Make primary'),
                ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The national emergency numbers, offered as one-tap adds.
///
/// Typing a number correctly under pressure is not something to rely on, and
/// these three are the ones a worker in India actually needs.
class _QuickAddSection extends StatelessWidget {
  final void Function(String name, String phone, String relation) onAdd;
  final Set<String> existingPhones;

  const _QuickAddSection({required this.onAdd, required this.existingPhones});

  static const _presets = [
    ('Ambulance (108)', '108', 'Emergency service'),
    ('National emergency (112)', '112', 'Emergency service'),
    ('Health helpline (104)', '104', 'Emergency service'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = _presets
        .where((p) => !existingPhones.contains(p.$2))
        .toList();
    if (available.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppTheme.spacingLg),
          child: Text(
            'Quick add',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const AppSpacing.vxs(),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (label, number, relation) in available)
                ListTile(
                  leading: Icon(
                    Icons.local_hospital_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(label, style: theme.textTheme.bodyLarge),
                  trailing: const Icon(Icons.add_rounded),
                  onTap: () => onAdd(label, number, relation),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactEditor extends StatefulWidget {
  final EmergencyContact? existing;

  const _ContactEditor({this.existing});

  @override
  State<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<_ContactEditor> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _relation;
  late bool _isPrimary;

  String? _nameError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
    _relation = TextEditingController(text: widget.existing?.relation ?? '');
    _isPrimary = widget.existing?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relation.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final phone = _phone.text.trim();

    setState(() {
      _nameError = name.isEmpty ? 'A name is required' : null;
      _phoneError = EmergencyRepository.isDiallable(phone)
          ? null
          : 'Enter a number that can be dialled';
    });
    if (_nameError != null || _phoneError != null) return;

    Navigator.pop(
      context,
      EmergencyContact(
        id: widget.existing?.id ?? const Uuid().v4(),
        name: name,
        phone: phone,
        relation: _relation.text.trim(),
        isPrimary: _isPrimary,
        sortOrder: widget.existing?.sortOrder ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Padded for the keyboard and scrollable: at 2.0x text scale these four
    // fields are taller than the half-screen a bottom sheet gets.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Add contact' : 'Edit contact',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const AppSpacing.vlg(),
            AppTextField(
              controller: _name,
              label: 'Name',
              hint: 'e.g. Dr. Sharma',
              prefixIcon: Icons.person_outline_rounded,
              errorText: _nameError,
              textCapitalization: TextCapitalization.words,
            ),
            const AppSpacing.vmd(),
            AppTextField(
              controller: _phone,
              label: 'Phone number',
              hint: 'e.g. +91 98765 43210 or 108',
              helperText: 'Spaces and dashes are fine — they are stripped.',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              errorText: _phoneError,
            ),
            const AppSpacing.vmd(),
            AppTextField(
              controller: _relation,
              label: 'Relation (optional)',
              hint: 'e.g. Supervisor, PHC, Son',
              prefixIcon: Icons.people_outline_rounded,
              textCapitalization: TextCapitalization.sentences,
            ),
            const AppSpacing.vsm(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isPrimary,
              onChanged: (v) => setState(() => _isPrimary = v),
              title: Text('Primary contact', style: theme.textTheme.bodyLarge),
              subtitle: Text(
                'Shown first and called first. Everyone still gets the SMS.',
                style: theme.textTheme.bodySmall,
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
                  child: AppButton(label: 'Save', onPressed: _submit),
                ),
              ],
            ),
            const AppSpacing.vmd(),
          ],
        ),
      ),
    );
  }
}
