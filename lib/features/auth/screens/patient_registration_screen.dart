import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/auth_repository.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';

/// The patient registration profile: body measurements, history, and the one
/// emergency contact an SOS can reach on day one.
///
/// This is not paperwork. Every field here changes what the app can honestly
/// say later: age and conditions re-threshold the deterministic risk engine
/// for this person, height/weight put a BMI band beside their readings, and
/// the AI explanation layer is handed this profile as context so it speaks
/// about *their* body, not an average adult.
///
/// Opened in two situations: right after a patient account is created (router
/// holds them here until the profile is complete), and from My Health to edit
/// — in which case the linked Patients row is updated, not duplicated.
class PatientRegistrationScreen extends ConsumerStatefulWidget {
  const PatientRegistrationScreen({super.key});

  @override
  ConsumerState<PatientRegistrationScreen> createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState
    extends ConsumerState<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _problems = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();

  String _sex = 'F';
  List<String> _conditions = const [];
  bool _saving = false;
  String? _error;

  bool _didPrefill = false;

  @override
  void initState() {
    super.initState();
    _loadExistingContact();
  }

  /// Fills the emergency contact from whoever SOS currently points at.
  ///
  /// Read here rather than in `build` because assigning to a
  /// [TextEditingController] notifies its field, and doing that mid-build on the
  /// second frame is how "setState during build" happens. The account fields in
  /// [_prefill] get away with it only because they run before the fields exist.
  ///
  /// Without this the editor opened blank every time, so re-saving a profile
  /// looked like it had lost the contact — or wrote a duplicate once the person
  /// typed it again.
  Future<void> _loadExistingContact() async {
    final contact =
        await ref.read(emergencyRepositoryProvider).explicitPrimaryContact();
    if (!mounted || contact == null) return;
    // Never clobber something already typed: the read is async and the person
    // may have reached the field first.
    if (_emergencyName.text.isEmpty) _emergencyName.text = contact.name;
    if (_emergencyPhone.text.isEmpty) _emergencyPhone.text = contact.phone;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _problems.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  void _prefill(UserAccount account) {
    if (_didPrefill) return;
    _didPrefill = true;
    _name.text = account.displayName;
    if (account.age != null) _age.text = '${account.age}';
    if (account.sex.isNotEmpty) _sex = account.sex;
    if (account.heightCm != null) {
      _height.text = account.heightCm!.toStringAsFixed(0);
    }
    if (account.weightKg != null) {
      _weight.text = account.weightKg!.toStringAsFixed(1);
    }
    _conditions = account.conditions;
    if (account.problems != null) _problems.text = account.problems!;
  }

  void _toggleCondition(String condition, bool selected) {
    final next = List<String>.from(_conditions);
    if (selected) {
      // "None of these" is exclusive both ways: picking it clears real
      // conditions, picking a real condition clears it.
      if (condition == 'None of these') {
        next
          ..clear()
          ..add(condition);
      } else {
        next.remove('None of these');
        if (!next.contains(condition)) next.add(condition);
      }
    } else {
      next.remove(condition);
    }
    setState(() => _conditions = next);
  }

  double? get _liveBmi {
    final h = double.tryParse(_height.text);
    final w = double.tryParse(_weight.text);
    if (h == null || w == null || h <= 0) return null;
    final m = h / 100.0;
    return w / (m * m);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(authStateProvider.notifier).completePatientProfile(
            displayName: _name.text,
            age: int.parse(_age.text.trim()),
            sex: _sex,
            heightCm: double.parse(_height.text.trim()),
            weightKg: double.parse(_weight.text.trim()),
            conditions: _conditions,
            problems: _problems.text,
            emergencyName: _emergencyName.text,
            emergencyPhone: _emergencyPhone.text,
          );
      // Router redirect takes us to /my-health: the profile flip changed
      // authStateProvider, and the router is listening.
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _error = e.detail ?? 'Could not save the profile.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not save the profile. Nothing was lost — try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = ref.watch(authStateProvider).account;

    if (account == null) {
      // The redirect normally prevents this; a hot-reload can land here with
      // no session and there is nothing honest to show but the way back.
      return const AppPageScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    _prefill(account);

    final bmi = _liveBmi;
    final editingName = account.profileComplete;

    return AppPageScaffold(
      appBar: AppBar(
        title: Text(editingName ? 'Edit health profile' : 'Your health profile'),
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!editingName) ...[
                    AppCard(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.35),
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.favorite_rounded,
                              color: theme.colorScheme.primary, size: 22),
                          const AppSpacing.hmd(),
                          Expanded(
                            child: Text(
                              'Welcome, ${account.firstName}. A few details '
                              'about your body make the readings yours — the '
                              'app scores them against your age, your history '
                              'and your build, not a stranger\'s.',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const AppSpacing.vlg(),
                  ],
                  AppTextField(
                    controller: _name,
                    label: 'Full name',
                    prefixIcon: Icons.badge_outlined,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter your name'
                        : null,
                  ),
                  const AppSpacing.vmd(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _age,
                          label: 'Age',
                          hint: '32',
                          prefixIcon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final age = int.tryParse(v?.trim() ?? '');
                            if (age == null || age < 1 || age > 120) {
                              return 'Age 1–120';
                            }
                            return null;
                          },
                        ),
                      ),
                      const AppSpacing.hmd(),
                      Expanded(
                        child: AppSelectField<String>(
                          value: _sex,
                          label: 'Sex',
                          prefixIcon: Icons.wc_rounded,
                          items: const [
                            DropdownMenuItem(value: 'F', child: Text('Female')),
                            DropdownMenuItem(value: 'M', child: Text('Male')),
                            DropdownMenuItem(value: 'O', child: Text('Other')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _sex = value;
                              // Pregnancy has no business surviving a sex change.
                              if (value != 'F') {
                                _conditions = _conditions
                                    .where((c) => c != 'Pregnancy')
                                    .toList();
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const AppSpacing.vmd(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _height,
                          label: 'Height (cm)',
                          hint: '165',
                          prefixIcon: Icons.height_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final h = double.tryParse(v?.trim() ?? '');
                            if (h == null || h < 60 || h > 260) {
                              return 'Height 60–260 cm';
                            }
                            return null;
                          },
                        ),
                      ),
                      const AppSpacing.hmd(),
                      Expanded(
                        child: AppTextField(
                          controller: _weight,
                          label: 'Weight (kg)',
                          hint: '58.5',
                          prefixIcon: Icons.monitor_weight_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final w = double.tryParse(v?.trim() ?? '');
                            if (w == null || w < 2 || w > 400) {
                              return 'Weight 2–400 kg';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  if (bmi != null) ...[
                    const AppSpacing.vsm(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppBadge(
                        label:
                            'BMI ${bmi.toStringAsFixed(1)} — ${_bmiBand(bmi)}',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  const AppSpacing.vlg(),
                  AppMultiSelectField<String>(
                    label: 'Do you have any of these? (tap all that apply)',
                    hint: 'Pick "None of these" if healthy',
                    selectedValues: _conditions,
                    availableValues: UserAccount.conditionOptions
                        .where((c) => c != 'Pregnancy' || _sex == 'F')
                        .toList(),
                    getLabel: (c) => c,
                    onChanged: (values) {
                      // Replay through the tap rules so "None of these" stays
                      // exclusive no matter which chip ended the gesture.
                      final added = values
                          .where((v) => !_conditions.contains(v))
                          .toList();
                      final removed = _conditions
                          .where((c) => !values.contains(c))
                          .toList();
                      if (removed.length + added.length == 1 &&
                          added.length == 1) {
                        _toggleCondition(added.single, true);
                      } else if (removed.length + added.length == 1) {
                        _toggleCondition(removed.single, false);
                      } else {
                        setState(() => _conditions = values);
                      }
                    },
                  ),
                  const AppSpacing.vlg(),
                  AppTextField(
                    controller: _problems,
                    label: 'Anything bothering you right now? (optional)',
                    hint: 'e.g. fever since yesterday, chest pain on walking…',
                    prefixIcon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                  const AppSpacing.vlg(),
                  const AppSectionHeader(
                    title: 'Emergency contact',
                    subtitle: 'The SOS button warns this person first. '
                        'Strongly recommended.',
                    padding: EdgeInsets.zero,
                  ),
                  const AppSpacing.vmd(),
                  AppTextField(
                    controller: _emergencyName,
                    label: 'Contact name',
                    hint: 'Family member or friend',
                    prefixIcon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const AppSpacing.vmd(),
                  AppTextField(
                    controller: _emergencyPhone,
                    label: 'Contact phone',
                    hint: '+91 98765 43210',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      final raw = v?.trim() ?? '';
                      if (raw.isEmpty) return null; // optional
                      // Short codes and 10-digit mobiles both valid.
                      final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
                      if (digits.length < 3 || digits.length > 15) {
                        return 'That number cannot be dialled';
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const AppSpacing.vmd(),
                    AppCard(
                      color: theme.colorScheme.errorContainer,
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                  const AppSpacing.vxl(),
                  AppButton(
                    label: editingName
                        ? 'Save changes'
                        : 'Save and start using the app',
                    icon: const Icon(Icons.check_rounded, size: 24),
                    isLoading: _saving,
                    onPressed: _saving ? null : _save,
                    minHeight: 56,
                  ),
                  if (!editingName) ...[
                    const AppSpacing.vmd(),
                    Center(
                      child: AppTextButton(
                        label: 'Not you? Sign out',
                        onPressed: _saving
                            ? null
                            : () => ref
                                .read(authStateProvider.notifier)
                                .signOut(),
                      ),
                    ),
                  ],
                  const AppSpacing.vlg(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _bmiBand(double bmi) {
    if (bmi < 18.5) return 'underweight';
    if (bmi < 25) return 'healthy range';
    if (bmi < 30) return 'overweight';
    return 'obese range';
  }
}
