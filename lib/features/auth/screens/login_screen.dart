import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/constants/app_constants.dart';
import 'package:swasthyasetu_ai/core/services/phone_auth_service.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/data/repositories/auth_repository.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:swasthyasetu_ai/features/auth/screens/otp_verification_screen.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';

/// The front door of SwasthyaSetu AI.
///
/// Visual language follows the clinical design system: one accent (teal),
/// hairline borders instead of shadows/gradients, no marketing copy, and the
/// only motion is the 350 ms panel swap. Every path funnels the same
/// way: role → method → on with the work.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  UserRole? _role;
  _AuthMode _mode = _AuthMode.phone;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _pickRole(UserRole role) {
    HapticFeedback.selectionClick();
    setState(() {
      _role = role;
      _error = null;
      _mode = role == UserRole.clinician ? _AuthMode.asha : _AuthMode.phone;
    });
  }

  void _back() {
    setState(() {
      _role = null;
      _error = null;
    });
  }

  Future<void> _sendOtp() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name first.');
      return;
    }
    final phone = '+91${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}';
    if (_phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length != 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await PhoneAuthService.instance.sendOtp(phone);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phoneNumber: phone,
            session: session,
            role: _role!,
            displayName: _nameCtrl.text.trim(),
          ),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.detail ?? 'Failed to send OTP.');
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitEmail({required bool register}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authStateProvider.notifier);
      if (register) {
        await auth.registerWithEmail(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          displayName: _nameCtrl.text,
          role: _role!,
        );
      } else {
        await auth.signInWithEmail(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    } catch (e) {
      if (mounted) setState(() => _error = 'Sign-in error. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _quickSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authStateProvider.notifier)
          .quickSignIn(role: UserRole.clinician);
    } catch (e) {
      if (mounted) setState(() => _error = 'Quick sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _demo() => ref.read(authStateProvider.notifier).continueAsDemo();

  Future<void> _signInWithGoogle([UserRole? explicitRole]) async {
    final targetRole = explicitRole ?? _role ?? UserRole.patient;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authStateProvider.notifier)
          .signInWithGoogle(roleForNewAccounts: targetRole);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    } catch (e) {
      if (mounted) setState(() => _error = 'Google Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(AuthException e) => switch (e.failure) {
    AuthFailure.emailInUse =>
      'An account with this email exists. Switch to "Sign in".',
    AuthFailure.wrongCredentials => 'Email or password not recognized.',
    AuthFailure.weakPassword => 'Password must be at least 6 characters.',
    AuthFailure.invalidEmail => 'Enter a valid email address.',
    AuthFailure.googleUnavailable =>
      e.detail ?? 'Google Sign-In is unavailable on this device.',
    AuthFailure.googleCancelled =>
      e.detail ?? 'Google Sign-In was cancelled or dismissed.',
    AuthFailure.phoneOtpFailed =>
      e.detail ?? 'OTP verification failed. Try again.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _loading;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = math.min(constraints.maxWidth - 48, 420.0);
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: SizedBox(
                  width: w,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 0.04),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    ),
                    child: _role == null
                        ? _RolePicker(
                            key: const ValueKey('picker'),
                            onPick: _pickRole,
                            onGoogle: (role) => _signInWithGoogle(role),
                            onDemo: _demo,
                            busy: busy,
                          )
                        : _AuthPanel(
                            key: ValueKey('auth-${_role!.name}'),
                            role: _role!,
                            mode: _mode,
                            nameCtrl: _nameCtrl,
                            phoneCtrl: _phoneCtrl,
                            emailCtrl: _emailCtrl,
                            passwordCtrl: _passwordCtrl,
                            formKey: _formKey,
                            obscure: _obscure,
                            loading: _loading,
                            error: _error,
                            onModeChange: (m) => setState(() {
                              _mode = m;
                              _error = null;
                            }),
                            onToggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                            onBack: _back,
                            onSendOtp: _sendOtp,
                            onEmailSignIn: () => _submitEmail(register: false),
                            onEmailRegister: () => _submitEmail(register: true),
                            onAshaQuick: _quickSignIn,
                            onGoogle: () => _signInWithGoogle(_role),
                            onDemo: _demo,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _AuthMode { phone, email, asha }

// ───────────────────────── Role picker ─────────────────────────

class _RolePicker extends StatelessWidget {
  final ValueChanged<UserRole> onPick;
  final ValueChanged<UserRole> onGoogle;
  final VoidCallback onDemo;
  final bool busy;

  const _RolePicker({
    super.key,
    required this.onPick,
    required this.onGoogle,
    required this.onDemo,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),

        // Brand mark: one accent, no glow.
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ClinicalPalette.tealBright, ClinicalPalette.teal],
              ),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          AppConstants.appName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 4),

        Text(
          'Screening · triage · follow-up',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: ClinicalPalette.muted(context),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 28),

        _RoleTile(
          icon: Icons.person_rounded,
          title: 'Patient',
          subtitle: 'Check vitals and follow your trends',
          onTap: busy ? null : () => onPick(UserRole.patient),
        ),
        const SizedBox(height: 12),
        _RoleTile(
          icon: Icons.local_hospital_rounded,
          title: 'Doctor / Nurse',
          subtitle: 'Screen patients and issue referral slips',
          onTap: busy ? null : () => onPick(UserRole.clinician),
        ),
        const SizedBox(height: 12),
        _RoleTile(
          icon: Icons.medical_services_rounded,
          title: 'ASHA / Health worker',
          subtitle: 'Field access with one-tap sign-in',
          onTap: busy ? null : () => onPick(UserRole.clinician),
        ),

        const SizedBox(height: 20),

        const _OrDivider(text: 'or'),
        const SizedBox(height: 16),

        _GoogleSignInButton(
          onTap: busy ? null : () => onGoogle(UserRole.patient),
          loading: busy,
        ),

        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: busy ? null : onDemo,
            child: const Text('Explore demo mode'),
          ),
        ),

        const SizedBox(height: 8),
        const _FooterNote(),
      ],
    );
  }
}

/// One role option. Flat, hairline border, single accent chip — the tap state
/// is the ripple, nothing else.
class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClinicalPalette.hairline(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ClinicalPalette.teal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: ClinicalPalette.teal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ClinicalPalette.muted(context),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: ClinicalPalette.faint(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Auth panel ─────────────────────────

class _AuthPanel extends StatefulWidget {
  final UserRole role;
  final _AuthMode mode;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final GlobalKey<FormState> formKey;
  final bool obscure;
  final bool loading;
  final String? error;
  final ValueChanged<_AuthMode> onModeChange;
  final VoidCallback onToggleObscure;
  final VoidCallback onBack;
  final VoidCallback onSendOtp;
  final VoidCallback onEmailSignIn;
  final VoidCallback onEmailRegister;
  final VoidCallback onAshaQuick;
  final VoidCallback onGoogle;
  final VoidCallback onDemo;

  const _AuthPanel({
    super.key,
    required this.role,
    required this.mode,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.formKey,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onModeChange,
    required this.onToggleObscure,
    required this.onBack,
    required this.onSendOtp,
    required this.onEmailSignIn,
    required this.onEmailRegister,
    required this.onAshaQuick,
    required this.onGoogle,
    required this.onDemo,
  });

  @override
  State<_AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends State<_AuthPanel> {
  bool _registerMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: widget.loading ? null : widget.onBack,
              tooltip: 'Change role',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _roleTitle(widget.role),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _roleSubtitle(widget.role),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ClinicalPalette.muted(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        if (widget.role == UserRole.clinician) ...[
          _QuickLoginTile(
            onTap: widget.loading ? null : widget.onAshaQuick,
            loading: widget.loading && widget.mode == _AuthMode.asha,
          ),
          const SizedBox(height: 16),
          const _OrDivider(text: 'or sign in with phone'),
          const SizedBox(height: 16),
        ],

        if (widget.mode == _AuthMode.phone || widget.mode == _AuthMode.asha)
          _buildPhoneForm(theme, cs),

        if (widget.mode == _AuthMode.email) _buildEmailForm(theme, cs),

        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: widget.loading
                ? null
                : () => widget.onModeChange(
                    widget.mode == _AuthMode.email
                        ? _AuthMode.phone
                        : _AuthMode.email,
                  ),
            child: Text(
              widget.mode == _AuthMode.email
                  ? 'Sign in with phone OTP instead'
                  : 'Sign in with email and password instead',
              style: theme.textTheme.bodySmall?.copyWith(
                color: ClinicalPalette.teal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        if (widget.error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ClinicalPalette.coral.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ClinicalPalette.coral.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: ClinicalPalette.coral,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.error!,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        const _FooterNote(),
      ],
    );
  }

  Widget _buildPhoneForm(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Your name',
            hintText: _roleNameHint(widget.role),
            prefixIcon: const Icon(Icons.badge_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: widget.phoneCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Mobile number',
            hintText: '98765 43210',
            prefixIcon: const Icon(Icons.phone_android_rounded),
            prefixText: '+91  ',
            prefixStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: widget.loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sms_rounded),
          label: Text(widget.loading ? 'Sending OTP…' : 'Send OTP'),
          onPressed: widget.loading ? null : widget.onSendOtp,
        ),
        const SizedBox(height: 16),
        const _OrDivider(text: 'or'),
        const SizedBox(height: 12),
        _GoogleSignInButton(
          onTap: widget.loading ? null : widget.onGoogle,
          loading: widget.loading,
        ),
      ],
    );
  }

  Widget _buildEmailForm(ThemeData theme, ColorScheme cs) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Sign in')),
              ButtonSegment(value: true, label: Text('Create account')),
            ],
            selected: {_registerMode},
            onSelectionChanged: widget.loading
                ? (_) {}
                : (s) => setState(() => _registerMode = s.first),
          ),
          const SizedBox(height: 16),
          if (_registerMode) ...[
            TextFormField(
              controller: widget.nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.badge_rounded),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name required' : null,
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: widget.emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email address',
              hintText: _roleEmailHint(widget.role),
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.passwordCtrl,
            obscureText: widget.obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: _registerMode ? 'At least 6 characters' : '',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  widget.obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: widget.onToggleObscure,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password required';
              if (_registerMode && v.length < 6) {
                return 'At least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: widget.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.login_rounded),
            label: Text(_registerMode ? 'Create account' : 'Sign in'),
            onPressed: widget.loading
                ? null
                : (_registerMode
                      ? widget.onEmailRegister
                      : widget.onEmailSignIn),
          ),
          const SizedBox(height: 16),
          const _OrDivider(text: 'or'),
          const SizedBox(height: 12),
          _GoogleSignInButton(
            onTap: widget.loading ? null : widget.onGoogle,
            loading: widget.loading,
          ),
        ],
      ),
    );
  }

  String _roleTitle(UserRole role) => switch (role) {
    UserRole.patient => 'Patient sign-in',
    UserRole.clinician => 'Clinician sign-in',
  };

  String _roleSubtitle(UserRole role) => switch (role) {
    UserRole.patient => 'Your records stay on this device.',
    UserRole.clinician => 'Screen, triage, and refer patients.',
  };

  String _roleNameHint(UserRole role) => switch (role) {
    UserRole.patient => 'Your full name',
    UserRole.clinician => 'Dr. / nurse name',
  };

  String _roleEmailHint(UserRole role) => switch (role) {
    UserRole.patient => 'you@example.com',
    UserRole.clinician => 'doctor@hospital.in',
  };
}

// ───────────────────────── ASHA quick login ─────────────────────────

class _QuickLoginTile extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;

  const _QuickLoginTile({required this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: ClinicalPalette.teal.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ClinicalPalette.teal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: loading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ClinicalPalette.teal,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.bolt_rounded,
                        color: ClinicalPalette.teal,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'One-tap field login',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Works fully offline · no OTP needed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ClinicalPalette.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: ClinicalPalette.faint(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Shared bits ─────────────────────────

class _OrDivider extends StatelessWidget {
  final String text;
  const _OrDivider({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: ClinicalPalette.hairline(context))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ClinicalPalette.muted(context),
            ),
          ),
        ),
        Expanded(child: Divider(color: ClinicalPalette.hairline(context))),
      ],
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 13,
          color: ClinicalPalette.faint(context),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            'Records stored on this device · screening only, not a diagnosis',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ClinicalPalette.muted(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;

  const _GoogleSignInButton({required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF1E1F20) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF444746) : const Color(0xFFDADCE0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                const _GoogleGIcon(),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  'Continue with Google',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F1F1F),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleGIcon extends StatelessWidget {
  const _GoogleGIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.6, 1.4, false, paint);
    canvas.drawLine(
      Offset(size.width / 2, size.height / 2),
      Offset(size.width - 1, size.height / 2),
      paint..strokeCap = StrokeCap.butt,
    );

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.8, 1.2, false, paint..strokeCap = StrokeCap.round);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.0, 1.1, false, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.1, 1.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
