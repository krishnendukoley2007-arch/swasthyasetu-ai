import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:swasthyasetu_ai/domain/rules/overnight_analysis_engine.dart';

/// Clinical PDF and CSV export service for Overnight Guardian monitoring sessions.
class OvernightReportExporter {
  OvernightReportExporter._();

  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  static Future<void> _ensureFonts() async {
    if (_regularFont != null && _boldFont != null) return;
    try {
      final regularData = await rootBundle.load(
        'assets/fonts/Inter-Regular.ttf',
      );
      final boldData = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
      _regularFont = pw.Font.ttf(regularData);
      _boldFont = pw.Font.ttf(boldData);
    } catch (_) {
      _regularFont = pw.Font.helvetica();
      _boldFont = pw.Font.helveticaBold();
    }
  }

  /// Generates the complete clinical Ayushman Bharat overnight report as PDF bytes.
  static Future<Uint8List> generatePdfReport(
    OvernightSessionReport report, {
    String patientName = 'Anonymous Patient',
    String abhaId = '91-XXXX-XXXX-XXXX',
    String facilityName = 'Primary Health Centre (PHC) Sub-Centre',
  }) async {
    await _ensureFonts();

    final pdfTheme = pw.ThemeData.withFont(
      base: _regularFont!,
      bold: _boldFont!,
    );

    final pdf = pw.Document(
      title: 'Overnight Polysomnography Triage - $patientName',
      author: 'SwasthyaSetu AI',
      theme: pdfTheme,
    );

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final startStr = dateFormat.format(report.startTime);
    final endStr = dateFormat.format(report.endTime);

    final isSevereOdi = report.odiScore >= 15.0;
    final isNonDipper = report.nocturnalDipPercent < 10.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Header (ABDM / NHM Format)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MINISTRY OF HEALTH & FAMILY WELFARE · GOVT OF INDIA',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'AYUSHMAN BHARAT DIGITAL MISSION (ABDM)',
                          style: const pw.TextStyle(
                            color: PdfColors.amber,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Nocturnal Cardiopulmonary Guardian & Sleep Triage Slip',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        if (report.isDemo)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.amber800,
                              borderRadius: pw.BorderRadius.all(
                                pw.Radius.circular(4),
                              ),
                            ),
                            child: pw.Text(
                              'DEMO SIMULATION',
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.green700,
                              borderRadius: pw.BorderRadius.all(
                                pw.Radius.circular(4),
                              ),
                            ),
                            child: pw.Text(
                              'SSAI-SENSE MEASURED',
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          facilityName,
                          style: const pw.TextStyle(
                            color: PdfColors.grey300,
                            fontSize: 7.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // 2. Patient & Session Metadata Card
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Patient: $patientName',
                          style: const pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        pw.Text(
                          'ABHA ID: $abhaId',
                          style: const pw.TextStyle(
                            color: PdfColors.grey700,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Session: $startStr - $endStr',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                        pw.Text(
                          'Monitored Duration: ${report.totalDuration.inHours}h ${report.totalDuration.inMinutes % 60}m (Valid Contact: ${report.validContactDuration.inMinutes}m)',
                          style: const pw.TextStyle(
                            color: PdfColors.blueGrey800,
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // 3. Clinical Biomarkers Grid
              pw.Text(
                'NOCTURNAL CARDIOPULMONARY BIOMARKERS',
                style: const pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    children: [
                      _cell('Biomarker Parameter', isHeader: true),
                      _cell('Measured Value', isHeader: true),
                      _cell('Clinical Reference', isHeader: true),
                      _cell('Triage Assessment', isHeader: true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell('Nocturnal HR Dip'),
                      _cell(
                        '${report.nocturnalDipPercent.toStringAsFixed(1)}% (Baseline ${report.baselineHr} -> Mean ${report.meanSleepHr} BPM)',
                      ),
                      _cell('10% - 20% Dip (Normal Dipper)'),
                      _cell(
                        report.nocturnalDipCategory,
                        color: isNonDipper
                            ? PdfColors.red800
                            : PdfColors.green800,
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell('Oxygen Desaturation Index (ODI)'),
                      _cell(
                        '${report.odiScore.toStringAsFixed(1)} drops/hr (Min SpO2: ${report.lowestSpo2.toStringAsFixed(1)}%)',
                      ),
                      _cell('< 5.0 drops/hour (Normal)'),
                      _cell(
                        report.odiSeverity,
                        color: isSevereOdi
                            ? PdfColors.red800
                            : PdfColors.blue800,
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell('Hypoxia Exposure (<90% SpO2)'),
                      _cell('${report.hypoxiaDurationMinutes} minutes'),
                      _cell('< 5 minutes overnight'),
                      _cell(
                        report.hypoxiaDurationMinutes > 5
                            ? 'Elevated Hypoxic Burden'
                            : 'Optimal',
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell('Heart Rate Extrema'),
                      _cell(
                        'Min: ${report.minHr} BPM · Max: ${report.maxHr} BPM',
                      ),
                      _cell('45 - 90 BPM during sleep'),
                      _cell(
                        report.minHr < 40
                            ? 'Severe Bradycardia Alert'
                            : 'Within Expected Bounds',
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell('Autonomic HRV (SDNN / RMSSD)'),
                      _cell(
                        'SDNN: ${report.sdnn} ms · RMSSD: ${report.rmssd} ms',
                      ),
                      _cell('SDNN > 50 ms · RMSSD > 25 ms'),
                      _cell(
                        report.rmssd >= 25
                            ? 'Normal Vagal Tone'
                            : 'Depressed HRV',
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // 4. Clinical Verdict & Referral Recommendation
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: isSevereOdi || isNonDipper
                      ? PdfColors.amber50
                      : PdfColors.teal50,
                  border: pw.Border.all(
                    color: isSevereOdi || isNonDipper
                        ? PdfColors.amber800
                        : PdfColors.teal800,
                  ),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CLINICAL INTERPRETATION: ${report.sleepRecoveryVerdict.toUpperCase()}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: isSevereOdi || isNonDipper
                            ? PdfColors.amber900
                            : PdfColors.teal900,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      report.triageRecommendation,
                      style: const pw.TextStyle(fontSize: 8.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // 5. Detected Events / Issues Log
              pw.Text(
                'FLAGGED CLINICAL INCIDENTS & ANOMALIES (${report.events.length} Detected)',
                style: const pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 4),
              if (report.events.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'No nocturnal desaturations, severe bradycardia, or arrhythmic pauses detected during this session.',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                )
              else
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey100,
                      ),
                      children: [
                        _cell('Time', isHeader: true),
                        _cell('Classification', isHeader: true),
                        _cell('Severity', isHeader: true),
                        _cell('Clinical Event Details', isHeader: true),
                      ],
                    ),
                    ...report.events.take(8).map((e) {
                      final timeStr = DateFormat(
                        'hh:mm:ss a',
                      ).format(e.timestamp);
                      final sevColor = e.severity == 'critical'
                          ? PdfColors.red800
                          : (e.severity == 'warning'
                                ? PdfColors.amber900
                                : PdfColors.grey800);
                      return pw.TableRow(
                        children: [
                          _cell(timeStr),
                          _cell(e.title),
                          _cell(e.severity.toUpperCase(), color: sevColor),
                          _cell(e.description),
                        ],
                      );
                    }),
                  ],
                ),
              pw.Spacer(),

              // 6. Sign-off & Disclaimer
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Attending Medical Officer / Pulmonologist',
                        style: const pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                      pw.SizedBox(height: 18),
                      pw.Text(
                        'Signature & Reg. No: _______________________',
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'PHC / CHC Health Centre Stamp',
                        style: const pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                      pw.SizedBox(height: 18),
                      pw.Text(
                        'Date: _______________________',
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Ayushman Bharat Digital Mission compliant tele-triage · Screening tool only, does not replace full Level 1 Polysomnography (PSG)',
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Exports the session report as a clinical PDF and opens the system share sheet.
  static Future<void> exportAndSharePdf(
    OvernightSessionReport report, {
    String patientName = 'Patient',
    String abhaId = '91-XXXX-XXXX-XXXX',
    String facilityName = 'Primary Health Centre (PHC) Sub-Centre',
  }) async {
    final pdfBytes = await generatePdfReport(
      report,
      patientName: patientName,
      abhaId: abhaId,
      facilityName: facilityName,
    );

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(report.startTime);
    final sanitizedName = patientName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final filePath =
        '${tempDir.path}/Overnight_Guardian_${sanitizedName}_$timestamp.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        text:
            'Ayushman Bharat Overnight Cardiopulmonary Report for $patientName',
        subject: 'Overnight Guardian Report - $patientName',
      ),
    );
  }

  /// Exports raw session data as CSV and opens the system share sheet.
  static Future<void> exportAndShareCsv(
    OvernightSessionReport report, {
    String patientName = 'Patient',
  }) async {
    final csvContent = report.toCsv();
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(report.startTime);
    final sanitizedName = patientName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final filePath =
        '${tempDir.path}/Overnight_Data_${sanitizedName}_$timestamp.csv';
    final file = File(filePath);
    await file.writeAsString(csvContent, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        text:
            'SwasthyaSetu AI Raw Overnight Screening CSV Data for $patientName',
        subject: 'Overnight Guardian CSV Data - $patientName',
      ),
    );
  }

  static pw.Widget _cell(
    String text, {
    bool isHeader = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 7.5 : 7,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.blueGrey900 : PdfColors.black),
        ),
      ),
    );
  }
}
