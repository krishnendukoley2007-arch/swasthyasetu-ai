import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/core/services/edge_ai_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';

/// Interactive On-Device Edge AI Neural Benchmark & Validation Screen.
///
/// Demonstrates on-device 1D-CNN autoencoder rhythm morphology evaluation,
/// comparing inference reconstruction fidelity against verified synthetic
/// reference patterns (normal sinus rhythm vs ventricular ectopic vs fibrillatory ripple).
///
/// Upholds Mandate 2.5: Neural flags are strictly assistive/advisory and
/// never modify the deterministic clinical risk band.
class EdgeAiBenchmarkScreen extends ConsumerStatefulWidget {
  const EdgeAiBenchmarkScreen({super.key});

  @override
  ConsumerState<EdgeAiBenchmarkScreen> createState() =>
      _EdgeAiBenchmarkScreenState();
}

class _EdgeAiBenchmarkScreenState extends ConsumerState<EdgeAiBenchmarkScreen> {
  int _selectedProfileIndex = 0; // 0=MIT-100, 1=MIT-119, 2=MIT-201, 3=Live BLE
  EdgeAiDetailedEvaluation? _evaluation;
  bool _evaluating = false;

  @override
  void initState() {
    super.initState();
    _runInference();
  }

  Future<void> _runInference() async {
    setState(() => _evaluating = true);
    final aiService = ref.read(edgeAiServiceProvider);

    List<int> samples;
    if (_selectedProfileIndex < EdgeAiService.benchmarkProfiles.length) {
      samples = EdgeAiService.benchmarkProfiles[_selectedProfileIndex].samples;
    } else {
      // Live ESP32 BLE stream or fallback
      final bleLink = ref.read(bleServiceProvider);
      final captured = bleLink.capturedEcg;
      if (captured.length >= 128) {
        samples = captured.sublist(captured.length - 128);
      } else {
        samples = EdgeAiService.record100Nsr.samples;
      }
    }

    final eval = await aiService.evaluateDetailedWindow(ecgSamples: samples);
    if (mounted) {
      setState(() {
        _evaluation = eval;
        _evaluating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profiles = EdgeAiService.benchmarkProfiles;
    final isLiveSelected = _selectedProfileIndex == profiles.length;
    final activeProfile = !isLiveSelected
        ? profiles[_selectedProfileIndex]
        : null;

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('On-Device AI Benchmark'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Overview & Hardware Architecture
            _buildArchitectureBanner(theme),
            const SizedBox(height: AppTheme.spacingMd),

            // 2. Profile Selection Chips
            _buildProfileSelector(theme, profiles),
            const SizedBox(height: AppTheme.spacingMd),

            // 3. Clinical Profile Info
            if (activeProfile != null) ...[
              _buildClinicalProfileCard(theme, activeProfile),
              const SizedBox(height: AppTheme.spacingMd),
            ] else if (isLiveSelected) ...[
              _buildLiveStreamInfoCard(theme),
              const SizedBox(height: AppTheme.spacingMd),
            ],

            // 4. Reconstruction Visualizer Card
            if (_evaluation != null) ...[
              _buildVisualizerCard(theme, _evaluation!),
              const SizedBox(height: AppTheme.spacingMd),

              // 5. Hardware Latency & Inference Telemetry Metrics
              _buildMetricsGrid(theme, _evaluation!),
              const SizedBox(height: AppTheme.spacingMd),
            ],

            // 6. Mandate 2.5 Clinical Governance Notice
            _buildGovernanceDisclaimer(theme),
            const SizedBox(height: AppTheme.spacingLg),
          ],
        ),
      ),
    );
  }

  Widget _buildArchitectureBanner(ThemeData theme) {
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  Icons.memory_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qualcomm Snapdragon & NPU Pipeline',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '1D-CNN Autoencoder · Zero Cloud Round-Trip',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Evaluates Lead I biopotential waveforms directly on the edge. '
            'Models morphological feature compression across a 2-channel bottleneck to '
            'detect rhythm anomalies without sending patient biometrics to the cloud.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSelector(
    ThemeData theme,
    List<SyntheticEcgBenchmarkProfile> profiles,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT BENCHMARK RHYTHM',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingSm,
          children: [
            for (int i = 0; i < profiles.length; i++)
              ChoiceChip(
                label: Text(profiles[i].recordId),
                selected: _selectedProfileIndex == i,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedProfileIndex = i);
                    _runInference();
                  }
                },
              ),
            ChoiceChip(
              avatar: const Icon(Icons.bluetooth_audio_rounded, size: 16),
              label: const Text('Live ESP32 Stream'),
              selected: _selectedProfileIndex == profiles.length,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedProfileIndex = profiles.length);
                  _runInference();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClinicalProfileCard(
    ThemeData theme,
    SyntheticEcgBenchmarkProfile profile,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingXs,
            children: [
              Text(
                profile.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: profile.expectedAnomaly
                      ? AppTheme.tertiaryAmber.withValues(alpha: 0.2)
                      : AppTheme.riskGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: profile.expectedAnomaly
                        ? AppTheme.tertiaryAmber
                        : AppTheme.riskGreen,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  profile.expectedAnomaly
                      ? 'EXPECTED ANOMALY'
                      : 'EXPECTED NORMAL',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: profile.expectedAnomaly
                        ? AppTheme.tertiaryAmber
                        : AppTheme.riskGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            profile.diagnosisTag,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            profile.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStreamInfoCard(ThemeData theme) {
    final link = ref.watch(bleLinkProvider);
    final isStreaming = link.status == BleLinkStatus.streaming;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Row(
        children: [
          Icon(
            isStreaming ? Icons.sensors_rounded : Icons.sensors_off_rounded,
            color: isStreaming ? AppTheme.riskGreen : AppTheme.tertiaryAmber,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStreaming
                      ? 'Streaming from SSAI-SENSE-01'
                      : 'No Active Hardware Stream',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isStreaming
                      ? 'Testing live ECG window from patient biopotential electrodes.'
                      : 'Connect your ESP32 board over BLE to benchmark your own live rhythm.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _runInference,
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizerCard(ThemeData theme, EdgeAiDetailedEvaluation eval) {
    final statusColor = eval.isAnomaly
        ? AppTheme.tertiaryAmber
        : AppTheme.riskGreen;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingXs,
            children: [
              Text(
                'NEURAL RECONSTRUCTION DYNAMICS',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: statusColor, width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      eval.isAnomaly
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      eval.isAnomaly ? 'ANOMALY FLAGGED' : 'NORMAL SINUS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          if (_evaluating) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: AppTheme.spacingSm),
          ],

          // Custom waveform chart
          SizedBox(
            height: 180,
            child: CustomPaint(
              size: const Size(double.infinity, 180),
              painter: _NeuralReconstructionPainter(
                input: eval.inputNormalized,
                reconstructed: eval.reconstructed,
                residual: eval.perSampleSquaredResidual,
                isDark: theme.brightness == Brightness.dark,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),

          // Legend
          Wrap(
            spacing: AppTheme.spacingMd,
            runSpacing: AppTheme.spacingXs,
            children: [
              _buildLegendItem(
                color: const Color(0xFF00E5FF),
                label: 'Input ECG (Normalized)',
                isDashed: false,
                theme: theme,
              ),
              _buildLegendItem(
                color: const Color(0xFFFF9100),
                label: '1D-CNN Reconstruction',
                isDashed: true,
                theme: theme,
              ),
              _buildLegendItem(
                color: const Color(0xFFFF5252).withValues(alpha: 0.6),
                label: 'Squared Residual Error',
                isDashed: false,
                isBar: true,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required bool isDashed,
    bool isBar = false,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: isBar ? 8 : 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(ThemeData theme, EdgeAiDetailedEvaluation eval) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isHighScale = textScale > 1.3;

    final tile1 = _buildMetricTile(
      theme: theme,
      icon: Icons.timer_outlined,
      title: 'Inference Latency',
      value: '${eval.latencyMs.toStringAsFixed(2)} ms',
      subtitle: '<1.0 ms ultra-low budget',
      color: AppTheme.riskGreen,
    );
    final tile2 = _buildMetricTile(
      theme: theme,
      icon: Icons.speed_rounded,
      title: 'Peak Throughput',
      value: '${eval.throughputBps.toInt()} /s',
      subtitle: 'beats processed / sec',
      color: theme.colorScheme.primary,
    );
    final tile3 = _buildMetricTile(
      theme: theme,
      icon: Icons.calculate_outlined,
      title: 'Reconstruction MSE',
      value: eval.mse.toStringAsFixed(4),
      subtitle: 'Threshold: ${eval.threshold.toStringAsFixed(2)}',
      color: eval.isAnomaly ? AppTheme.tertiaryAmber : AppTheme.riskGreen,
    );
    final tile4 = _buildMetricTile(
      theme: theme,
      icon: Icons.data_usage_rounded,
      title: 'Model Footprint',
      value: '${eval.parameterCount} params',
      subtitle:
          '${(eval.modelSizeBytes / 1024).toStringAsFixed(1)} KB (100% offline)',
      color: theme.colorScheme.secondary,
    );

    if (isHighScale) {
      return Column(
        children: [
          tile1,
          const SizedBox(height: AppTheme.spacingSm),
          tile2,
          const SizedBox(height: AppTheme.spacingSm),
          tile3,
          const SizedBox(height: AppTheme.spacingSm),
          tile4,
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tile1),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(child: tile2),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Row(
          children: [
            Expanded(child: tile3),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(child: tile4),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGovernanceDisclaimer(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: ClinicalPalette.hairline(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mandate 2.5 — Advisory Edge AI Compliance',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Edge AI anomaly scores are purely assistive indicators derived '
                  'from autoencoder residual divergence. They NEVER alter deterministic '
                  'NEWS2 clinical risk bands or provide definitive arrhythmia diagnoses.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for side-by-side normalized input, reconstruction, and residual error heatmap.
class _NeuralReconstructionPainter extends CustomPainter {
  final List<double> input;
  final List<double> reconstructed;
  final List<double> residual;
  final bool isDark;

  _NeuralReconstructionPainter({
    required this.input,
    required this.reconstructed,
    required this.residual,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (input.isEmpty || reconstructed.isEmpty) return;

    final n = input.length;
    final w = size.width;
    final h = size.height;

    // Waveform area: top 72% of canvas, residual error bars: bottom 25%
    final waveH = h * 0.72;
    final resH = h * 0.22;

    // Grid lines & Zero-axis
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    final midY = waveH * 0.5;
    canvas.drawLine(Offset(0, midY), Offset(w, midY), gridPaint);
    canvas.drawLine(
      Offset(0, waveH * 0.25),
      Offset(w, waveH * 0.25),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, waveH * 0.75),
      Offset(w, waveH * 0.75),
      gridPaint,
    );

    // Range scaling: input is normalized around mean 0, span roughly -2.5 to +3.5
    const yMin = -2.5;
    const yMax = 3.5;
    const ySpan = yMax - yMin;

    double mapY(double val) {
      final norm = (val - yMin) / ySpan;
      final clamped = norm.clamp(0.0, 1.0);
      return waveH - (clamped * waveH);
    }

    // 1. Draw Residual Error Heatmap Bars at bottom
    final barW = w / n;
    final maxRes = residual.fold<double>(
      0.001,
      (prev, curr) => curr > prev ? curr : prev,
    );
    for (int i = 0; i < n; i++) {
      final normRes = (residual[i] / maxRes).clamp(0.0, 1.0);
      final barH = normRes * resH;
      final barPaint = Paint()
        ..color =
            (residual[i] > 0.06
                    ? const Color(0xFFFF5252)
                    : const Color(0xFF64FFDA))
                .withValues(alpha: 0.45 + normRes * 0.45);

      canvas.drawRect(Rect.fromLTWH(i * barW, h - barH, barW, barH), barPaint);
    }

    // 2. Draw 1D-CNN Reconstruction Line (Amber / Coral)
    final reconPaint = Paint()
      ..color = const Color(0xFFFF9100)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final reconPath = Path();
    for (int i = 0; i < n; i++) {
      final x = (i / (n - 1)) * w;
      final y = mapY(reconstructed[i]);
      if (i == 0) {
        reconPath.moveTo(x, y);
      } else {
        reconPath.lineTo(x, y);
      }
    }
    canvas.drawPath(reconPath, reconPaint);

    // 3. Draw Input ECG Waveform Line (Cyan / Blue solid)
    final inputPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final inputPath = Path();
    for (int i = 0; i < n; i++) {
      final x = (i / (n - 1)) * w;
      final y = mapY(input[i]);
      if (i == 0) {
        inputPath.moveTo(x, y);
      } else {
        inputPath.lineTo(x, y);
      }
    }
    canvas.drawPath(inputPath, inputPaint);
  }

  @override
  bool shouldRepaint(covariant _NeuralReconstructionPainter oldDelegate) {
    return oldDelegate.input != input ||
        oldDelegate.reconstructed != reconstructed ||
        oldDelegate.residual != residual ||
        oldDelegate.isDark != isDark;
  }
}
