import 'package:flutter/material.dart';
import '../../domain/models/workout_session.dart';
import '../theme/fitness_theme.dart';

class BiomechanicalAvatarPainter extends CustomPainter {
  final WorkoutType workoutType;
  final double pitch; // degrees
  final double roll; // degrees
  final double jointAngle; // degrees
  final double formQuality; // 0..100%

  BiomechanicalAvatarPainter({
    required this.workoutType,
    required this.pitch,
    required this.roll,
    required this.jointAngle,
    required this.formQuality,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final isGoodForm = formQuality >= 75.0;
    final primaryGlow =
        isGoodForm ? FitnessTheme.neonLime : FitnessTheme.crimsonPeak;
    final jointColor =
        isGoodForm ? FitnessTheme.electricCyan : FitnessTheme.warmOrange;

    final bonePaint = Paint()
      ..color = primaryGlow
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final shadowPaint = Paint()
      ..color = primaryGlow.withValues(alpha: 0.35)
      ..strokeWidth = 7.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = jointColor
      ..style = PaintingStyle.fill;

    // Background target grid lines
    final gridPaint = Paint()
      ..color = FitnessTheme.border.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(cx - 50, cy), Offset(cx + 50, cy), gridPaint);
    canvas.drawLine(Offset(cx, cy - 50), Offset(cx, cy + 50), gridPaint);

    if (workoutType == WorkoutType.squats) {
      _drawSquatAvatar(
          canvas, cx, cy, bonePaint, shadowPaint, jointPaint, primaryGlow);
    } else if (workoutType == WorkoutType.pushups) {
      _drawPushupAvatar(
          canvas, cx, cy, bonePaint, shadowPaint, jointPaint, primaryGlow);
    } else {
      _drawStandingAvatar(
          canvas, cx, cy, bonePaint, shadowPaint, jointPaint, primaryGlow);
    }
  }

  void _drawSquatAvatar(
    Canvas canvas,
    double cx,
    double cy,
    Paint bonePaint,
    Paint shadowPaint,
    Paint jointPaint,
    Color glowColor,
  ) {
    // Normal squat depth flex: hip lowering according to jointAngle (0 to 90 degrees)
    final depthFactor = (jointAngle / 90.0).clamp(0.0, 1.2);
    final hipY = cy - 10 + (depthFactor * 35.0);
    final kneeOffset = (depthFactor * 30.0);

    final headPos = Offset(cx + (pitch * 0.4), hipY - 55);
    final neckPos = Offset(cx + (pitch * 0.3), hipY - 40);
    final spinePos = Offset(cx, hipY);

    // Legs: Hips -> Knees -> Ankles
    final leftKnee = Offset(cx - 24 - kneeOffset * 0.3, hipY + 30);
    final rightKnee = Offset(cx + 24 + kneeOffset * 0.3, hipY + 30);
    final leftAnkle = Offset(cx - 26, cy + 55);
    final rightAnkle = Offset(cx + 26, cy + 55);

    // Shoulders & Arms
    final leftShoulder = Offset(neckPos.dx - 18, neckPos.dy + 4);
    final rightShoulder = Offset(neckPos.dx + 18, neckPos.dy + 4);
    final leftHand = Offset(leftShoulder.dx - 10, hipY - 10);
    final rightHand = Offset(rightShoulder.dx + 10, hipY - 10);

    // Draw Glow & Bones
    void drawSegment(Offset a, Offset b) {
      canvas.drawLine(a, b, shadowPaint);
      canvas.drawLine(a, b, bonePaint);
    }

    // Spine & Head
    canvas.drawCircle(headPos, 9, jointPaint);
    drawSegment(neckPos, spinePos);

    // Arms
    drawSegment(neckPos, leftShoulder);
    drawSegment(neckPos, rightShoulder);
    drawSegment(leftShoulder, leftHand);
    drawSegment(rightShoulder, rightHand);

    // Legs
    drawSegment(spinePos, leftKnee);
    drawSegment(spinePos, rightKnee);
    drawSegment(leftKnee, leftAnkle);
    drawSegment(rightKnee, rightAnkle);

    // Joints
    for (final p in [
      leftKnee,
      rightKnee,
      leftAnkle,
      rightAnkle,
      spinePos,
      leftShoulder,
      rightShoulder
    ]) {
      canvas.drawCircle(p, 4.5, jointPaint);
    }

    // Depth Angle Arc
    final textPainter = TextPainter(
      text: TextSpan(
        text:
            'KNEE: ${jointAngle.toStringAsFixed(0)}° ${jointAngle >= 80 ? '(PARALLEL)' : ''}',
        style: TextStyle(
          color: glowColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy + 62));
  }

  void _drawPushupAvatar(
    Canvas canvas,
    double cx,
    double cy,
    Paint bonePaint,
    Paint shadowPaint,
    Paint jointPaint,
    Color glowColor,
  ) {
    final descent = (jointAngle / 90.0).clamp(0.0, 1.0) * 25.0;

    final headPos = Offset(cx - 50, cy - 20 + descent);
    final chestPos = Offset(cx - 30, cy - 10 + descent);
    final hipsPos = Offset(cx + 10, cy - 6 + (descent * 0.7));
    final feetPos = Offset(cx + 55, cy + 10);

    final handPos = Offset(cx - 30, cy + 15);
    final elbowPos =
        Offset(cx - 40 - (descent * 0.3), cy - 2 + (descent * 0.4));

    void drawSegment(Offset a, Offset b) {
      canvas.drawLine(a, b, shadowPaint);
      canvas.drawLine(a, b, bonePaint);
    }

    // Spine plank line
    drawSegment(headPos, chestPos);
    drawSegment(chestPos, hipsPos);
    drawSegment(hipsPos, feetPos);

    // Arm pushup mechanics
    drawSegment(chestPos, elbowPos);
    drawSegment(elbowPos, handPos);

    canvas.drawCircle(headPos, 8, jointPaint);
    for (final p in [chestPos, hipsPos, feetPos, elbowPos, handPos]) {
      canvas.drawCircle(p, 4, jointPaint);
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'SPINE ALIGNMENT: ${formQuality.toStringAsFixed(0)}%',
        style: TextStyle(
          color: glowColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy + 45));
  }

  void _drawStandingAvatar(
    Canvas canvas,
    double cx,
    double cy,
    Paint bonePaint,
    Paint shadowPaint,
    Paint jointPaint,
    Color glowColor,
  ) {
    // Dynamic curl or standing movement
    final armCurl = (jointAngle / 120.0).clamp(0.0, 1.0);

    final headPos = Offset(cx, cy - 50);
    final neckPos = Offset(cx, cy - 35);
    final spinePos = Offset(cx, cy);

    final leftHand = Offset(cx - 25, cy - (armCurl * 30.0));
    final rightHand = Offset(cx + 25, cy - (armCurl * 30.0));

    void drawSegment(Offset a, Offset b) {
      canvas.drawLine(a, b, shadowPaint);
      canvas.drawLine(a, b, bonePaint);
    }

    drawSegment(headPos, neckPos);
    drawSegment(neckPos, spinePos);
    drawSegment(neckPos, leftHand);
    drawSegment(neckPos, rightHand);
    drawSegment(spinePos, Offset(cx - 20, cy + 50));
    drawSegment(spinePos, Offset(cx + 20, cy + 50));

    canvas.drawCircle(headPos, 9, jointPaint);
    for (final p in [
      neckPos,
      spinePos,
      leftHand,
      rightHand,
      Offset(cx - 20, cy + 50),
      Offset(cx + 20, cy + 50)
    ]) {
      canvas.drawCircle(p, 4.5, jointPaint);
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'JOINT FLEX: ${jointAngle.toStringAsFixed(0)}°',
        style: TextStyle(
          color: glowColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy + 60));
  }

  @override
  bool shouldRepaint(covariant BiomechanicalAvatarPainter oldDelegate) =>
      oldDelegate.pitch != pitch ||
      oldDelegate.roll != roll ||
      oldDelegate.jointAngle != jointAngle ||
      oldDelegate.formQuality != formQuality;
}
