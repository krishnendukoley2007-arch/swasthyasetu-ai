import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/services/phone_auth_service.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/auth_repository.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';

/// OTP verification screen — shows a 6-box pincode entry and handles:
///   • Countdown timer with "Resend OTP" after 60 s
///   • Auto-fill from SMS (Android)
///   • Error display with retry
class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber; // display format, e.g. +91 98765 43210
  final PhoneOtpSession session;
  final UserRole role;
  final String displayName;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.session,
    required this.role,
    required this.displayName,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  // 6 separate controllers for the pin boxes
  final List<TextEditingController> _ctls = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  String? _error;

  // Resend countdown
  static const _resendSeconds = 60;
  int _secondsLeft = _resendSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctls) {
      c.dispose();
    }
    for (final f in _foci) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _ctls.map((c) => c.text).join();

  bool get _otpComplete => _otp.length == 6;

  void _onDigitEntered(int index, String value) {
    if (value.length == 6) {
      // Auto-fill: paste the whole OTP at once (from SMS suggestion)
      for (var i = 0; i < 6 && i < value.length; i++) {
        _ctls[i].text = value[i];
      }
      _foci.last.requestFocus();
      if (_otpComplete) _verify();
      return;
    }
    if (value.isNotEmpty && index < 5) {
      _foci[index + 1].requestFocus();
    }
    if (_otpComplete) _verify();
    setState(() {});
  }

  void _onBackspace(int index) {
    if (_ctls[index].text.isEmpty && index > 0) {
      _ctls[index - 1].clear();
      _foci[index - 1].requestFocus();
      setState(() {});
    }
  }

  Future<void> _verify() async {
    if (!_otpComplete || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await PhoneAuthService.instance.verifyOtp(
        session: widget.session,
        code: _otp,
      );
      if (!mounted) return;
      await ref
          .read(authStateProvider.notifier)
          .signInWithPhoneOtp(
            result: result,
            displayName: widget.displayName,
            roleForNewAccounts: widget.role,
          );
      // Navigation handled by router watching authStateProvider
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.detail ?? 'OTP verification failed. Please try again.';
          _loading = false;
          // Clear boxes on bad OTP
          for (final c in _ctls) {
            c.clear();
          }
          _foci.first.requestFocus();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unexpected error: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await PhoneAuthService.instance.sendOtp(widget.phoneNumber);
      if (mounted) {
        _startCountdown();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('New OTP sent!')));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not resend OTP. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppPageScaffold(
      appBar: null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = math.min(constraints.maxWidth - 32, 440.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Center(
                child: SizedBox(
                  width: w,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cs.primary, cs.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.35),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.sms_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ).animate().scale(
                        duration: 400.ms,
                        curve: Curves.elasticOut,
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Verify your number',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 8),

                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'We sent a 6-digit code to\n'),
                            TextSpan(
                              text: widget.phoneNumber,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 150.ms),

                      const SizedBox(height: 20),

                      if (widget.session.isMockSession) ...[
                        ActionChip(
                          avatar: const Icon(Icons.touch_app_rounded, size: 16),
                          label: const Text(
                            'Test/Demo Code: 123456 (Tap to fill)',
                          ),
                          backgroundColor: cs.primaryContainer,
                          onPressed: () {
                            const code = '123456';
                            for (int i = 0; i < 6; i++) {
                              _ctls[i].text = code[i];
                            }
                            setState(() {});
                            _verify();
                          },
                        ),
                        const SizedBox(height: 16),
                      ] else
                        const SizedBox(height: 16),

                      // OTP Pin Boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (i) {
                          return _PinBox(
                            controller: _ctls[i],
                            focusNode: _foci[i],
                            onChanged: (v) => _onDigitEntered(i, v),
                            onBackspace: () => _onBackspace(i),
                            hasError: _error != null,
                          );
                        }),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 28),

                      // Verify Button
                      AnimatedSwitcher(
                        duration: 200.ms,
                        child: _loading
                            ? const Center(
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _otpComplete ? _verify : null,
                                child: const Text(
                                  'Verify & Sign In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),

                      const SizedBox(height: 20),

                      // Error Display
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: cs.error,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onErrorContainer,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().shake(hz: 4, duration: 400.ms),

                      const SizedBox(height: 24),

                      // Resend + timer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive the code? ",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          _secondsLeft > 0
                              ? Text(
                                  'Resend in ${_secondsLeft}s',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : TextButton(
                                  onPressed: _loading ? null : _resend,
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: EdgeInsets.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Resend OTP',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Change number
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Change Number'),
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
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

/// Single pin input box.
class _PinBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;
  final bool hasError;

  const _PinBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizedBox(
      width: 44,
      height: 56,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            onBackspace();
          }
        },
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            LengthLimitingTextInputFormatter(6), // allow paste of full OTP
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: hasError
                ? cs.errorContainer.withValues(alpha: 0.4)
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            counterText: '',
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? cs.error : cs.outline.withValues(alpha: 0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? cs.error : cs.primary,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? cs.error.withValues(alpha: 0.5)
                    : cs.outline.withValues(alpha: 0.3),
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
