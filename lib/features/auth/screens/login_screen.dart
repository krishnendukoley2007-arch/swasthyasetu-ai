import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/constants/app_constants.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/auth_repository.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';

/// The two-mode front door.
///
/// The screen is a short state machine, not two routes:
///   1. pick a role (big cards — the whole app bends around this choice), then
///   2. prove identity for that role (email, or Google where configured).
///
/// Successful sign-in never navigates from here. It changes
/// [authStateProvider], and the router's redirect moves the phone to the
/// right home — one place owns "who goes where".
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Null while the two role cards are up; set once one is tapped.
  UserRole? _role;

  bool _registerMode = false;
  bool _isLoading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  bool get _busy => _isLoading || _googleLoading;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _runAuth(Future<void> Function() action,
      {bool google = false}) async {
    setState(() {
      _errorMessage = null;
      if (google) {
        _googleLoading = true;
      } else {
        _isLoading = true;
      }
    });
    try {
      await action();
      // No navigation: the router has been watching authStateProvider the
      // whole time and is already moving the app to the right home.
    } on AuthException catch (e) {
      if (!mounted) return;
      // A cancelled Google sheet is not an error the user needs explained —
      // they know they closed it.
      if (e.failure != AuthFailure.googleCancelled) {
        setState(() => _errorMessage = _messageFor(e));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage =
            'Sign-in failed on this phone. Email sign-in is fully offline — '
            'it keeps working with no network at all.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _googleLoading = false;
        });
      }
    }
  }

  String _messageFor(AuthException e) => switch (e.failure) {
        AuthFailure.emailInUse =>
          'An account for this email already exists — switch to "Sign in" '
              'and use its password.',
        AuthFailure.wrongCredentials => 'Email or password is incorrect.',
        AuthFailure.weakPassword =>
          'Password needs at least 6 characters.',
        AuthFailure.invalidEmail =>
          'That does not look like an email address.',
        AuthFailure.googleUnavailable => e.detail ?? 'Google sign-in is not '
            'available on this build. Email sign-in works offline instead.',
        AuthFailure.googleCancelled => '',
      };

  Future<void> _submit() {
    if (!_formKey.currentState!.validate()) {
      return Future.value();
    }
    final auth = ref.read(authStateProvider.notifier);
    final role = _role!;
    if (_registerMode) {
      return _runAuth(() => auth.registerWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
            displayName: _nameController.text,
            role: role,
          ));
    }
    return _runAuth(() => auth.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        ));
  }

  Future<void> _google() => _runAuth(
        () => ref
            .read(authStateProvider.notifier)
            .signInWithGoogle(roleForNewAccounts: _role!),
        google: true,
      );

  void _demo() => ref.read(authStateProvider.notifier).continueAsDemo();

  @override
  Widget build(BuildContext context) {
    // Constrained + centred: this screen is the first thing shown on tablets
    // at clinics, and a full-width login form looks broken at 900 dp.
    return AppPageScaffold(
      appBar: null,
      body: SafeArea(
        child: AppCenteredScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _role == null ? _buildRolePicker() : _buildAuthForm(),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────── Role picker ─────────────────────────────

  Widget _buildRolePicker() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.favorite_rounded,
            size: 64, color: theme.colorScheme.primary),
        const AppSpacing.vlg(),
        Text(
          AppConstants.appName,
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const AppSpacing.vxs(),
        Text(
          'One platform, two ways in. This choice decides what the app shows '
          'you and how the AI speaks to you.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const AppSpacing.vxl(),
        _RoleCard(
          icon: Icons.face_rounded,
          color: theme.colorScheme.primary,
          title: 'I am a Patient',
          subtitle: 'Check my own health with the ESP32 device. '
              'Plain-language results, and safe home care when it is not '
              'serious.',
          onTap: _busy
              ? null
              : () => setState(() {
                    _role = UserRole.patient;
                    _errorMessage = null;
                  }),
        ),
        const AppSpacing.vmd(),
        _RoleCard(
          icon: Icons.medical_services_outlined,
          color: theme.colorScheme.secondary,
          title: 'Nurse / Doctor / Health Worker',
          subtitle: 'Screen patients with the device, manage cases, and get '
              'clinical referral guidance.',
          onTap: _busy
              ? null
              : () => setState(() {
                    _role = UserRole.clinician;
                    _errorMessage = null;
                  }),
        ),
        const AppSpacing.vxl(),
        AppOutlinedButton(
          label: 'Continue as Demo (no account)',
          icon: const Icon(Icons.science_rounded, size: 24),
          onPressed: _busy ? null : _demo,
          borderColor: theme.colorScheme.outline,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          minHeight: 52,
        ),
        const AppSpacing.vsm(),
        Text(
          'Demo mode uses simulated data — nothing is tied to an account.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const AppSpacing.vlg(),
        _buildFootnote(theme),
      ],
    );
  }

  // ───────────────────────────── Auth form ─────────────────────────────

  Widget _buildAuthForm() {
    final theme = Theme.of(context);
    final isPatient = _role == UserRole.patient;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back to role choice',
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _role = null;
                        _errorMessage = null;
                      }),
            ),
            const AppSpacing.hsm(),
            Expanded(
              child: Text(
                isPatient
                    ? 'Patient sign-in'
                    : 'Nurse / Doctor sign-in',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const AppSpacing.vsm(),
        Text(
          isPatient
              ? 'Your results stay on this phone, explained in plain words.'
              : 'Screen camps, patients and referral guidance stay on this '
                  'phone — even with no network.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const AppSpacing.vlg(),
        AppSegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Sign in')),
            ButtonSegment(value: true, label: Text('Create account')),
          ],
          selected: {_registerMode},
          onSelectionChanged: _busy
              ? (_) {}
              : (selection) => setState(() {
                    _registerMode = selection.first;
                    _errorMessage = null;
                  }),
        ),
        const AppSpacing.vlg(),
        Form(
          key: _formKey,
          child: Column(
            children: [
              if (_registerMode) ...[
                AppTextField(
                  controller: _nameController,
                  label: 'Full name',
                  hint: isPatient ? 'Your name' : 'Worker name',
                  prefixIcon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Please enter the name'
                          : null,
                ),
                const AppSpacing.vmd(),
              ],
              AppTextField(
                controller: _emailController,
                label: 'Email',
                hint: isPatient ? 'you@example.com' : 'asha.worker@health.gov',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              const AppSpacing.vmd(),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hint: _registerMode ? 'At least 6 characters' : 'Your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                suffixIcon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onSuffixTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (_registerMode && value.length < 6) {
                    return 'At least 6 characters';
                  }
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const AppSpacing.vmd(),
                AppCard(
                  color: theme.colorScheme.errorContainer,
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: theme.colorScheme.error, size: 20),
                      const AppSpacing.hmd(),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const AppSpacing.vlg(),
              AppButton(
                label: _registerMode ? 'Create account' : 'Sign in',
                icon: const Icon(Icons.login_rounded, size: 24),
                isLoading: _isLoading,
                onPressed: _busy ? null : _submit,
                minHeight: 56,
              ),
            ],
          ),
        ),
        const AppSpacing.vlg(),
        Row(children: [
          const Expanded(child: AppDivider()),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd),
            child: Text('or',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          const Expanded(child: AppDivider()),
        ]),
        const AppSpacing.vlg(),
        AppOutlinedButton(
          label: 'Continue with Google',
          icon: Icon(Icons.g_mobiledata_rounded,
              size: 28, color: theme.colorScheme.primary),
          isLoading: _googleLoading,
          onPressed: _busy ? null : _google,
          borderColor: theme.colorScheme.outline,
          foregroundColor: theme.colorScheme.onSurface,
          minHeight: 56,
        ),
        const AppSpacing.vsm(),
        Text(
          'Google needs an internet connection the first time. Email works '
          'with no network at all.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const AppSpacing.vlg(),
        _buildFootnote(theme),
      ],
    );
  }

  Widget _buildFootnote(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded,
            size: 14, color: theme.colorScheme.onSurfaceVariant),
        const AppSpacing.hxs(),
        Flexible(
          child: Text(
            'Passwords are never stored — only a salted hash on this device.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// One role card. Full-width even when a second one sits below it — a 360 dp
/// field phone has no business splitting this into columns.
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const AppSpacing.hlg(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const AppSpacing.hsm(),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
