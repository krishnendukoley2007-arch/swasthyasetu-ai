import 'package:flutter/foundation.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';

@immutable
class VernacularGuidance {
  final String languageCode; // 'hi', 'bn', 'en'
  final String languageName; // 'हिन्दी', 'বাংলা', 'English'
  final String headline;
  final String spokenText;
  final String immediateAction;
  final List<String> dangerSigns;

  const VernacularGuidance({
    required this.languageCode,
    required this.languageName,
    required this.headline,
    required this.spokenText,
    required this.immediateAction,
    required this.dangerSigns,
  });
}

/// ASHA Vernacular Spoken Audio & Clinical Guidance Service.
///
/// Provides frontline health workers (ASHAs) with auditable, highly structured
/// spoken clinical guidance in Hindi, Bengali, and English, specifically
/// calibrated for rural Indian primary care and emergency escalation.
class VernacularGuidanceService {
  /// Generates vernacular guidance across supported Indian languages.
  static Map<String, VernacularGuidance> generateAll({
    required TriageAssessment assessment,
    String? patientName,
  }) {
    return {
      'hi': getGuidance(assessment: assessment, languageCode: 'hi', patientName: patientName),
      'bn': getGuidance(assessment: assessment, languageCode: 'bn', patientName: patientName),
      'en': getGuidance(assessment: assessment, languageCode: 'en', patientName: patientName),
    };
  }

  static VernacularGuidance getGuidance({
    required TriageAssessment assessment,
    required String languageCode,
    String? patientName,
  }) {
    final name = (patientName != null && patientName.trim().isNotEmpty)
        ? patientName.trim()
        : null;

    final band = assessment.band;
    final s = assessment.sample;

    return switch (languageCode) {
      'hi' => _generateHindi(band, s, assessment, name),
      'bn' => _generateBengali(band, s, assessment, name),
      _ => _generateEnglish(band, s, assessment, name),
    };
  }

  static VernacularGuidance _generateHindi(
    RiskBand band,
    HealthSample s,
    TriageAssessment a,
    String? name,
  ) {
    final who = name ?? 'रोगी';

    if (band == RiskBand.red) {
      final reasons = <String>[];
      if (s.spo2Percent > 0 && s.spo2Percent < 90) {
        reasons.add('ऑक्सीजन स्तर ${s.spo2Percent}% अत्यंत कम है');
      }
      if (s.estimatedGlucose > 0 && s.estimatedGlucose < 70) {
        reasons.add('रक्त शर्करा ${s.estimatedGlucose} mg/dL बहुत कम है');
      } else if (s.estimatedGlucose >= 250) {
        reasons.add('रक्त शर्करा ${s.estimatedGlucose} mg/dL अत्यधिक अधिक है');
      }
      if (s.temperatureC >= 39.5) {
        reasons.add('तापमान ${s.temperatureC.toStringAsFixed(1)}°C गंभीर रूप से अधिक है');
      }
      if (s.heartRateBpm > 120 || (s.heartRateBpm > 0 && s.heartRateBpm < 45)) {
        reasons.add('हृदय गति ${s.heartRateBpm} प्रति मिनट असामान्य है');
      }

      final reasonText = reasons.isNotEmpty ? reasons.join(', ') : 'गंभीर खतरे के लक्षण मिले हैं';

      return VernacularGuidance(
        languageCode: 'hi',
        languageName: 'हिन्दी',
        headline: 'आपातकालीन चेतावनी: तत्काल अस्पताल ले जाएं (लाल श्रेणी)',
        spokenText: 'सतर्कता: $who में $reasonText। कृपया तुरंत नजदीकी सामुदायिक स्वास्थ्य केंद्र या अस्पताल में रेफर करें।',
        immediateAction: 'मरीज को स्थिर रखें। यदि सांस लेने में तकलीफ हो तो सीधा बैठाएं। तुरंत 108 एम्बुलेंस या वाहन की व्यवस्था करें।',
        dangerSigns: const [
          'सांस लेने में अत्यधिक कठिनाई या तेज सांसें',
          'होठों या नाखूनों का नीला पड़ना',
          'बेहोशी या अत्यधिक सुस्ती',
          'छाती में दर्द या असहनीय बेचैनी',
        ],
      );
    }

    if (band == RiskBand.yellow) {
      return VernacularGuidance(
        languageCode: 'hi',
        languageName: 'हिन्दी',
        headline: 'सावधानी: 24 घंटे में डॉक्टर को दिखाएं (पीली श्रेणी)',
        spokenText: 'ध्यान दें: $who की जांच में कुछ आंकड़े असामान्य पाए गए हैं (स्कोर ${a.score}/100)। चौबीस घंटे के भीतर नजदीकी स्वास्थ्य केंद्र में डॉक्टर से परामर्श लें।',
        immediateAction: 'रोगी को आराम कराएं। पर्याप्त पानी और तरल पदार्थ दें। लक्षणों के बिगड़ने पर तुरंत अस्पताल ले जाएं।',
        dangerSigns: const [
          'बुखार का लगातार बढ़ना',
          'उल्टी होना और दवा न पचना',
          'चक्कर आना या कमजोरी',
        ],
      );
    }

    return VernacularGuidance(
      languageCode: 'hi',
      languageName: 'हिन्दी',
      headline: 'सामान्य स्थिति: कोई तत्काल खतरा नहीं (हरी श्रेणी)',
      spokenText: '$who के सभी प्राथमिक महत्वपूर्ण लक्षण (हृदय गति, ऑक्सीजन, तापमान) सुरक्षित सीमा में हैं।',
      immediateAction: 'नियमित स्वास्थ्य देखभाल जारी रखें। यदि नए लक्षण दिखाई दें तो दोबारा जांच करें।',
      dangerSigns: const ['अचानक सांस फूलना', 'तीव्र बुखार'],
    );
  }

  static VernacularGuidance _generateBengali(
    RiskBand band,
    HealthSample s,
    TriageAssessment a,
    String? name,
  ) {
    final who = name ?? 'রোগী';

    if (band == RiskBand.red) {
      final reasons = <String>[];
      if (s.spo2Percent > 0 && s.spo2Percent < 90) {
        reasons.add('অক্সিজেনের মাত্রা ${s.spo2Percent}% বিপদজনকভাবে কম');
      }
      if (s.estimatedGlucose > 0 && s.estimatedGlucose < 70) {
        reasons.add('রক্তের শর্করা ${s.estimatedGlucose} mg/dL খুব কম');
      } else if (s.estimatedGlucose >= 250) {
        reasons.add('রক্তের শর্করা ${s.estimatedGlucose} mg/dL অতিরিক্ত বেশি');
      }
      if (s.temperatureC >= 39.5) {
        reasons.add('শরীরের তাপমাত্রা ${s.temperatureC.toStringAsFixed(1)}°C অতি উচ্চ');
      }
      if (s.heartRateBpm > 120 || (s.heartRateBpm > 0 && s.heartRateBpm < 45)) {
        reasons.add('হৃদস্পন্দন ${s.heartRateBpm} প্রতি মিনিটে অনিয়মিত');
      }

      final reasonText = reasons.isNotEmpty ? reasons.join(', ') : 'জরুরি বিপদের লক্ষণ পাওয়া গেছে';

      return VernacularGuidance(
        languageCode: 'bn',
        languageName: 'বাংলা',
        headline: 'জরুরি সতর্কতা: অবিলম্বে হাসপাতালে স্থানান্তর করুন (লাল বিভাগ)',
        spokenText: 'সতর্কতা: $who-এর $reasonText। অবিলম্বে নিকটবর্তী স্বাস্থ্যকেন্দ্রে বা হাসপাতালে নিয়ে যান।',
        immediateAction: 'রোগীকে সোজা বসিয়ে রাখুন। দ্রুত অ্যাম্বুলেন্স বা যানবাহনের ব্যবস্থা করুন।',
        dangerSigns: const [
          'শ্বাসকষ্ট বা দ্রুত শ্বাস নেওয়া',
          'ঠোঁট বা নখ নীল হয়ে যাওয়া',
          'অচেতন হয়ে পড়া',
          'বুকে তীব্র ব্যথা',
        ],
      );
    }

    if (band == RiskBand.yellow) {
      return VernacularGuidance(
        languageCode: 'bn',
        languageName: 'বাংলা',
        headline: 'সতর্কতা: ২৪ ঘণ্টার মধ্যে ডাক্তার দেখান (হলুদ বিভাগ)',
        spokenText: 'দৃষ্টি আকর্ষণ: $who-এর কিছু পরিমাপ স্বাভাবিকের চেয়ে বেশি (স্কোর ${a.score}/১০০)। আগামী ২৪ ঘণ্টার মধ্যে ডাক্তারের পরামর্শ নিন।',
        immediateAction: 'রোগীকে বিশ্রাম দিন এবং প্রচুর পরিমাণে তরল খাবার ও জল পান করতে দিন।',
        dangerSigns: const [
          'জ্বর ক্রমাগত বাড়লে',
          'বারবার বমি হলে',
          'শরীর অতিরিক্ত দুর্বল লাগলে',
        ],
      );
    }

    return VernacularGuidance(
      languageCode: 'bn',
      languageName: 'বাংলা',
      headline: 'স্বাভাবিক অবস্থা: আশঙ্কাজনক কিছু নেই (সবুজ বিভাগ)',
      spokenText: '$who-এর প্রাথমিক স্বাস্থ্য মাপকাঠি (অক্সিজেন, হৃদস্পন্দন, তাপমাত্রা) স্বাভাবিক সীমার মধ্যে রয়েছে।',
      immediateAction: 'নিয়মিত স্বাস্থ্যের যত্ন নিন। নতুন উপসর্গ দেখা দিলে পুনরায় স্ক্রিনিং করুন।',
      dangerSigns: const ['হঠাৎ শ্বাসকষ্ট', 'তীব্র জ্বর'],
    );
  }

  static VernacularGuidance _generateEnglish(
    RiskBand band,
    HealthSample s,
    TriageAssessment a,
    String? name,
  ) {
    final who = name ?? 'The patient';

    if (band == RiskBand.red) {
      final reasons = <String>[];
      if (s.spo2Percent > 0 && s.spo2Percent < 90) {
        reasons.add('Oxygen saturation (${s.spo2Percent}%) is critically low');
      }
      if (s.estimatedGlucose > 0 && s.estimatedGlucose < 70) {
        reasons.add('Blood glucose (${s.estimatedGlucose} mg/dL) indicates hypoglycemia');
      } else if (s.estimatedGlucose >= 250) {
        reasons.add('Blood glucose (${s.estimatedGlucose} mg/dL) is critically elevated');
      }
      if (s.temperatureC >= 39.5) {
        reasons.add('Severe fever (${s.temperatureC.toStringAsFixed(1)}°C)');
      }
      if (s.heartRateBpm > 120 || (s.heartRateBpm > 0 && s.heartRateBpm < 45)) {
        reasons.add('Heart rate (${s.heartRateBpm} BPM) is out of safety range');
      }

      final reasonText = reasons.isNotEmpty ? reasons.join(', ') : 'Critical red flag vitals detected';

      return VernacularGuidance(
        languageCode: 'en',
        languageName: 'English',
        headline: 'Emergency Alert: Immediate Referral Required (Red Band)',
        spokenText: 'Warning: $who exhibits danger signs: $reasonText. Immediate transport to Community Health Centre or Hospital is required.',
        immediateAction: 'Keep patient seated upright if breathless. Arrange immediate emergency medical transport. Do not leave patient unattended.',
        dangerSigns: const [
          'Severe breathing difficulty or stridor',
          'Cyanosis (blue lips or nail beds)',
          'Altered mental state or unresponsiveness',
          'Acute chest pain or pressure',
        ],
      );
    }

    if (band == RiskBand.yellow) {
      return VernacularGuidance(
        languageCode: 'en',
        languageName: 'English',
        headline: 'Caution: Medical Review within 24 Hours (Yellow Band)',
        spokenText: 'Notice: $who has abnormal screening findings with a risk score of ${a.score}/100. Schedule a medical examination at the local clinic within 24 hours.',
        immediateAction: 'Ensure patient rests and remains well-hydrated. Re-screen immediately if danger signs develop.',
        dangerSigns: const [
          'Persistent or worsening fever',
          'Inability to tolerate oral fluids',
          'Progressive weakness or dizziness',
        ],
      );
    }

    return VernacularGuidance(
      languageCode: 'en',
      languageName: 'English',
      headline: 'Normal Screening: Within Safe Range (Green Band)',
      spokenText: 'All primary vitals for $who are within standard screening ranges.',
      immediateAction: 'Maintain routine health monitoring. Re-screen if symptoms arise.',
      dangerSigns: const ['Sudden breathlessness', 'High spiking fever'],
    );
  }
}
