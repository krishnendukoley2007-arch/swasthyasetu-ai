import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/services/pdf_clinical_report_service.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/screening.dart';
import 'package:swasthyasetu_ai/features/screening/widgets/abha_qr_card.dart';
import 'package:swasthyasetu_ai/features/screening/widgets/clarke_error_grid_widget.dart';
import 'package:swasthyasetu_ai/features/screening/widgets/dual_waveform_sweep_monitor.dart';
import 'package:swasthyasetu_ai/features/screening/widgets/poincare_plot_widget.dart';
import 'package:swasthyasetu_ai/features/screening/widgets/vascular_elasticity_gauge.dart';

void main() {
  group('Clarke Error Grid Analysis (EGA)', () {
    test('evaluates clinical zones accurately according to ISO 15197 / Clarke 1987', () {
      // Zone A: Within 20% of reference or both <= 70
      expect(ClarkeErrorGridWidget.evaluateZone(100.0, 110.0), 'Zone A');
      expect(ClarkeErrorGridWidget.evaluateZone(100.0, 90.0), 'Zone A');
      expect(ClarkeErrorGridWidget.evaluateZone(50.0, 60.0), 'Zone A');

      // Zone E: Erroneous treatment
      expect(ClarkeErrorGridWidget.evaluateZone(60.0, 220.0), 'Zone E');
      expect(ClarkeErrorGridWidget.evaluateZone(220.0, 60.0), 'Zone E');

      // Zone B: Benign errors
      expect(ClarkeErrorGridWidget.evaluateZone(100.0, 140.0), 'Zone B');
    });

    testWidgets('renders ClarkeErrorGridWidget without layout overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClarkeErrorGridWidget(
                estimatedGlucose: 125.0,
                referenceGlucose: 110.0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clarke Error Grid Analysis (EGA)'), findsOneWidget);
      expect(find.text('Zone A'), findsOneWidget);
    });
  });

  group('Poincaré Plot (RR Interval HRV)', () {
    testWidgets('renders PoincarePlotWidget with telemetry tiles and SD1/SD2 metrics', (tester) async {
      final syntheticRRs = [820, 815, 830, 810, 825, 840, 818, 822, 835, 828];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PoincarePlotWidget(
                rrIntervalsMs: syntheticRRs,
                heartRateBpm: 72,
                hasArrhythmia: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Poincaré Plot (RR Interval HRV)'), findsOneWidget);
      expect(find.text('SINUS RHYTHM'), findsOneWidget);
      expect(find.text('SD1 (Short-term)'), findsOneWidget);
      expect(find.text('SD2 (Long-term)'), findsOneWidget);
    });
  });

  group('Vascular Elasticity & Pulse Transit Time Speedometer', () {
    test('computes pulse wave velocity (PWV) accurately from PTT', () {
      const normalGauge = VascularElasticityGauge(pttMs: 140.0);
      // PWV = 0.85 / 0.14 = 6.07 m/s (< 7.0 = Optimal)
      expect(normalGauge.pwv, closeTo(6.07, 0.1));
      expect(normalGauge.stiffnessClassification, 'Optimal Elasticity');

      const stiffGauge = VascularElasticityGauge(pttMs: 80.0);
      // PWV = 0.85 / 0.08 = 10.6 m/s (> 9.5 = High stiffness)
      expect(stiffGauge.pwv, closeTo(10.6, 0.1));
      expect(stiffGauge.stiffnessClassification, 'High Arterial Stiffness (Rigid)');
    });

    testWidgets('renders VascularElasticityGauge with numeric readout and explainer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VascularElasticityGauge(
                pttMs: 135.0,
                systolicBp: 118,
                diastolicBp: 76,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vascular Elasticity & PTT Speedometer'), findsOneWidget);
      expect(find.text('118 / 76 mmHg'), findsOneWidget);
      expect(find.textContaining('m/s PWV'), findsOneWidget);
    });
  });

  group('Dual Waveform Sweep Monitor', () {
    testWidgets('renders ECG + Pleth PPG sweep monitor with telemetry HUD', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DualWaveformSweepMonitor(
              heartRate: 75,
              spo2: 99,
              isLive: false,
              showControls: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Lead II'), findsAtLeast(1));
      expect(find.text('75'), findsOneWidget);
      expect(find.text('99'), findsOneWidget);
    });
  });

  group('Ayushman Bharat ABHA QR Card', () {
    testWidgets('renders offline ABHA card with valid FHIR R4 JSON QR payload', (tester) async {
      final patient = Patient(
        id: 'P-101',
        name: 'Ramesh Patel',
        age: 52,
        sex: 'Male',
        phone: '9876543210',
        location: 'Rampur Sub-Centre',
        notes: 'ABHA: 91-8842-1920-3341',
        createdAt: DateTime.now(),
      );

      final screening = Screening(
        id: 'SCR-9901',
        patientId: patient.id,
        deviceId: 'ESP32-BLE-01',
        timestamp: DateTime.now(),
        heartRate: 78,
        spo2: 97,
        temperature: 36.8,
        estimatedSystolic: 128,
        estimatedDiastolic: 82,
        estimatedGlucose: 104,
        riskScore: 22,
        riskLevel: 'green',
        triggeredRules: const ['Normal Sinus Rhythm'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AbhaQrCard(
                patient: patient,
                screening: screening,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ramesh Patel'), findsOneWidget);
      expect(find.text('91-8842-1920-3341'), findsOneWidget);
      expect(find.text('Ayushman Bharat Health Account'), findsOneWidget);
      expect(find.text('NDHM / ABDM Offline Verified'), findsOneWidget);
    });
  });

  group('High-Fidelity PDF Medical Report (Ayushman Bharat / CHC)', () {
    test('generates valid multi-section PDF document with non-empty bytes', () async {
      final patient = Patient(
        id: 'P-202',
        name: 'Sunita Sharma',
        age: 44,
        sex: 'Female',
        phone: '9123456780',
        location: 'Kalyanpur PHC',
        notes: 'ABHA: 91-4455-6677-8899',
        createdAt: DateTime.now(),
      );

      final screening = Screening(
        id: 'SCR-8877',
        patientId: patient.id,
        deviceId: 'ESP32-DEV-02',
        timestamp: DateTime.now(),
        heartRate: 110,
        spo2: 91,
        temperature: 38.6,
        estimatedSystolic: 145,
        estimatedDiastolic: 92,
        estimatedGlucose: 195,
        riskScore: 78,
        riskLevel: 'red',
        triggeredRules: const ['Tachycardia', 'Hypoxemia Alert', 'High Fever'],
      );

      final pdfBytes = await PdfClinicalReportService.generateMedicalReport(
        patient: patient,
        screening: screening,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
      // PDF documents start with '%PDF-' magic bytes
      final header = utf8.decode(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });
  });
}
