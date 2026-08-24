import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      context.go('/home');
    }
  }

  void _handleDemoLogin() {
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      appBar: null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSpacing.vxl(),
              Icon(
                Icons.favorite_rounded,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const AppSpacing.vlg(),
              Text(
                'Welcome Back',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const AppSpacing.vsm(),
              Text(
                'Sign in to continue screening',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const AppSpacing.vxl(),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      controller: _emailController,
                      label: 'Email / Worker ID',
                      hint: 'asha.worker@health.gov',
                      prefixIcon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email or worker ID';
                        }
                        return null;
                      },
                    ),
                    const AppSpacing.vmd(),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const AppSpacing.vsm(),
                      AppCard(
                        color: theme.colorScheme.errorContainer,
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        border: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.3), width: 1),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 20),
                            const AppSpacing.hmd(),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const AppSpacing.vlg(),
                    AppButton(
                      label: 'Sign In',
                      icon: const Icon(Icons.login_rounded, size: 24),
                      isLoading: _isLoading,
                      onPressed: _handleLogin,
                      minHeight: 56,
                    ),
                  ],
                ),
              ),
              const AppSpacing.vlg(),
              AppOutlinedButton(
                label: 'Continue as Demo (No Login)',
                icon: const Icon(Icons.science_rounded, size: 24),
                onPressed: _handleDemoLogin,
                borderColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.primary,
                minHeight: 56,
              ),
              const AppSpacing.vmd(),
              Text(
                'Demo mode uses simulated data for testing',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const AppSpacing.vxl(),
              AppCard(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                border: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 1),
                child: Column(
                  children: [
                    Icon(Icons.medical_services_outlined, color: theme.colorScheme.primary, size: 28),
                    const AppSpacing.vsm(),
                    Text(
                      'SwasthyaSetu AI',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      'AI-Powered Smart Health Monitoring\n& Community Early-Warning Platform',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const AppSpacing.vsm(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingXs),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        'Screening Tool Only \u2014 Not a Medical Device',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}