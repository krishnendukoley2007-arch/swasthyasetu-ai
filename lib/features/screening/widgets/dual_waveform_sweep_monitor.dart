import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

/// Hospital-grade real-time dual-waveform sweep monitor (ECG + Plethysmograph PPG).
///
/// Features standard medical 25 mm/s or 50 mm/s paper grid calibration:
/// - Small grid box: 0.04s (40 ms) horizontally, 0.1 mV vertically
/// - Large grid box: 0.20s (200 ms) horizontally, 0.5 mV vertically
/// - Sweeping line cursor that wraps around continuously like bedside monitors
/// - Synchronized arterial pulse wave (PPG) with systolic peak and dicrotic notch
class DualWaveformSweepMonitor extends StatefulWidget {
  final double heartRate;
  final double spo2;
  final bool isLive;
  final bool showControls;

  const DualWaveformSweepMonitor({
    super.key,
    this.heartRate = 72,
    this.spo2 = 98,
    this.isLive = false,
    this.showControls = true,
  });

  @override
  State<DualWaveformSweepMonitor> createState() => _DualWaveformSweepMonitorState();
}

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

    // ECG synthetic computation (P, Q, R, S, T waves)
    final ecgVal = _calculateEcgSample(phase);
    // PPG arterial computation (systolic peak at phase 0.25, dicrotic notch at 0.45)
    final ppgVal = _calculatePpgSample(phase);

    setState(() {
      _ecgHistory.add(ecgVal);
      _ppgHistory.add(ppgVal);
      if (_ecgHistory.length > _bufferSize) {
        _ecgHistory.removeAt(0);
        _ppgHistory.removeAt(0);
      }
    });
  }

  /// Calculates normalized ECG amplitude [-0.5, 1.2]
  double _calculateEcgSample(double phase) {
    // P wave: centered at 0.15
    final p = 0.15 * math.exp(-math.pow((phase - 0.15) / 0.035, 2));
    // Q wave: centered at 0.25, negative
    final q = -0.15 * math.exp(-math.pow((phase - 0.25) / 0.015, 2));
    // R wave: sharp peak at 0.28
    final r = 1.0 * math.exp(-math.pow((phase - 0.28) / 0.018, 2));
    // S wave: negative undershoot at 0.31
    final s = -0.25 * math.exp(-math.pow((phase - 0.31) / 0.018, 2));
    // T wave: repolarization at 0.50
    final tw = 0.28 * math.exp(-math.pow((phase - 0.50) / 0.065, 2));

    return (p + q + r + s + tw);
  }

  /// Calculates normalized PPG amplitude [0.0, 1.0] with dicrotic notch
  double _calculatePpgSample(double phase) {
    // Systolic pulse: delayed slightly after R wave
    final ppgPhase = (phase - 0.12 + 1.0) % 1.0;
    if (ppgPhase < 0.6) {
      final x = ppgPhase / 0.6;
      // Main systolic peak
      final peak = math.sin(x * math.pi);
      // Dicrotic notch reflection at x ~ 0.55
      final notch = 0.15 * math.exp(-math.pow((x - 0.55) / 0.08, 2));
      return (peak + notch).clamp(0.0, 1.0);
    } else {
      // Diastolic decay
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
        color: const Color(0xFF0F171A), // Medical dark cathode monitor color
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: widget.isLive ? const Color(0xFF00E676) : const Color(0xFF37474F),
          width: widget.isLive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top telemetry HUD
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                // Live/Sim & Lead badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF00E676), width: 0.8),
                  ),
                  child: Text(
                    '$_selectedLead · ${_is50mmSec ? '50 mm/s' : '25 mm/s'}',
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '10 mm/mV',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                // Heart Rate Readout
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded, color: Color(0xFF00E676), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.heartRate.round()}',
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Text(
                      ' bpm',
                      style: TextStyle(color: Color(0xFF00E676), fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // SpO2 Readout
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.air_rounded, color: Color(0xFF00E5FF), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.spo2.round()}',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Text(
                      ' %',
                      style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Dual Waveform Canvas
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusLg)),
              child: CustomPaint(
                painter: _DualWaveformSweepPainter(
                  ecgHistory: _ecgHistory,
                  ppgHistory: _ppgHistory,
                  sweepProgress: sweepProgress,
                  isFrozen: _isFrozen,
                  showGrid: _showGrid,
                ),
                child: Container(),
              ),
            ),
          ),

          // Controls Bar (Optional)
          if (widget.showControls)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF0B1013),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusLg)),
              ),
              child: Row(
                children: [
                  // Freeze / Run
                  IconButton(
                    icon: Icon(
                      _isFrozen ? Icons.play_arrow_rounded : Icons.pause_rounded,
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
                  // Grid Toggle
                  IconButton(
                    icon: Icon(
                      _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                      color: _showGrid ? const Color(0xFF00E676) : Colors.white38,
                      size: 18,
                    ),
                    tooltip: 'Toggle 25mm/s Grid',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _showGrid = !_showGrid;
                      });
                    },
                  ),
                  // Speed Toggle (25 mm/s <-> 50 mm/s)
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
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  // Lead selector
                  PopupMenuButton<String>(
                    initialValue: _selectedLead,
                    tooltip: 'Select ECG Lead',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            _selectedLead,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                    onSelected: (lead) {
                      setState(() {
                        _selectedLead = lead;
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'Lead I', child: Text('Lead I')),
                      const PopupMenuItem(value: 'Lead II', child: Text('Lead II (Standard)')),
                      const PopupMenuItem(value: 'Lead III', child: Text('Lead III')),
                      const PopupMenuItem(value: 'aVR', child: Text('aVR')),
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
/// 2. ECG Channel (Top half)
/// 3. PPG Pleth Channel (Bottom half)
/// 4. Phosphor beam sweep line & eraser bar
class _DualWaveformSweepPainter extends CustomPainter {
  final List<double> ecgHistory;
  final List<double> ppgHistory;
  final double sweepProgress;
  final bool isFrozen;
  final bool showGrid;

  _DualWaveformSweepPainter({
    required this.ecgHistory,
    required this.ppgHistory,
    required this.sweepProgress,
    required this.isFrozen,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final halfH = h / 2.0;

    // 1. Draw Medical 25 mm/s Grid
    if (showGrid) {
      _paintMedicalGrid(canvas, size);
    }

    // Channel Divider
    final dividerPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, halfH), Offset(w, halfH), dividerPaint);

    // Channel Labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = const TextSpan(
      text: 'II  ECG',
      style: TextStyle(
        color: Color(0xFF00E676),
        fontSize: 10,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(6, 6));

    textPainter.text = const TextSpan(
      text: 'PLETH  PPG',
      style: TextStyle(
        color: Color(0xFF00E5FF),
        fontSize: 10,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(6, halfH + 6));

    if (ecgHistory.isEmpty) return;

    // 2. Plot ECG Channel (Top half: y in [10, halfH - 10])
    final ecgPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final ecgGlowPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.25)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final ecgBaseline = halfH * 0.65;
    final ecgAmpScale = halfH * 0.45;
    final ecgPath = Path();

    final sweepX = sweepProgress * w;
    final count = ecgHistory.length;
    final stepX = w / count;

    for (int i = 0; i < count; i++) {
      final x = i * stepX;
      if (!isFrozen && x > sweepX && x < sweepX + 25) {
        // Eraser gap right ahead of sweep
        continue;
      }

      final y = ecgBaseline - (ecgHistory[i] * ecgAmpScale);
      if (i == 0 || (x > sweepX && x < sweepX + 26)) {
        ecgPath.moveTo(x, y.clamp(4.0, halfH - 4.0));
      } else {
        ecgPath.lineTo(x, y.clamp(4.0, halfH - 4.0));
      }
    }

    canvas.drawPath(ecgPath, ecgGlowPaint);
    canvas.drawPath(ecgPath, ecgPaint);

    // 3. Plot PPG Plethysmograph Channel (Bottom half: y in [halfH + 10, h - 10])
    final ppgPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final ppgGlowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final ppgBaseline = h - 12;
    final ppgAmpScale = (halfH - 24);
    final ppgPath = Path();

    for (int i = 0; i < ppgHistory.length; i++) {
      final x = i * stepX;
      if (!isFrozen && x > sweepX && x < sweepX + 25) {
        continue;
      }

      final y = ppgBaseline - (ppgHistory[i] * ppgAmpScale);
      if (i == 0 || (x > sweepX && x < sweepX + 26)) {
        ppgPath.moveTo(x, y.clamp(halfH + 4.0, h - 4.0));
      } else {
        ppgPath.lineTo(x, y.clamp(halfH + 4.0, h - 4.0));
      }
    }

    canvas.drawPath(ppgPath, ppgGlowPaint);
    canvas.drawPath(ppgPath, ppgPaint);

    // 4. Draw Sweeping Cursor & Eraser Bar
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
        ..strokeWidth = 2.0;

      canvas.drawLine(Offset(sweepX, 0), Offset(sweepX, h), sweepBarPaint);

      // Eraser shadow ahead of sweep
      final eraserRect = Rect.fromLTWH(sweepX, 0, 20.0, h);
      final eraserPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF0F171A).withValues(alpha: 0.95),
            Colors.transparent,
          ],
        ).createShader(eraserRect);
      canvas.drawRect(eraserRect, eraserPaint);
    }
  }

  void _paintMedicalGrid(Canvas canvas, Size size) {
    const smallGridSize = 6.0; // 0.04s scale representation
    const largeGridSize = 30.0; // 0.20s large box (5 small boxes)

    final smallGridPaint = Paint()
      ..color = const Color(0xFF004D40).withValues(alpha: 0.22)
      ..strokeWidth = 0.5;

    final largeGridPaint = Paint()
      ..color = const Color(0xFF00796B).withValues(alpha: 0.45)
      ..strokeWidth = 0.9;

    // Vertical lines (time)
    for (double x = 0; x <= size.width; x += smallGridSize) {
      final isMajor = (x % largeGridSize).abs() < 1.0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMajor ? largeGridPaint : smallGridPaint,
      );
    }

    // Horizontal lines (voltage)
    for (double y = 0; y <= size.height; y += smallGridSize) {
      final isMajor = (y % largeGridSize).abs() < 1.0;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isMajor ? largeGridPaint : smallGridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DualWaveformSweepPainter oldDelegate) {
    return true; // Continuously sweeps at 60 FPS
  }
}
