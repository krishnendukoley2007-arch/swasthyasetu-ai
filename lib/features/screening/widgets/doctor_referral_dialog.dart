import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:swasthyasetu_ai/core/services/pdf_clinical_report_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/screening.dart';
import 'package:swasthyasetu_ai/domain/models/triage_result.dart';
import 'package:swasthyasetu_ai/features/screening/widgets/abha_qr_card.dart';

/// Clinical Doctor Referral Slip Dialog.
///
/// Generates an instant, standardized 1-page Community Health Centre (CHC) /
/// Primary Health Centre (PHC) Medical Referral Slip that can be reviewed,
/// copied, or shared via WhatsApp/SMS to attending medical officers.
class DoctorReferralDialog extends StatelessWidget {
  final TriageResult triageResult;
  final Patient? patient;
  final String? screeningId;

  const DoctorReferralDialog({
    super.key,
    required this.triageResult,
    this.patient,
    this.screeningId,
  });

  static Future<void> show(
    BuildContext context, {
    required TriageResult triageResult,
    Patient? patient,
    String? screeningId,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => DoctorReferralDialog(
        triageResult: triageResult,
        patient: patient,
        screeningId: screeningId,
      ),
    );
  }

  String _formatReferralSlipText() {
    final now = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final vitals = triageResult.vitals;
    final patientName = patient?.name ?? 'Walk-In Patient';
    final ageSex = patient != null ? '${patient!.age}y / ${patient!.sex}' : 'Adult';
    final location = patient?.location ?? 'Primary Care Village Post';
    final refId = screeningId ?? 'SCR-${DateTime.now().millisecondsSinceEpoch % 1000000}';

    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('SWASTHYASETU AI - CLINICAL REFERRAL SLIP');
    buffer.writeln('Primary Health Centre / CHC Referral');
    buffer.writeln('========================================');
    buffer.writeln('Date & Time: $now');
    buffer.writeln('Referral ID: $refId');
    buffer.writeln('Patient: $patientName ($ageSex)');
    buffer.writeln('Location: $location');
    buffer.writeln('----------------------------------------');
    buffer.writeln('TRIAGE STATUS: ${triageResult.level.toUpperCase()} ALERT');
    buffer.writeln('Clinical Risk Score: ${triageResult.score}/100');
    buffer.writeln('Action: ${triageResult.recommendedAction}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('MEASURED VITALS:');
    buffer.writeln('• Heart Rate: ${vitals['heart_rate'] ?? '—'} BPM');
    buffer.writeln('• SpO2: ${vitals['spo2'] ?? '—'}%');
    buffer.writeln('• Temperature: ${vitals['temperature'] ?? '—'} °C');
    if (vitals['glucose'] != null) {
      buffer.writeln('• Blood Glucose: ${vitals['glucose']} mg/dL');
    }
    if (vitals['systolic'] != null && vitals['diastolic'] != null) {
      buffer.writeln('• Est. Blood Pressure: ${vitals['systolic']}/${vitals['diastolic']} mmHg');
    }
    if (vitals['ecg_classification'] != null) {
      buffer.writeln('• ECG Rhythm: ${vitals['ecg_classification']}');
    }
    buffer.writeln('----------------------------------------');
    if (triageResult.symptoms.isNotEmpty) {
      buffer.writeln('REPORTED SYMPTOMS:');
      for (final s in triageResult.symptoms) {
        buffer.writeln('• $s');
      }
      buffer.writeln('----------------------------------------');
    }
    if (triageResult.triggeredRules.isNotEmpty) {
      buffer.writeln('TRIGGERED CLINICAL RULES:');
      for (final r in triageResult.triggeredRules) {
        buffer.writeln('• $r');
      }
      buffer.writeln('----------------------------------------');
    }
    buffer.writeln('Note: Screened by Frontline Health Worker via SwasthyaSetu AI.');
    buffer.writeln('Requires clinical evaluation by Medical Officer.');
    buffer.writeln('========================================');

    return buffer.toString();
  }

  void _shareSlip(BuildContext context) {
    final text = _formatReferralSlipText();
    SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Urgent Medical Referral: ${patient?.name ?? "Patient"} (${triageResult.level.toUpperCase()})',
      ),
    );
  }

  void _copySlip(BuildContext context) {
    final text = _formatReferralSlipText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referral slip copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRed = triageResult.level == 'red';
    final isYellow = triageResult.level == 'yellow';
    final headerColor = isRed
        ? AppTheme.riskRed
        : (isYellow ? AppTheme.riskYellow : AppTheme.riskGreen);

    final vitals = triageResult.vitals;
    final patientName = patient?.name ?? 'Walk-In Patient';
    final ageSex = patient != null ? '${patient!.age} yrs, ${patient!.sex}' : 'Age/Sex Unspecified';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              decoration: BoxDecoration(
                color: headerColor.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
                border: Border(bottom: BorderSide(color: headerColor.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSm),
                    decoration: BoxDecoration(
                      color: headerColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
                  ),
                  const AppSpacing.hmd(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Doctor Referral Slip',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: headerColor,
                          ),
                        ),
                        Text(
                          'Primary Health Centre / CHC Escalation',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Slip Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient & Referral Badge
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patientName,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ageSex,
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                                if (patient?.location != null && patient!.location!.isNotEmpty)
                                  Text(
                                    patient!.location!,
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: headerColor,
                              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Text(
                              '${triageResult.level.toUpperCase()} (${triageResult.score})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const AppSpacing.vmd(),

                    // Action headline
                    Text(
                      'Clinical Recommendation',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      triageResult.recommendedAction,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),

                    const AppSpacing.vmd(),
                    const Divider(),
                    const AppSpacing.vsm(),

                    // Measured vitals grid
                    Text(
                      'Recorded Vitals',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _vitalChip(theme, 'HR', '${vitals['heart_rate'] ?? '—'} BPM', Icons.favorite_rounded),
                        _vitalChip(theme, 'SpO2', '${vitals['spo2'] ?? '—'}%', Icons.air_rounded),
                        _vitalChip(theme, 'Temp', '${vitals['temperature'] ?? '—'}°C', Icons.thermostat_rounded),
                        if (vitals['glucose'] != null)
                          _vitalChip(theme, 'Glucose', '${vitals['glucose']} mg/dL', Icons.water_drop_rounded),
                        if (vitals['systolic'] != null && vitals['diastolic'] != null)
                          _vitalChip(theme, 'BP', '${vitals['systolic']}/${vitals['diastolic']} mmHg', Icons.speed_rounded),
                        if (vitals['ecg_classification'] != null)
                          _vitalChip(theme, 'ECG', '${vitals['ecg_classification']}', Icons.monitor_heart_rounded),
                      ],
                    ),

                    const AppSpacing.vmd(),

                    // Triggered rules
                    if (triageResult.triggeredRules.isNotEmpty) ...[
                      Text(
                        'Clinical Findings & Red Flags',
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 6),
                      ...triageResult.triggeredRules.map(
                        (rule) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 16, color: headerColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  rule,
                                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Clinical export actions: PDF report & ABHA QR card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('PDF Report', style: TextStyle(fontSize: 12)),
                      onPressed: () => _exportPdf(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                      label: const Text('ABHA QR Card', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showAbhaQr(context),
                    ),
                  ),
                ],
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusXl)),
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                    onPressed: () => _copySlip(context),
                  ),
                  const AppSpacing.hsm(),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: headerColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share to Doctor / CHC'),
                      onPressed: () => _shareSlip(context),
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

  Screening _getScreening() {
    final v = triageResult.vitals;
    return Screening(
      id: screeningId ?? const Uuid().v4(),
      patientId: patient?.id ?? 'walkin',
      deviceId: 'DEMO-ESP32-01',
      timestamp: DateTime.now(),
      heartRate: (v['heart_rate'] as num?)?.toInt() ?? 75,
      spo2: (v['spo2'] as num?)?.toInt() ?? 98,
      temperature: (v['temperature'] as num?)?.toDouble() ?? 37.0,
      estimatedGlucose: (v['glucose'] as num?)?.toInt() ?? 0,
      estimatedSystolic: (v['systolic'] as num?)?.toInt() ?? 0,
      estimatedDiastolic: (v['diastolic'] as num?)?.toInt() ?? 0,
      riskScore: triageResult.score,
      riskLevel: triageResult.level,
      triggeredRules: triageResult.triggeredRules,
      symptoms: triageResult.symptoms,
      isDemo: true,
    );
  }

  Patient _getPatient() {
    return patient ??
        Patient(
          id: 'walkin',
          name: 'Walk-In Patient',
          age: 45,
          sex: 'Female',
          phone: null,
          location: 'Primary Health Post',
          notes: 'ABHA: 91-8421-9034-7712',
          createdAt: DateTime.now(),
        );
  }

  Future<void> _exportPdf(BuildContext context) async {
    try {
      await PdfClinicalReportService.exportAndShareReport(
        patient: _getPatient(),
        screening: _getScreening(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  void _showAbhaQr(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AbhaQrCard(
            patient: _getPatient(),
            screening: _getScreening(),
          ),
        ),
      ),
    );
  }

  Widget _vitalChip(ThemeData theme, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
