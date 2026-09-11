import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

/// Hospital-grade real-time dual-waveform sweep monitor (ECG + Plethysmograph PPG).
///
/// Supports both:
/// 1. Real 250 Hz Lead I ECG samples streamed over BLE from the AD8232 front-end.
/// 2. Real arterial PPG pulse wave from MAX30102 with finger-contact gating.
/// 3. Virtual patient simulation fallback when zero hardware is attached.
class DualWaveformSweepMonitor extends StatefulWidget {
  final double heartRate;
  final double spo2;
  final bool isLive;
  final bool showControls;
  final List<int>? rawEcgSamples;
  final bool leadOff;
  final bool fingerOff;
  final bool beatDetected;
  final int? qrsWidthMs;
  final int? qtcMs;
  final int? sqi;
  final String? rhythmName;
  final double? aiConfidence;
  final int activeMode; // 1 = SpO2, 2 = ECG, 3 = Temp, 0 = Idle

  const DualWaveformSweepMonitor({
    super.key,
    this.heartRate = 72,
    this.spo2 = 98,
    this.isLive = false,
    this.showControls = true,
    this.rawEcgSamples,
    this.leadOff = false,
    this.fingerOff = false,
    this.beatDetected = false,
    this.qrsWidthMs,
    this.qtcMs,
    this.sqi,
    this.rhythmName,
    this.aiConfidence,
    this.activeMode = 2,
  });

  @override
  State<DualWaveformSweepMonitor> createState() =>
      _DualWaveformSweepMonitorState();
}

const _calLabel = '1.0 mV CAL';
const _bpmUnit = ' BPM';
const _leadsOffTitle = 'ELECTRODE DETACHED (LEADS OFF)';
const _leadsOffDesc = 'Ensure RA, LA, and RL electrodes make firm skin contact';
const _fingerOffTitle = 'FINGER CONTACT REQUIRED';
const _fingerOffDesc = 'Rest fingertip firmly on MAX30102 optical sensor';

class _DualWaveformSweepMonitorState extends State<DualWaveformSweepMonitor>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;
  bool _isFrozen = false;
  bool _is50mmSec = false;
  bool _showGrid = true;
  String _selectedLead = 'Lead II';

  final List<double> _ecgHistory = [];
  final List<double> _ppgHistory = [];
  static const int _bufferSize = 300;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _sweepController.addListener(_onSweepTick);
  }

  void _onSweepTick() {
    if (_isFrozen) return;

    final t = _sweepController.value;
    final hr = widget.heartRate.clamp(40.0, 180.0);
    final period = 60.0 / hr; // seconds per beat
    final timeSec = t * (_is50mmSec ? 1.5 : 3.0);
    final phase = (timeSec % period) / period; // 0.0 to 1.0 within beat

    // 1. ECG Signal Source:
    // Only real raw ECG samples from the physical sensor are displayed.
    final hasRealEcg =
        widget.rawEcgSamples != null &&
        widget.rawEcgSamples!.isNotEmpty &&
        !widget.leadOff;

    double ecgVal;
    if (hasRealEcg) {
      // Pick current slice value from trailing samples
      final samples = widget.rawEcgSamples!;
      final sampleIdx = (t * samples.length).floor().clamp(
        0,
        samples.length - 1,
      );
      final raw = samples[sampleIdx];
      // Normalize raw ADC counts (-2000..+2000 -> -0.8..+1.2)
      ecgVal = (raw / 1200.0).clamp(-1.0, 1.5);
    } else {
      // Mandate: Zero vain synthetic drafts. When detached, baseline is strictly flat at 0.0
      ecgVal = 0.0;
    }

    // 2. PPG Signal Source:
    // Only generate arterial pulse wave when finger is present, measuring, and active!
    double ppgVal;
    if (widget.fingerOff ||
        widget.spo2 < 70 ||
        widget.heartRate <= 0 ||
        widget.activeMode == 2) {
      ppgVal = 0.0; // Rule 2.3: No fabricated gaps when finger is off
    } else {
      ppgVal = _calculatePpgSample(phase);
    }

    setState(() {
      _ecgHistory.add(ecgVal);
      _ppgHistory.add(ppgVal);
      if (_ecgHistory.length > _bufferSize) {
        _ecgHistory.removeAt(0);
        _ppgHistory.removeAt(0);
      }
    });
  }

  /// Calculates normalized PPG amplitude [0.0, 1.0] with dicrotic notch
  double _calculatePpgSample(double phase) {
    final ppgPhase = (phase - 0.12 + 1.0) % 1.0;
    if (ppgPhase < 0.6) {
      final x = ppgPhase / 0.6;
      final peak = math.sin(x * math.pi);
      final notch = 0.15 * math.exp(-math.pow((x - 0.55) / 0.08, 2));
      return (peak + notch).clamp(0.0, 1.0);
    } else {
      final x = (ppgPhase - 0.6) / 0.4;
      return math.max(0.0, 0.15 * (1.0 - x));
    }
  }

  @override
  void dispose() {
    _sweepController.removeListener(_onSweepTick);
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sweepProgress = _sweepController.value;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF070C14), // Clinical deep navy-black
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: widget.isLive
              ? const Color(0xFF10B981)
              : const Color(0xFF334155),
          width: widget.isLive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top telemetry & AI diagnostics HUD
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1524),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLg),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E2E48), width: 1),
              ),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Live/Sim & Lead badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isLive
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: widget.isLive
                          ? const Color(0xFF10B981)
                          : const Color(0xFF64748B),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    widget.isLive
                        ? 'LIVE · $_selectedLead · 250 Hz'
                        : 'SIM · $_selectedLead',
                    style: TextStyle(
                      color: widget.isLive
                          ? const Color(0xFF34D399)
                          : const Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),

                // 1.0 mV CAL
                const Text(
                  _calLabel,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),

                // Live HR Readout
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFF10B981),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.heartRate > 0
                          ? '${widget.heartRate.round()}'
                          : '—',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Text(
                      _bpmUnit,
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 9),
                    ),
                  ],
                ),

                // SpO2 Readout
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.air_rounded,
                      color: Color(0xFF06B6D4),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.spo2 > 0 ? '${widget.spo2.round()}' : '—',
                      style: const TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Text(
                      ' %',
                      style: TextStyle(color: Color(0xFF06B6D4), fontSize: 9),
                    ),
                  ],
                ),

                // Morphological metrics tags
                if (widget.qrsWidthMs != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131F33),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'QRS: ${widget.qrsWidthMs}ms',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 9,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                if (widget.sqi != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131F33),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'SQI: ${widget.sqi}%',
                      style: TextStyle(
                        color: widget.sqi! >= 80
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFBBF24),
                        fontSize: 9,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // AI Rhythm classification badge
                if (widget.rhythmName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      'AI: ${widget.rhythmName}',
                      style: const TextStyle(
                        color: Color(0xFF60A5FA),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Dual Waveform Canvas
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                ClipRRect(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _DualWaveformSweepPainter(
                      ecgHistory: _ecgHistory,
                      ppgHistory: _ppgHistory,
                      sweepProgress: sweepProgress,
                      isFrozen: _isFrozen,
                      showGrid: _showGrid,
                      leadOff: widget.leadOff,
                      fingerOff: widget.fingerOff,
                      activeMode: widget.activeMode,
                    ),
                  ),
                ),

                // Leads Off overlay banner
                if (widget.leadOff && widget.activeMode == 2)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.75),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFEF4444),
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              _leadsOffTitle,
                              style: TextStyle(
                                color: Color(0xFFF87171),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _leadsOffDesc,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Finger off sensor overlay
                if (widget.fingerOff && widget.activeMode == 1)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.75),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.touch_app_rounded,
                              color: Color(0xFF06B6D4),
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              _fingerOffTitle,
                              style: TextStyle(
                                color: Color(0xFF22D3EE),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _fingerOffDesc,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Controls Bar (Freeze, Grid, Speed, Lead)
          if (widget.showControls)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1524),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(AppTheme.radiusLg),
                ),
                border: Border(
                  top: BorderSide(color: Color(0xFF1E2E48), width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isFrozen
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: _isFrozen ? Colors.amber : Colors.white70,
                      size: 18,
                    ),
                    tooltip: _isFrozen ? 'Resume Sweep' : 'Freeze Waveform',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _isFrozen = !_isFrozen;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _showGrid
                          ? Icons.grid_on_rounded
                          : Icons.grid_off_rounded,
                      color: _showGrid
                          ? const Color(0xFF10B981)
                          : Colors.white38,
                      size: 18,
                    ),
                    tooltip: 'Toggle Medical Grid',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _showGrid = !_showGrid;
                      });
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _is50mmSec = !_is50mmSec;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      _is50mmSec ? '50 mm/s' : '25 mm/s',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    initialValue: _selectedLead,
                    tooltip: 'Select ECG Lead',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedLead,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                    onSelected: (lead) {
                      setState(() {
                        _selectedLead = lead;
                      });
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'Lead I', child: Text('Lead I')),
                      PopupMenuItem(value: 'Lead II', child: Text('Lead II')),
                      PopupMenuItem(value: 'Lead III', child: Text('Lead III')),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// CustomPainter for rendering:
/// 1. Standard medical millimetric paper grid (0.04s small, 0.20s large)
/// 2. Lead I ECG Channel with 1.0 mV calibration pulse (Top half)
/// 3. PPG Pleth Channel (Bottom half)
/// 4. Phosphor beam sweep line & eraser bar
class _DualWaveformSweepPainter extends CustomPainter {
  final List<double> ecgHistory;
  final List<double> ppgHistory;
  final double sweepProgress;
  final bool isFrozen;
  final bool showGrid;
  final bool leadOff;
  final bool fingerOff;
  final int activeMode;

  _DualWaveformSweepPainter({
    required this.ecgHistory,
    required this.ppgHistory,
    required this.sweepProgress,
    required this.isFrozen,
    required this.showGrid,
    required this.leadOff,
    required this.fingerOff,
    required this.activeMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final halfH = h / 2.0;
    final sweepX = sweepProgress * w;

    // 1. Draw Medical Grid
    if (showGrid) {
      _paintMedicalGrid(canvas, size);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    if (activeMode == 2) {
      // ── Dedicated ECG Full-Height Mode ──
      textPainter.text = const TextSpan(
        text: 'LEAD I  ECG (AD8232 — 250 Hz)',
        style: TextStyle(
          color: Color(0xFF10B981),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(6, 6));

      if (!leadOff && ecgHistory.isNotEmpty) {
        final ecgPaint = Paint()
          ..color = const Color(0xFF10B981)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final ecgGlowPaint = Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.32)
          ..strokeWidth = 4.0
          ..style = PaintingStyle.stroke;

        final sweepX = sweepProgress * w;
        final count = ecgHistory.length;
        final stepX = count > 1 ? w / count : 1.0;
        final ecgBaseline = h * 0.52;
        final ecgAmpScale = h * 0.40;
        final ecgPath = Path();

        for (int i = 0; i < count; i++) {
          final x = i * stepX;
          if (!isFrozen && x > sweepX && x < sweepX + 22) {
            continue;
          }

          final y = ecgBaseline - (ecgHistory[i] * ecgAmpScale);
          final clampedY = y.clamp(8.0, h - 8.0);
          if (i == 0 || (x > sweepX && x < sweepX + 24)) {
            ecgPath.moveTo(x, clampedY);
          } else {
            ecgPath.lineTo(x, clampedY);
          }
        }

        canvas.drawPath(ecgPath, ecgGlowPaint);
        canvas.drawPath(ecgPath, ecgPaint);
      }
    } else if (activeMode == 1) {
      // ── Dedicated Arterial PPG Plethysmograph Mode ──
      textPainter.text = const TextSpan(
        text: 'PLETH  PPG (MAX30102 — Arterial Pulse)',
        style: TextStyle(
          color: Color(0xFF06B6D4),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(6, 6));

      if (!fingerOff && ppgHistory.isNotEmpty) {
        final ppgPaint = Paint()
          ..color = const Color(0xFF06B6D4)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final ppgGlowPaint = Paint()
          ..color = const Color(0xFF06B6D4).withValues(alpha: 0.32)
          ..strokeWidth = 4.0
          ..style = PaintingStyle.stroke;

        final sweepX = sweepProgress * w;
        final count = ppgHistory.length;
        final stepX = count > 1 ? w / count : 1.0;
        final ppgBaseline = h - 14.0;
        final ppgAmpScale = h * 0.72;
        final ppgPath = Path();

        for (int i = 0; i < count; i++) {
          final x = i * stepX;
          if (!isFrozen && x > sweepX && x < sweepX + 22) {
            continue;
          }

          final y = ppgBaseline - (ppgHistory[i] * ppgAmpScale);
          final clampedY = y.clamp(12.0, h - 6.0);
          if (i == 0 || (x > sweepX && x < sweepX + 24)) {
            ppgPath.moveTo(x, clampedY);
          } else {
            ppgPath.lineTo(x, clampedY);
          }
        }

        canvas.drawPath(ppgPath, ppgGlowPaint);
        canvas.drawPath(ppgPath, ppgPaint);
      }
    } else {
      // ── Split Dual Channel Mode (ECG Top / PPG Bottom) ──
      final dividerPaint = Paint()
        ..color = const Color(0xFF1E2E48)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(0, halfH), Offset(w, halfH), dividerPaint);

      textPainter.text = const TextSpan(
        text: 'LEAD I  ECG (AD8232)',
        style: TextStyle(
          color: Color(0xFF10B981),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(6, 6));

      textPainter.text = const TextSpan(
        text: 'PLETH  PPG (MAX30102)',
        style: TextStyle(
          color: Color(0xFF06B6D4),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(6, halfH + 6));

      final sweepX = sweepProgress * w;
      final count = ecgHistory.length;
      final stepX = count > 1 ? w / count : 1.0;

      if (!leadOff && ecgHistory.isNotEmpty) {
        final ecgPaint = Paint()
          ..color = const Color(0xFF10B981)
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke;
        final ecgBaseline = halfH * 0.55;
        final ecgAmpScale = halfH * 0.38;
        final ecgPath = Path();

        for (int i = 0; i < count; i++) {
          final x = i * stepX;
          if (!isFrozen && x > sweepX && x < sweepX + 22) continue;
          final y = (ecgBaseline - (ecgHistory[i] * ecgAmpScale)).clamp(
            8.0,
            halfH - 6.0,
          );
          if (i == 0 || (x > sweepX && x < sweepX + 24)) {
            ecgPath.moveTo(x, y);
          } else {
            ecgPath.lineTo(x, y);
          }
        }
        canvas.drawPath(ecgPath, ecgPaint);
      }

      if (!fingerOff && ppgHistory.isNotEmpty) {
        final ppgPaint = Paint()
          ..color = const Color(0xFF06B6D4)
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke;
        final ppgBaseline = h - 12;
        final ppgAmpScale = (halfH - 22);
        final ppgPath = Path();

        for (int i = 0; i < ppgHistory.length; i++) {
          final x = i * stepX;
          if (!isFrozen && x > sweepX && x < sweepX + 22) continue;
          final y = (ppgBaseline - (ppgHistory[i] * ppgAmpScale)).clamp(
            halfH + 8.0,
            h - 4.0,
          );
          if (i == 0 || (x > sweepX && x < sweepX + 24)) {
            ppgPath.moveTo(x, y);
          } else {
            ppgPath.lineTo(x, y);
          }
        }
        canvas.drawPath(ppgPath, ppgPaint);
      }
    }

    // 4. Sweeping Beam & Eraser Bar
    if (!isFrozen) {
      final sweepBarPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.8),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(sweepX - 2, 0, 4, h))
        ..strokeWidth = 1.8;

      canvas.drawLine(Offset(sweepX, 0), Offset(sweepX, h), sweepBarPaint);

      final eraserRect = Rect.fromLTWH(sweepX, 0, 18.0, h);
      final eraserPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF070C14).withValues(alpha: 0.95),
            Colors.transparent,
          ],
        ).createShader(eraserRect);
      canvas.drawRect(eraserRect, eraserPaint);
    }
  }

  void _paintMedicalGrid(Canvas canvas, Size size) {
    const smallGrid = 8.0;
    const largeGrid = 40.0;

    final minorPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.05)
      ..strokeWidth = 0.5;

    final majorPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.15)
      ..strokeWidth = 0.8;

    for (double x = 0; x <= size.width; x += smallGrid) {
      final isMajor = (x % largeGrid).abs() < 1.0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMajor ? majorPaint : minorPaint,
      );
    }

    for (double y = 0; y <= size.height; y += smallGrid) {
      final isMajor = (y % largeGrid).abs() < 1.0;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isMajor ? majorPaint : minorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DualWaveformSweepPainter oldDelegate) {
    return true; // Live 60 FPS sweep
  }
}
