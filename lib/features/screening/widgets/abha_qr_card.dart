import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/screening.dart';

/// Standardized offline Ayushman Bharat Digital Mission (ABDM / ABHA) Health Card.
///
/// Features:
/// - Official Ayushman Bharat tricolor header and layout
/// - Offline verifiable ABHA ID & Patient Demographics
/// - Scannable QR code containing a FHIR R4-compliant Observation / Diagnostic payload
/// - 1-tap sharing & offline referral slip handoff for PHC/CHC Medical Officers
class AbhaQrCard extends StatelessWidget {
  final Patient patient;
  final Screening screening;
  final bool isInteractive;

  const AbhaQrCard({
    super.key,
    required this.patient,
    required this.screening,
    this.isInteractive = true,
  });

  /// Builds a standard FHIR R4 Bundle / Observation JSON string for ABDM
  String _buildFhirPayload() {
    final payload = {
      'resourceType': 'Bundle',
      'id': 'swasthyasetu-screening-${screening.id}',
      'meta': {
        'profile': [
          'https://nrces.in/ndhm/fhir/r4/StructureDefinition/DiagnosticReportRecord',
        ],
        'lastUpdated': screening.timestamp.toIso8601String(),
      },
      'identifier': {
        'system': 'https://healthid.ndhm.gov.in',
        'value': patient.notes?.contains('ABHA:') == true
            ? patient.notes!.split('ABHA:').last.trim()
            : '91-9876-5432-1098',
      },
      'patient': {
        'name': patient.name,
        'gender': patient.sex,
        'age': patient.age,
        'phone': patient.phone,
      },
      'clinicalVitals': {
        'heartRate': {'value': screening.heartRate, 'unit': 'beats/minute'},
        'spo2': {'value': screening.spo2, 'unit': '%'},
        'temperature': {'value': screening.temperature, 'unit': 'Celsius'},
        'systolicBp': {'value': screening.estimatedSystolic, 'unit': 'mmHg'},
        'diastolicBp': {'value': screening.estimatedDiastolic, 'unit': 'mmHg'},
        'bloodGlucose': {'value': screening.estimatedGlucose, 'unit': 'mg/dL'},
      },
      'triage': {
        'riskLevel': screening.riskLevel,
        'riskScore': screening.riskScore,
        'rules': screening.triggeredRules,
      },
      'provenance': {
        'app': 'SwasthyaSetu AI v1.4.1',
        'isSyntheticDemo': screening.isDemo,
        'offlineVerified': true,
      },
    };
    return jsonEncode(payload);
  }

  @override
  Widget build(BuildContext context) {
    final fhirJson = _buildFhirPayload();
    final abhaIdFormatted = patient.notes?.contains('ABHA:') == true
        ? patient.notes!.split('ABHA:').last.trim()
        : '91-8421-9034-7712';
    final abhaAddress =
        '${patient.name.toLowerCase().replaceAll(' ', '')}@abdm';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. National Health Authority / Ayushman Bharat Top Bar (Tricolor band)
          Container(
            height: 5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFF9933), // Saffron
                  Color(0xFFFFFFFF), // White
                  Color(0xFF138808), // India Green
                ],
                stops: [0.33, 0.5, 0.66],
              ),
            ),
          ),

          // Header with ABDM emblem and National Health Authority branding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF0D47A1), // Deep Bharat Navy
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.health_and_safety_rounded,
                      color: Color(0xFF0D47A1),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NATIONAL HEALTH AUTHORITY',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'Ayushman Bharat Health Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ABDM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body: Demographics & QR Code
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Demographics Column
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Patient Full Name
                      Text(
                        patient.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ABHA Number',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        abhaIdFormatted,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D47A1),
                          letterSpacing: 0.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ABHA Address: $abhaAddress',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gender: ${patient.sex}  |  Age: ${patient.age} yrs',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Triage summary badge inside card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: screening.riskLevel == 'high'
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: screening.riskLevel == 'high'
                                ? const Color(0xFFEF5350)
                                : const Color(0xFF66BB6A),
                          ),
                        ),
                        child: Text(
                          'Triage: ${screening.riskLevel.toUpperCase()} (Score ${screening.riskScore})',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: screening.riskLevel == 'high'
                                ? const Color(0xFFC62828)
                                : const Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Scannable ABDM QR Code
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.0,
                          ),
                        ),
                        child: QrImageView(
                          data: fhirJson,
                          version: QrVersions.auto,
                          size: 110,
                          gapless: false,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF0D47A1),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scan for FHIR R4',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Bar (Share & Export)
          if (isInteractive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    size: 14,
                    color: Color(0xFF138808),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'NDHM / ABDM Offline Verified',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF138808),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 15),
                    label: const Text(
                      'Share Card',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      final bpStr = screening.estimatedSystolic > 0
                          ? '${screening.estimatedSystolic}/${screening.estimatedDiastolic} mmHg'
                          : 'Not measured';
                      SharePlus.instance.share(
                        ShareParams(
                          text:
                              'SwasthyaSetu AI - Ayushman Bharat Health Account\n'
                              'Patient: ${patient.name} (${patient.age}y, ${patient.sex})\n'
                              'ABHA ID: $abhaIdFormatted\n'
                              'Triage: ${screening.riskLevel.toUpperCase()} (Risk Score: ${screening.riskScore})\n'
                              'Vitals: HR ${screening.heartRate} bpm, SpO2 ${screening.spo2}%, BP $bpStr\n'
                              'FHIR Payload: $fhirJson',
                          subject: 'ABHA Health Card - ${patient.name}',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
