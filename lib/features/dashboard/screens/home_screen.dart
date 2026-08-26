import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/constants/app_constants.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/device.dart';
import 'package:swasthyasetu_ai/domain/models/environment.dart';
import 'package:swasthyasetu_ai/domain/models/screening.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';
import 'package:swasthyasetu_ai/features/environment/state/environment_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _heroController;
  late AnimationController _statsController;
  late AnimationController _actionsController;
  late AnimationController _devicePulseController;
  late AnimationController _backgroundController;

  late Animation<double> _devicePulseAnimation;
  late Animation<double> _backgroundFloatAnimation;

  final Device _demoDevice = Device.demo();

  /// Counted from rows on this phone, never held as a literal. The dashboard
  /// previously carried `_todayScreenings = 3` and `_totalPatients = 12` as
  /// fields, which meant a worker who had recorded nothing all morning still
  /// saw three screenings and twelve patients.
  DashboardStats get _stats => ref.watch(dashboardStatsProvider);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

void _initializeAnimations() {
    _heroController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _statsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _actionsController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _devicePulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat(reverse: true);

    _devicePulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _devicePulseController, curve: Curves.easeInOut),
    );

    _backgroundFloatAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_backgroundController);
  }

  void _startAnimations() async {
    await _heroController.forward();
    await _statsController.forward();
    await _actionsController.forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    _statsController.dispose();
    _actionsController.dispose();
    _devicePulseController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = _demoDevice.isConnected;

    return AppPageScaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.appName,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          _buildNotificationButton(),
          _buildProfileButton(),
        ],
        elevation: 0,
        scrolledUnderElevation: AppTheme.elevationLevel1,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surface,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _backgroundController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      // Positioned.fill, not a bare child: the decorative layer
                      // is all `Positioned`, so as a sizing child it left this
                      // Stack with no intrinsic height inside a sliver — an
                      // unbounded-constraints crash in debug and a broken
                      // paint in release. The Column below is the only thing
                      // that should decide how tall this section is.
                      Positioned.fill(child: _buildBackgroundElements()),
                      Column(
                        children: [
                          _buildAnimatedWidget(
                            controller: _heroController,
                            delay: const Duration(milliseconds: 0),
                            child: _buildHeroSection(isConnected),
                          ),
                          _buildAnimatedWidget(
                            controller: _statsController,
                            delay: const Duration(milliseconds: 200),
                            child: _buildStatsSection(),
                          ),
                          _buildAnimatedWidget(
                            controller: _statsController,
                            delay: const Duration(milliseconds: 400),
                            child: _buildLastScreeningSection(),
                          ),
                          _buildAnimatedWidget(
                            controller: _actionsController,
                            delay: const Duration(milliseconds: 600),
                            child: _buildQuickActionsSection(),
                          ),
                          _buildAnimatedWidget(
                            controller: _actionsController,
                            delay: const Duration(milliseconds: 800),
                            child: _buildDisclaimerCard(),
                          ),
                          const AppSpacing.vxl(),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedWidget({
    required AnimationController controller,
    required Duration delay,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = controller.value;
        final delayedProgress = ((progress * 1000) - delay.inMilliseconds).clamp(0, 1000) / 1000;
        final curvedProgress = Curves.easeOutCubic.transform(delayedProgress);
        
        return Opacity(
          opacity: curvedProgress.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - curvedProgress)),
            child: Transform.scale(
              scale: 0.95 + 0.05 * curvedProgress,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildBackgroundElements() {
    return AnimatedBuilder(
      animation: _backgroundFloatAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: -100 + 50 * _backgroundFloatAnimation.value,
              right: -50 + 30 * _backgroundFloatAnimation.value,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.03),
                      AppTheme.primaryGreen.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80 + 40 * _backgroundFloatAnimation.value,
              left: -60 + 25 * _backgroundFloatAnimation.value,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.secondaryTeal.withValues(alpha: 0.02),
                      AppTheme.secondaryTeal.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroSection(bool isConnected) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          _buildDeviceStatusCard(isConnected),
          const AppSpacing.vxl(),
          _buildGreetingSection(),
          const AppSpacing.vlg(),
          _buildEnvironmentBanner(),
        ],
      ),
    );
  }

  /// Shown only when today's conditions carry advice — heat, bad air — that
  /// changes how the worker should sequence and counsel a day's rounds.
  /// Absent when conditions are ordinary: a permanent banner is wallpaper.
  Widget _buildEnvironmentBanner() {
    final theme = Theme.of(context);
    final advisories =
        ref.watch(environmentAdvisoriesProvider).valueOrNull ?? const [];
    if (advisories.isEmpty) return const SizedBox.shrink();

    final top = advisories.first;
    final isWarning = top.level == AdvisoryLevel.warning;
    final color = isWarning
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.tertiaryContainer;
    final onColor = isWarning
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onTertiaryContainer;

    return AppCard(
      color: color,
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      onTap: () => context.push('/advisories'),
      child: Row(
        children: [
          Icon(
            isWarning
                ? Icons.warning_amber_rounded
                : Icons.tips_and_updates_outlined,
            color: onColor,
            size: 22,
          ),
          const AppSpacing.hmd(),
          Expanded(
            child: Text(
              top.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: onColor),
        ],
      ),
    );
  }

  /// True when a text block and a labelled button cannot share a row.
  ///
  /// The dashboard's two header rows each pair prose with a real button label
  /// ("New Screening", "Connect"). Both need roughly 420 logical pixels before
  /// they fit side by side, and every step of font scaling pushes that figure
  /// up — so on a 360 px field phone they stack, which also puts the primary
  /// action within thumb reach. Neither the prose nor the label is ever
  /// truncated.
  bool _stacksHeaderActions(double maxWidth) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return maxWidth < 420 * scale;
  }

  Widget _buildDeviceStatusCard(bool isConnected) {
    final theme = Theme.of(context);

    final identity = Row(
      children: [
          AnimatedBuilder(
            animation: _devicePulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isConnected ? _devicePulseAnimation.value : 1.0,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isConnected
                          ? [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withValues(alpha: 0.7),
                            ]
                          : [
                              theme.colorScheme.outlineVariant,
                              theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    boxShadow: isConnected
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isConnected
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_disabled_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 34,
                  ),
                ),
              );
            },
          ),
          const AppSpacing.hmd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wrap, not Row: the label and the connection pill are both
                // intrinsically sized, so at large font settings they ran past
                // the card edge instead of dropping onto a second line.
                Wrap(
                  spacing: AppTheme.spacingSm,
                  runSpacing: AppTheme.spacingXs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Device',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    _buildConnectionIndicator(isConnected),
                  ],
                ),
                const AppSpacing.vxs(),
                Text(
                  _demoDevice.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const AppSpacing.vxs(),
                Row(
                  children: [
                    // Flexible at the call site, because the battery indicator
                    // is itself a Row with a flexible label: without a bound
                    // from here it is measured against infinite width and its
                    // own flex child can never be laid out.
                    Flexible(child: _buildBatteryIndicator()),
                    if (_demoDevice.isDemo) ...[
                      const AppSpacing.hsm(),
                      _buildDemoBadge(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      );

    final action = _buildDeviceActionButton(isConnected);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: LayoutBuilder(
        builder: (context, constraints) => _stacksHeaderActions(constraints.maxWidth)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [identity, const AppSpacing.vmd(), action],
              )
            : Row(children: [Expanded(child: identity), action]),
      ),
    );
  }

  Widget _buildGreetingSection() {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    final greetingText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const AppSpacing.vxs(),
        Text(
          'Ready for your next screening',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final action = _buildPrimaryActionButton();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_stacksHeaderActions(constraints.maxWidth)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [greetingText, const AppSpacing.vmd(), action],
          );
        }
        return Row(
          children: [
            Expanded(child: greetingText),
            const AppSpacing.hmd(),
            action,
          ],
        );
      },
    );
  }

  Widget _buildPrimaryActionButton() {
    final theme = Theme.of(context);

    return AppButton(
      label: 'New Screening',
      icon: const Icon(Icons.add_rounded, size: 24),
      isExpanded: false,
      onPressed: () => context.go('/screening/new'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(160, 56),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingXxl,
          vertical: AppTheme.spacingMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
        textStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final theme = Theme.of(context);

    final l10n = context.l10n;
    final stats = _stats;
    // Before the streams have delivered, a tile says nothing rather than saying
    // zero. "No screenings today" is a claim; "not loaded yet" is not.
    String count(int n) => stats.ready ? n.toString() : '—';

    final tiles = [
      _StatData(
        label: l10n.homeStatToday,
        value: count(stats.todayScreenings),
        icon: Icons.assignment_rounded,
        color: theme.colorScheme.primary,
      ),
      _StatData(
        label: l10n.homeStatPending,
        value: count(stats.pendingSync),
        icon: Icons.cloud_queue_rounded,
        color: stats.pendingSync > 0
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary,
        trend: !stats.ready
            ? null
            : (stats.pendingSync > 0 ? l10n.syncWaiting : l10n.syncUploaded),
        trendPositive: stats.pendingSync == 0,
        tapRoute: stats.pendingSync > 0 ? '/sync' : null,
      ),
      _StatData(
        label: l10n.homeStatHighRisk,
        value: count(stats.highRiskToday),
        icon: Icons.warning_amber_rounded,
        color: theme.colorScheme.error,
      ),
      _StatData(
        label: l10n.homeStatPatients,
        value: count(stats.totalPatients),
        icon: Icons.people_rounded,
        color: theme.colorScheme.secondary,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: l10n.homeOverview,
            action: TextButton(
              onPressed: () => context.go('/history'),
              child: Text(l10n.navHistory, style: theme.textTheme.labelLarge),
            ),
          ),
          const AppSpacing.vsm(),
          AppStaggeredList(
            duration: AppTheme.durationMd,
            delay: const Duration(milliseconds: 80),
            children: tiles.map((stat) => _buildStatCard(stat)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(_StatData stat) {
    final theme = Theme.of(context);
    final isZero = stat.value == '0';

    return AppElevatedCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      onTap: stat.tapRoute == null ? null : () => context.go(stat.tapRoute!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: AppTheme.durationSm,
                padding: const EdgeInsets.all(AppTheme.spacingSm),
                decoration: BoxDecoration(
                  color: isZero
                      ? theme.colorScheme.outlineVariant.withValues(alpha: 0.2)
                      : stat.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  stat.icon,
                  color: isZero ? theme.colorScheme.onSurfaceVariant : stat.color,
                  size: 22,
                ),
              ),
              const Spacer(),
              // No trend arrow. The old badge always pointed up and always read
              // "+", whatever the number beside it was — a direction the app had
              // never computed. Day-over-day deltas are not stored, so there is
              // nothing honest to draw here.
            ],
          ),
          const AppSpacing.vsm(),
          Flexible(
            child: Text(
              stat.value,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isZero ? theme.colorScheme.onSurfaceVariant : stat.color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const AppSpacing.vxs(),
          Flexible(
            child: Text(
              stat.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          if (stat.trend != null) ...[
            const AppSpacing.vxs(),
            Flexible(
              child: Text(
                stat.trend!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: stat.trendPositive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLastScreeningSection() {
    final theme = Theme.of(context);
    final recent = ref.watch(recentScreeningsProvider).valueOrNull;
    final last = (recent?.isEmpty ?? true) ? null : recent!.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: context.l10n.homeLastScreening,
            action: TextButton(
              onPressed: () => context.go('/history'),
              child: Text(context.l10n.navHistory,
                  style: theme.textTheme.labelLarge),
            ),
          ),
          const AppSpacing.vsm(),
          AppCard(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: last == null
                ? _buildNoScreeningContent()
                : _buildLastScreeningContent(last),
          ),
        ],
      ),
    );
  }

  /// The real last screening.
  ///
  /// This card used to render the band `GREEN` and the vitals 72 / 98 / 36.5
  /// whatever the row said — three numbers a worker could reasonably have read
  /// as the reading they had just taken. Every value below now comes off
  /// [screening], and a field the board never filled in shows a dash.
  Widget _buildLastScreeningContent(Screening screening) {
    final theme = Theme.of(context);
    final risk = RiskStyle.ofStorage(screening.riskLevel, context.l10n);

    // Zero is the not-measured sentinel on these columns, not a reading: nobody
    // is being screened at 0 bpm. Rendered as a dash so an empty column cannot
    // read as a measurement.
    String? measured(num v, {int digits = 0}) =>
        v <= 0 ? null : v.toStringAsFixed(digits);

    return Column(
      children: [
        Row(
          children: [
            AppRiskBadge(
              riskLevel: screening.riskLevel,
              isCompact: true,
              animate: true,
            ),
            const AppSpacing.hmd(),
            Expanded(
              child: Text(
                '${risk.label} • ${relativeTime(screening.timestamp)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const AppSpacing.vlg(),
        // Thirds rather than spaceAround: real readings are wider than the
        // 72 / 98 / 36.5 placeholders this row used to hardcode ("120 bpm" plus
        // a large text scale overflowed a 360 dp phone by 65 px), and each
        // column scales its own number down instead of pushing its neighbours
        // off the card.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildAnimatedVitalItem(
                  'HR',
                  measured(screening.heartRate),
                  'bpm',
                  Icons.favorite_rounded,
                  theme.colorScheme.primary),
            ),
            Expanded(
              child: _buildAnimatedVitalItem('SpO₂', measured(screening.spo2),
                  '%', Icons.air_rounded, theme.colorScheme.secondary),
            ),
            Expanded(
              child: _buildAnimatedVitalItem(
                  'Temp',
                  measured(screening.temperature, digits: 1),
                  '°C',
                  Icons.thermostat_rounded,
                  theme.colorScheme.tertiary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedVitalItem(String label, String? value, String unit,
      IconData icon, Color color) {
    final theme = Theme.of(context);

    return AppPulseAnimation(
      minScale: 0.98,
      maxScale: 1.02,
      duration: const Duration(milliseconds: 2000),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const AppSpacing.vsm(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              maxLines: 1,
              text: TextSpan(
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
                children: [
                  TextSpan(text: value ?? '—'),
                  if (value != null)
                    TextSpan(
                      text: ' $unit',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoScreeningContent() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const AppSpacing.vlg(),
          Text(
            'No screenings today',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const AppSpacing.vxs(),
          Text(
            'Start a new screening to begin',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const AppSpacing.vlg(),
          AppButton(
            label: context.l10n.navScreening,
            icon: const Icon(Icons.add_rounded, size: 24),
            onPressed: () => context.go('/screening/new'),
            isExpanded: false,
            minWidth: 160,
            minHeight: 56,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    final theme = Theme.of(context);

    final l10n = context.l10n;
    final pending = _stats.pendingSync;
    final actions = [
      _ActionData(
        label: l10n.navPatients,
        icon: Icons.people_outline_rounded,
        color: theme.colorScheme.secondary,
        route: '/patients',
      ),
      _ActionData(
        label: l10n.navHistory,
        icon: Icons.history_rounded,
        color: theme.colorScheme.primary.withValues(alpha: 0.8),
        route: '/history',
      ),
      _ActionData(
        label: pending > 0 ? l10n.navSync : l10n.syncUploaded,
        icon: pending > 0
            ? Icons.cloud_upload_rounded
            : Icons.cloud_done_rounded,
        color: pending > 0
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary,
        route: '/sync',
        hasBadge: pending > 0,
        badgeCount: pending,
      ),
      _ActionData(
        label: l10n.navDevices,
        icon: Icons.bluetooth_rounded,
        color: theme.colorScheme.primary,
        route: '/devices/scan',
      ),
      _ActionData(
        label: l10n.navCommunity,
        icon: Icons.insights_outlined,
        color: theme.colorScheme.secondary,
        route: '/community',
        usePush: true,
      ),
      _ActionData(
        label: 'Health guides',
        icon: Icons.health_and_safety_outlined,
        color: theme.colorScheme.tertiary,
        route: '/advisories',
        usePush: true,
      ),
      _ActionData(
        label: l10n.navSos,
        icon: Icons.sos_rounded,
        color: theme.colorScheme.error,
        route: '/emergency/sos',
        usePush: true,
      ),
      _ActionData(
        label: l10n.navSettings,
        icon: Icons.settings_outlined,
        color: theme.colorScheme.onSurfaceVariant,
        route: '/settings',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: l10n.homeQuickActions,
          ),
          const AppSpacing.vsm(),
          AppStaggeredList(
            duration: AppTheme.durationMd,
            delay: const Duration(milliseconds: 100),
            children: actions.map((action) => _buildActionButton(action)).toList(),
          ),
        ],
      ),
    );
  }

Widget _buildActionButton(_ActionData action) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Stack(
        children: [
          InkWell(
            onTap: () => action.usePush
                ? context.push(action.route)
                : context.go(action.route),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingXl),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        action.color.withValues(alpha: 0.15),
                        action.color.withValues(alpha: 0.1)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  ),
                  child: Icon(action.icon, color: action.color, size: 32),
                ),
                const AppSpacing.vmd(),
                Text(
                  action.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (action.hasBadge)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    action.badgeCount.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

Widget _buildDisclaimerCard() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: AppFilledCard(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: theme.colorScheme.onTertiaryContainer,
                size: 20,
              ),
            ),
            const AppSpacing.hmd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medical Disclaimer',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const AppSpacing.vxs(),
                  Text(
                    'This is a screening and decision-support prototype. It is NOT a certified medical device. It must NOT claim to diagnose diseases. All results require clinical verification by a qualified healthcare professional.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator(bool isConnected) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
      decoration: BoxDecoration(
        color: isConnected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isConnected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
          const AppSpacing.hxs(),
          // Flexible so the label can wrap inside the pill: a non-flex child of
          // a Row is measured against unbounded width, so at 2.0x
          // "Disconnected" pushed the pill past the card edge.
          Flexible(
            child: Text(
              isConnected ? 'Connected' : 'Disconnected',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isConnected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryIndicator() {
    final theme = Theme.of(context);
    final battery = _demoDevice.batteryPercent;
    final isLow = battery <= 20;

    return Row(
      children: [
        Icon(
          battery > 20
              ? Icons.battery_std_rounded
              : Icons.battery_alert_rounded,
          size: 18,
          color: isLow
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
        const AppSpacing.hxs(),
        Expanded(
          child: Text(
              '$battery%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isLow ? theme.colorScheme.error : theme.colorScheme.onSurface,
              ),
            ),
        ),
      ],
    );
  }

  Widget _buildDemoBadge() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
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
    );
  }

  Widget _buildDeviceActionButton(bool isConnected) {
    return AppOutlinedButton(
      label: isConnected ? 'Manage' : 'Connect',
      icon: Icon(isConnected
          ? Icons.settings_rounded
          : Icons.bluetooth_searching_rounded, size: 24),
      isExpanded: false,
      onPressed: () => context.go('/devices/scan'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(140, 52),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingXl,
          vertical: AppTheme.spacingMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
      ),
    );
  }

  Widget _buildNotificationButton() {
    return IconButton(
      onPressed: () => context.go('/sync'),
      icon: Stack(
        children: [
          const Icon(Icons.notifications_outlined),
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileButton() {
    final account = ref.watch(authStateProvider).account;
    final workerName = ref.watch(settingsProvider).workerName;
    final displayName = workerName.isNotEmpty
        ? workerName
        : account?.displayName ?? '';
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'D'; // demo session

    return PopupMenuButton<String>(
      icon: CircleAvatar(
        radius: 18,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          initial,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      onSelected: (value) {
        if (value == 'ui_showcase') {
          context.go('/debug/ui-showcase');
        } else if (value == 'settings') {
          context.go('/settings');
        } else if (value == 'signout') {
          ref.read(authStateProvider.notifier).signOut();
          // Redirect watches the session; nothing to navigate by hand.
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_rounded, size: 20),
              SizedBox(width: 12),
              Text('Settings'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'ui_showcase',
          child: Row(
            children: [
              Icon(Icons.palette_rounded, size: 20),
              SizedBox(width: 12),
              Text('UI Showcase'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 20),
              SizedBox(width: 12),
              Text('Sign out'),
            ],
          ),
        ),
      ],
    );
  }

  /// Pull-to-refresh.
  ///
  /// It used to wait 800 ms and then run `_todayScreenings += 1; _pendingSync = 0`
  /// — a gesture that invented a screening and emptied a sync queue that was
  /// still full. The counts come off drift streams that already push on every
  /// write, so the only honest thing a manual pull can do is re-read them.
  Future<void> _refreshData() async {
    ref.invalidate(recentScreeningsProvider);
    ref.invalidate(pendingScreeningsProvider);
    ref.invalidate(patientSummariesProvider);
    // Give the rebuilt streams a frame to deliver before the spinner retracts,
    // so the gesture does not look like it did nothing.
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// Only set where the app has something true to say about the number. Null
  /// renders nothing — the tile does not need a caption more than it needs to
  /// avoid inventing one.
  final String? trend;
  final bool trendPositive;

  /// Where tapping the tile leads, or null for a tile that is just a figure.
  final String? tapRoute;

  _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.trendPositive = true,
    this.tapRoute,
  });
}

class _ActionData {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  final bool hasBadge;
  final int badgeCount;

  /// Pushed rather than replacing the stack. Set for destinations a worker is
  /// visiting briefly and needs to back out of — an SOS especially, where
  /// `go` would make the system back button quit the app.
  final bool usePush;

  _ActionData({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
    this.hasBadge = false,
    this.badgeCount = 0,
    this.usePush = false,
  });
}