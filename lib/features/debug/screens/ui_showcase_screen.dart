import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';

class UIShowcaseScreen extends StatefulWidget {
  const UIShowcaseScreen({super.key});

  @override
  State<UIShowcaseScreen> createState() => _UIShowcaseScreenState();
}

class _UIShowcaseScreenState extends State<UIShowcaseScreen> {
  bool _switchValue = true;
  double _sliderValue = 0.5;
  String _dropdownValue = 'Option 1';
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return AppPageScaffold(
      appBar: const AppTopBar(title: 'UI Showcase'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Buttons', [
              _buildButtonShowcase(),
            ]),
            _buildSection('Cards', [
              _buildCardShowcase(),
            ]),
            _buildSection('Badges & Chips', [
              _buildBadgeShowcase(),
            ]),
            _buildSection('Inputs', [
              _buildInputShowcase(),
            ]),
            _buildSection('Progress & Loading', [
              _buildProgressShowcase(),
            ]),
            _buildSection('Risk Badges', [
              _buildRiskBadgeShowcase(),
            ]),
            _buildSection('Theme Colors', [
              _buildColorShowcase(),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))
            .animate().fadeIn().slideX(),
        const AppSpacing.vmd(),
        ...children.map((child) => child.animate().fadeIn(delay: 100.ms).slideY()),
        const AppSpacing.vxl(),
      ],
    );
  }

  Widget _buildButtonShowcase() {
    return Wrap(
      spacing: AppTheme.spacingMd,
      runSpacing: AppTheme.spacingMd,
      children: [
        AppButton(label: 'Primary', icon: const Icon(Icons.arrow_forward_rounded), onPressed: () {}),
        AppButton(label: 'Loading', isLoading: true, onPressed: () {}),
        AppOutlinedButton(label: 'Outlined', icon: const Icon(Icons.format_paint_rounded), onPressed: () {}),
        AppTextButton(label: 'Text Button', onPressed: () {}),
        AppIconButton(icon: const Icon(Icons.favorite_rounded), onPressed: () {}),
      ],
    );
  }

  Widget _buildCardShowcase() {
    return const Column(
      children: [
        AppElevatedCard(
          padding: EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              Icon(Icons.layers_rounded),
              AppSpacing.hmd(),
              Text('Elevated Card'),
            ],
          ),
        ),
        AppSpacing.vmd(),
        AppOutlinedCard(
          padding: EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              Icon(Icons.border_all_rounded),
              AppSpacing.hmd(),
              Text('Outlined Card'),
            ],
          ),
        ),
        AppSpacing.vmd(),
        AppFilledCard(
          padding: EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              Icon(Icons.format_color_fill_rounded),
              AppSpacing.hmd(),
              Text('Filled Card'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeShowcase() {
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: [
        const AppStatusBadge(label: 'Success', type: AppStatusType.success),
        const AppStatusBadge(label: 'Warning', type: AppStatusType.warning),
        const AppStatusBadge(label: 'Error', type: AppStatusType.error),
        const AppStatusBadge(label: 'Info', type: AppStatusType.info),
        const AppStatusBadge(label: 'Neutral', type: AppStatusType.neutral),
        const AppRiskBadge(riskLevel: 'RED', isCompact: true),
        const AppRiskBadge(riskLevel: 'YELLOW', isCompact: true),
        const AppRiskBadge(riskLevel: 'GREEN', isCompact: true),
        AppPillLabel(label: 'Filter 1', color: theme.colorScheme.primary, onClose: () {}),
        AppPillLabel(label: 'Selected', color: theme.colorScheme.primary, isSelected: true, onClose: () {}),
      ],
    );
  }

  Widget _buildInputShowcase() {
    return Column(
      children: [
        AppTextField(
          controller: _textController,
          label: 'Email',
          hint: 'Enter your email',
          prefixIcon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const AppSpacing.vmd(),
        const AppTextField(
          label: 'Password',
          hint: 'Enter password',
          prefixIcon: Icons.lock_rounded,
          obscureText: true,
          suffixIcon: Icon(Icons.visibility_off_rounded),
        ),
        const AppSpacing.vmd(),
        AppSelectField<String>(
          label: 'Select Option',
          value: _dropdownValue,
          items: ['Option 1', 'Option 2', 'Option 3']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _dropdownValue = v!),
          prefixIcon: Icons.arrow_drop_down_rounded,
        ),
        const AppSpacing.vmd(),
        SwitchListTile(
          title: const Text('Enable Feature'),
          subtitle: const Text('Toggle this feature on or off'),
          value: _switchValue,
          onChanged: (v) => setState(() => _switchValue = v),
          secondary: const Icon(Icons.toggle_on_rounded),
        ),
        const AppSpacing.vmd(),
        Slider(
          value: _sliderValue,
          onChanged: (v) => setState(() => _sliderValue = v),
          min: 0,
          max: 1,
          divisions: 10,
          label: '${(_sliderValue * 100).round()}%',
        ),
      ],
    );
  }

  Widget _buildProgressShowcase() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const AppProgressIndicator(value: 0.3, radius: 40),
            AppProgressIndicator(value: 0.65, radius: 40, color: Theme.of(context).colorScheme.tertiary),
            const AppProgressIndicator(radius: 40),
          ],
        ),
        const AppSpacing.vlg(),
        const AppLinearProgress(value: 0.25, showValue: true, valueLabel: '25% Complete'),
        const AppSpacing.vmd(),
        AppLinearProgress(value: 0.75, color: Theme.of(context).colorScheme.tertiary, showValue: true),
        const AppSpacing.vlg(),
        const AppStepProgress(
          currentStep: 2,
          totalSteps: 5,
          stepLabels: ['Patient', 'Device', 'Instructions', 'Screening', 'Results'],
        ),
      ],
    );
  }

  Widget _buildRiskBadgeShowcase() {
    return const Wrap(
      spacing: AppTheme.spacingMd,
      runSpacing: AppTheme.spacingMd,
      children: [
        AppRiskBadge(riskLevel: 'RED', isCompact: false),
        AppRiskBadge(riskLevel: 'YELLOW', isCompact: false),
        AppRiskBadge(riskLevel: 'GREEN', isCompact: false),
        AppRiskBadge(riskLevel: 'URGENT', isCompact: false),
        AppRiskBadge(riskLevel: 'ATTENTION', isCompact: false),
        AppRiskBadge(riskLevel: 'NORMAL', isCompact: false),
      ],
    );
  }

  Widget _buildColorShowcase() {
    final theme = Theme.of(context);

    final colors = [
      ('Primary', theme.colorScheme.primary, theme.colorScheme.onPrimary),
      ('Primary Container', theme.colorScheme.primaryContainer, theme.colorScheme.onPrimaryContainer),
      ('Secondary', theme.colorScheme.secondary, theme.colorScheme.onSecondary),
      ('Secondary Container', theme.colorScheme.secondaryContainer, theme.colorScheme.onSecondaryContainer),
      ('Tertiary', theme.colorScheme.tertiary, theme.colorScheme.onTertiary),
      ('Tertiary Container', theme.colorScheme.tertiaryContainer, theme.colorScheme.onTertiaryContainer),
      ('Error', theme.colorScheme.error, theme.colorScheme.onError),
      ('Error Container', theme.colorScheme.errorContainer, theme.colorScheme.onErrorContainer),
      ('Surface', theme.colorScheme.surface, theme.colorScheme.onSurface),
      ('Surface Variant', theme.colorScheme.surfaceContainerHighest, theme.colorScheme.onSurfaceVariant),
      ('Outline', theme.colorScheme.outline, theme.colorScheme.onSurface),
    ];

    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: colors.map((colorData) {
        return Container(
          width: 140,
          height: 80,
          decoration: BoxDecoration(
            color: colorData.$2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                colorData.$1,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorData.$3,
                ),
              ),
              const Spacer(),
              Text(
                '#${colorData.$2.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: colorData.$3.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}