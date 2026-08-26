import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:uuid/uuid.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isDemo = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _ageController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    const uuid = Uuid();
    final patientId = 'PAT-${uuid.v4().substring(0, 7).toUpperCase()}';

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      context.go('/patients/$patientId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Add Patient'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/patients'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepHeader(
                'Patient Information',
                'Enter the patient details',
                Icons.person_outline_rounded,
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
              const AppSpacing.vlg(),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _ageController,
                      label: 'Age',
                      hint: '42',
                      prefixIcon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final age = int.tryParse(value);
                        if (age == null || age < 0 || age > 120) {
                          return 'Invalid age';
                        }
                        return null;
                      },
                    ),
                  ),
                  const AppSpacing.hmd(),
                  Expanded(
                    child: AppTextField(
                      controller: _locationController,
                      label: 'Location (Optional)',
                      hint: 'District, Sub-center',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.1),
              const AppSpacing.vmd(),
              AppTextField(
                controller: _phoneController,
                label: 'Phone (Optional)',
                hint: '+91 98765 43210',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideY(begin: 0.1),
              const AppSpacing.vmd(),
              AppTextField(
                controller: _notesController,
                label: 'Notes (Optional)',
                hint: 'Medical history, conditions...',
                prefixIcon: Icons.note_outlined,
                maxLines: 3,
              ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideY(begin: 0.1),
              const AppSpacing.vxl(),
              _buildStepHeader(
                'Options',
                'Configure patient settings',
                Icons.settings_outlined,
              ).animate().fadeIn(duration: 300.ms, delay: 400.ms).slideY(begin: 0.1),
              const AppSpacing.vmd(),
              AppCard(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: SwitchListTile(
                  title: const Text('Demo Mode'),
                  subtitle: const Text('Use simulated data for testing'),
                  value: _isDemo,
                  onChanged: (value) => setState(() => _isDemo = value),
                  activeThumbColor: theme.colorScheme.primary,
                  secondary: Icon(
                    _isDemo ? Icons.science_outlined : Icons.person_outline,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 500.ms).slideY(begin: 0.1),
              const AppSpacing.vxl(),
              AppButton(
                label: 'Register Patient',
                isLoading: _isLoading,
                onPressed: _savePatient,
              ).animate().fadeIn(duration: 300.ms, delay: 600.ms).slideY(begin: 0.1),
              const AppSpacing.vmd(),
              AppCard(
                color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.2),
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                border: BorderSide(color: theme.colorScheme.tertiary.withValues(alpha: 0.3), width: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: theme.colorScheme.tertiary, size: 20),
                    const AppSpacing.hmd(),
                    Expanded(
                      child: Text(
                        'Patient IDs are generated automatically (e.g., PAT-93F8A21). Avoid collecting unnecessary personal information. Use internal UUIDs for privacy.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 700.ms).slideY(begin: 0.1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader(String title, String subtitle, IconData icon) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer, size: 28),
        ),
        const AppSpacing.hmd(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const AppSpacing.vxs(),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}