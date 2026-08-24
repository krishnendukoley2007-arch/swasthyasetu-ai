import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/device.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/features/screening/state/screening_draft.dart';

class NewScreeningScreen extends ConsumerStatefulWidget {
  const NewScreeningScreen({super.key});

  @override
  ConsumerState<NewScreeningScreen> createState() => _NewScreeningScreenState();
}

class _NewScreeningScreenState extends ConsumerState<NewScreeningScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _stepController;
  late AnimationController _headerController;
  late AnimationController _contentController;

  int _currentStep = 0;
  Patient? _selectedPatient;
  Device? _selectedDevice;

  final Device _demoDevice = Device.demo();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _stepController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Driven here, once, before any child is listening. The animated header
    // used to call `forward(from: 0)` from its own initState, so the second
    // header to mount notified a controller that an already-listening
    // AnimatedBuilder was in the middle of building against.
    _stepController.forward();
    _headerController.forward();
    _contentController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stepController.dispose();
    _headerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0 && _selectedPatient == null) {
      _showSnackBar('Please select a patient');
      return;
    }
    if (_currentStep == 1 && _selectedDevice == null) {
      _showSnackBar('Please connect a device');
      return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: AppTheme.curveStandard,
      );
      _stepController.forward(from: 0);
      _headerController.forward(from: 0);
      _contentController.forward(from: 0);
    } else {
      // The draft is what carries the patient into the next three screens.
      // Before this existed, `go('/screening/live')` dropped the selection and
      // the reading was scored against adult defaults and never saved.
      ref.read(screeningDraftProvider.notifier).begin(
            patient: _selectedPatient!,
            device: _selectedDevice,
          );
      context.go('/screening/live');
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: AppTheme.curveStandard,
      );
      _stepController.forward(from: 0);
      _headerController.forward(from: 0);
      _contentController.forward(from: 0);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      ),
    );
  }

  void _scanForDevices() => context.push('/devices/scan');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('New Screening'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppTheme.spacingMd),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingXs),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              'DEMO',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
        elevation: 0,
        scrolledUnderElevation: AppTheme.elevationLevel1,
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentStep = index),
              children: [
                _AnimatedPageContent(
                  animationController: _contentController,
                  pageIndex: 0,
                  currentStep: _currentStep,
                  child: _buildPatientSelectionStep(),
                ),
                _AnimatedPageContent(
                  animationController: _contentController,
                  pageIndex: 1,
                  currentStep: _currentStep,
                  child: _buildDeviceConnectionStep(),
                ),
                _AnimatedPageContent(
                  animationController: _contentController,
                  pageIndex: 2,
                  currentStep: _currentStep,
                  child: _buildInstructionsStep(),
                ),
              ],
            ),
          ),
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _stepController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingLg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
            ),
          ),
          child: Row(
            children: [
              _buildStepItem(0, 'Patient', Icons.person_rounded),
              _buildStepConnector(0),
              _buildStepItem(1, 'Device', Icons.bluetooth_rounded),
              _buildStepConnector(1),
              _buildStepItem(2, 'Ready', Icons.check_circle_outline_rounded),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepItem(int step, String label, IconData icon) {
    final theme = Theme.of(context);
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;

    return Expanded(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: AppTheme.curveSpring,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isCompleted || isActive
                      ? LinearGradient(
                          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isCompleted || isActive ? null : theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: (!isCompleted && !isActive)
                      ? Border.all(color: theme.colorScheme.outlineVariant, width: 2)
                      : null,
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ] : null,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check_rounded, color: theme.colorScheme.onPrimary, size: 24)
                      : Icon(icon, color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant, size: 24),
                ),
              ),
              if (isActive)
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeInOut,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const AppSpacing.vxs(),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: theme.textTheme.labelSmall!.copyWith(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final theme = Theme.of(context);
    final isCompleted = step < _currentStep;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: AppTheme.curveStandard,
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
        decoration: BoxDecoration(
          color: isCompleted ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
      ),
    );
  }

  Widget _buildPatientSelectionStep() {

    return _AnimatedPageContent(
      animationController: _contentController,
      pageIndex: 0,
      currentStep: _currentStep,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AnimatedHeader(
              animationController: _headerController,
              child: _buildStepHeader(
                'Select Patient',
                'Choose an existing patient or create a new one',
                Icons.person_search_rounded,
              ),
            ),
            const AppSpacing.vxl(),
            _buildPatientList(),
            const AppSpacing.vlg(),
            _buildAddPatientButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientList() {
    // The roster comes from the local database, so a patient added moments ago
    // in another screen is selectable here without a restart.
    final patientsAsync = ref.watch(patientsProvider);

    return patientsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppTheme.spacingXl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load patients',
        subtitle: 'The local database did not respond.',
        action: AppOutlinedButton(
          label: 'Try again',
          isExpanded: false,
          onPressed: () => ref.invalidate(patientSummariesProvider),
        ),
      ),
      data: (patients) {
        if (patients.isEmpty) {
          return const AppEmptyState(
            icon: Icons.person_off_outlined,
            title: 'No patients yet',
            subtitle: 'Add a patient below to begin the first screening.',
          );
        }
        return AppStaggeredList(
          duration: AppTheme.durationMd,
          delay: const Duration(milliseconds: 100),
          children: patients
              .asMap()
              .entries
              .map((entry) => _buildPatientCard(entry.value, entry.key))
              .toList(),
        );
      },
    );
  }

  Widget _buildStepHeader(String title, String subtitle, IconData icon) {
    final theme = Theme.of(context);

    return _AnimatedHeader(
      animationController: _headerController,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primaryContainer, theme.colorScheme.primaryContainer.withValues(alpha: 0.7)],
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
      ),
    );
  }

  Widget _buildPatientCard(Patient patient, int index) {
    final theme = Theme.of(context);
    final isSelected = _selectedPatient?.id == patient.id;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      onTap: () => setState(() => _selectedPatient = patient),
      isSelected: isSelected,
      border: BorderSide(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
        width: isSelected ? 2 : 1,
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: AppTheme.curveStandard,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected
                    ? [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)]
                    : [theme.colorScheme.primaryContainer, theme.colorScheme.primaryContainer.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Center(
              child: Text(
                // `id.substring(4, 6)` used to be shown here, which threw a
                // RangeError on any id shorter than six characters.
                initialsFor(patient.name),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const AppSpacing.hmd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        patient.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (patient.isDemo)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Text(
                          'DEMO',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
                const AppSpacing.vxs(),
                Text(
                  '${patient.age} years • ${patient.sex}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (patient.location != null) ...[
                  const AppSpacing.vxs(),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      const AppSpacing.hxs(),
                      Expanded(
                        child: Text(
                          patient.location!,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (patient.notes != null) ...[
                  const AppSpacing.vxs(),
                  Row(
                    children: [
                      Icon(Icons.note_alt_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      const AppSpacing.hxs(),
                      Expanded(
                        child: Text(
                          patient.notes!,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: isSelected
                ? Icon(Icons.check_circle_rounded, key: const ValueKey('selected'), color: theme.colorScheme.primary, size: 28)
                : Icon(Icons.radio_button_unchecked_rounded, key: const ValueKey('unselected'), color: theme.colorScheme.outlineVariant, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPatientButton() {

    return AppOutlinedButton(
      label: 'Add New Patient',
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 24),
      onPressed: () => context.go('/patients/add'),
      minHeight: 56,
    );
  }

  Widget _buildDeviceConnectionStep() {
    final isConnected = _selectedDevice?.isConnected == true;

    return _AnimatedPageContent(
      animationController: _contentController,
      pageIndex: 1,
      currentStep: _currentStep,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AnimatedHeader(
              animationController: _headerController,
              child: _buildStepHeader(
                'Connect Device',
                'Ensure your SwasthyaSetu device is powered on and nearby',
                Icons.bluetooth_searching_rounded,
              ),
            ),
            const AppSpacing.vxl(),
            _buildDeviceCard(isConnected),
            const AppSpacing.vlg(),
            if (!isConnected) _buildScanButton() else _buildConnectedActions(),
            const AppSpacing.vxl(),
            _buildDeviceInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(bool isConnected) {
    final theme = Theme.of(context);

    return AppElevatedCard(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: AppTheme.curveSpring,
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isConnected
                    ? [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)]
                    : [theme.colorScheme.surfaceContainerHighest, theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
              boxShadow: isConnected ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 32,
                  spreadRadius: 5,
                  offset: const Offset(0, 12),
                ),
              ] : null,
            ),
            child: Icon(
              isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_searching_rounded,
              size: 56,
              color: isConnected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const AppSpacing.vlg(),
          Text(
            _selectedDevice?.name ?? 'SwasthyaSetu Demo Device',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vsm(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: AppTheme.curveStandard,
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isConnected ? theme.colorScheme.primary : theme.colorScheme.tertiary,
                  shape: BoxShape.circle,
                  boxShadow: isConnected ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ] : null,
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                    isConnected ? 'Connected' : 'Demo Mode - Simulated',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isConnected ? theme.colorScheme.primary : theme.colorScheme.tertiary,
                    ),
                  ),
              ),
            ],
          ),
          const AppSpacing.vxs(),
          // Only the selected device's own battery, and only when it is a
          // real one: this line used to read the demo device's field whatever
          // was connected, so a live board always reported the demo's charge.
          if (_selectedDevice != null && !_selectedDevice!.isDemo)
            Text(
              'Battery: ${_selectedDevice!.batteryPercent}%',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _buildScanButton() {

    return Column(
      children: [
        AppButton(
          label: 'Use Demo Device',
          icon: const Icon(Icons.bluetooth_connected_rounded, size: 24),
          onPressed: () => setState(() => _selectedDevice = _demoDevice),
          minWidth: double.infinity,
          minHeight: 56,
        ),
        const AppSpacing.vmd(),
        AppOutlinedButton(
          label: 'Scan for Devices',
          icon: const Icon(Icons.bluetooth_searching_rounded, size: 24),
          onPressed: () => _scanForDevices(),
          minHeight: 56,
        ),
      ],
    );
  }

  Widget _buildConnectedActions() {
    return Row(
      children: [
        Expanded(
          child: AppOutlinedButton(
            label: 'Change Device',
            icon: const Icon(Icons.bluetooth_searching_rounded, size: 24),
            onPressed: () => context.go('/devices/scan'),
            minHeight: 56,
          ),
        ),
        const AppSpacing.hmd(),
        Expanded(
          child: AppButton(
            label: 'Disconnect',
            icon: const Icon(Icons.bluetooth_disabled_rounded, size: 24),
            onPressed: () => setState(() => _selectedDevice = null),
            minHeight: 56,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceInfoCard() {
    final theme = Theme.of(context);

    return AppFilledCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requirements',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const AppSpacing.vsm(),
          _buildRequirementItem('Bluetooth enabled on phone'),
          _buildRequirementItem('Device powered on (LED blinking)'),
          _buildRequirementItem('Within 10 meters range'),
          _buildRequirementItem('Battery above 20%'),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingXs),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 16, color: theme.colorScheme.primary),
          const AppSpacing.hsm(),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsStep() {
    final theme = Theme.of(context);

    final instructions = [
      _Instruction(
        number: '1',
        title: 'Place Finger on Sensor',
        description: 'Place your index finger gently on the MAX30102 sensor. Keep still and avoid excessive pressure.',
        icon: Icons.favorite_rounded,
        color: theme.colorScheme.primary,
      ),
      _Instruction(
        number: '2',
        title: 'Attach ECG Electrodes',
        description: 'Connect the 3 ECG electrodes: RA (right arm), LA (left arm), RL (right leg, reference/ground). Ensure good skin contact.',
        icon: Icons.monitor_heart_rounded,
        color: theme.colorScheme.secondary,
      ),
      _Instruction(
        number: '3',
        title: 'Measure Temperature',
        description: 'Point the MLX90614 sensor at the forehead or temporal artery from 2-5cm distance.',
        icon: Icons.thermostat_rounded,
        color: theme.colorScheme.tertiary,
      ),
      _Instruction(
        number: '4',
        title: 'Remain Still',
        description: 'Stay relaxed and quiet for 30 seconds while measurements are taken. Movement affects accuracy.',
        icon: Icons.accessibility_new_rounded,
        color: theme.colorScheme.primary.withValues(alpha: 0.8),
      ),
    ];

    return _AnimatedPageContent(
      animationController: _contentController,
      pageIndex: 2,
      currentStep: _currentStep,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AnimatedHeader(
              animationController: _headerController,
              child: _buildStepHeader(
                'Screening Instructions',
                'Follow these steps for accurate measurements',
                Icons.medical_services_outlined,
              ),
            ),
            const AppSpacing.vxl(),
            AppStaggeredList(
              duration: AppTheme.durationMd,
              delay: const Duration(milliseconds: 100),
              children: instructions.asMap().entries.map((entry) {
                final index = entry.key;
                final instruction = entry.value;
                return _buildInstructionCard(instruction, index);
              }).toList(),
            ),
            const AppSpacing.vlg(),
            _buildImportantNotesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard(_Instruction instruction, int index) {
    final theme = Theme.of(context);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [instruction.color, instruction.color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Center(
              child: Text(
                instruction.number,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          const AppSpacing.hmd(),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: instruction.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(instruction.icon, color: instruction.color, size: 24),
          ),
          const AppSpacing.hmd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const AppSpacing.vxs(),
                Text(
                  instruction.description,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportantNotesCard() {
    final theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      border: BorderSide(color: theme.colorScheme.tertiary.withValues(alpha: 0.3), width: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.tertiary, size: 24),
          const AppSpacing.hmd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Notes',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
                const AppSpacing.vsm(),
                Text(
                  '• Experimental BP estimation is NOT clinically validated\n'
                  '• This is a screening tool, NOT a diagnostic device\n'
                  '• Results require clinical verification\n'
                  '• Do not make medical decisions based solely on this device',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: AppOutlinedButton(
                label: 'Back',
                icon: const Icon(Icons.arrow_back_rounded, size: 24),
                onPressed: _previousStep,
                minHeight: 56,
              ),
            ),
          if (_currentStep > 0) const AppSpacing.hmd(),
          Expanded(
            flex: _currentStep > 0 ? 1 : 2,
            child: AppButton(
              label: _currentStep == 2 ? 'Start Screening' : 'Next',
              icon: _currentStep == 2 ? const Icon(Icons.play_arrow_rounded, size: 24) : const Icon(Icons.arrow_forward_rounded, size: 24),
              trailingIcon: _currentStep != 2 ? const Icon(Icons.arrow_forward_rounded, size: 24) : null,
              onPressed: _nextStep,
              minHeight: 56,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedPageContent extends StatefulWidget {
  final AnimationController animationController;
  final int pageIndex;
  final int currentStep;
  final Widget child;

  const _AnimatedPageContent({
    required this.animationController,
    required this.pageIndex,
    required this.currentStep,
    required this.child,
  });

  @override
  State<_AnimatedPageContent> createState() => _AnimatedPageContentState();
}

class _AnimatedPageContentState extends State<_AnimatedPageContent> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animationController,
      builder: (context, child) {
        final isCurrentPage = widget.currentStep == widget.pageIndex;
        final progress = widget.animationController.value;
        final fade = isCurrentPage ? 1.0 : (1.0 - progress).clamp(0.0, 1.0);
        final slide = isCurrentPage ? 0.0 : (0.3 * (1 - progress)).clamp(0.0, 0.3);

        return IgnorePointer(
          ignoring: !isCurrentPage,
          child: Opacity(
            opacity: fade,
            child: Transform.translate(
              offset: Offset(30 * slide, 0),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedHeader extends StatefulWidget {
  final AnimationController animationController;
  final Widget child;

  const _AnimatedHeader({
    required this.animationController,
    required this.child,
  });

  @override
  State<_AnimatedHeader> createState() => _AnimatedHeaderState();
}

class _AnimatedHeaderState extends State<_AnimatedHeader> with SingleTickerProviderStateMixin {
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: widget.animationController, curve: const Interval(0.0, 0.6, curve: AppTheme.curveDecelerate)),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: widget.animationController, curve: const Interval(0.2, 0.8, curve: AppTheme.curveDecelerate)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _Instruction {
  final String number;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  _Instruction({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}