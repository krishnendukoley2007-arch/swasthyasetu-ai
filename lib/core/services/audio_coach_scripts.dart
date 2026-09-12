import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';

/// Supported spoken languages for the offline audio coach.
enum AudioCoachLanguage {
  hindi(code: 'hi', ttsLocale: 'hi-IN', displayName: 'हिन्दी'),
  bengali(code: 'bn', ttsLocale: 'bn-IN', displayName: 'বাংলা'),
  english(code: 'en', ttsLocale: 'en-IN', displayName: 'English');

  final String code;
  final String ttsLocale;
  final String displayName;

  const AudioCoachLanguage({
    required this.code,
    required this.ttsLocale,
    required this.displayName,
  });

  static AudioCoachLanguage fromCode(String code) {
    return switch (code.toLowerCase()) {
      'hi' || 'hi-in' => AudioCoachLanguage.hindi,
      'bn' || 'bn-in' => AudioCoachLanguage.bengali,
      _ => AudioCoachLanguage.english,
    };
  }
}

/// Curated, human-like voice scripts in Hindi, Bengali, and English.
///
/// Specifically crafted for illiterate and vulnerable community members in
/// conversational, empathetic, and culturally grounded Indian vernacular.
class AudioCoachScripts {
  const AudioCoachScripts._();

  // ===========================================================================
  // 1. GUIDED BREATHING AUDIO SCRIPTS (Pursed-Lip Metronome)
  // ===========================================================================

  static String breathingSessionStart(AudioCoachLanguage lang) {
    return switch (lang) {
      AudioCoachLanguage.hindi =>
        'आइए, हमारे साथ धीरे-धीरे सांस लीजिए। अपनी रीढ़ सीधी रखें और बिल्कुल शांत हो जाएं।',
      AudioCoachLanguage.bengali =>
        'আসুন, আমাদের সাথে ধীরে ধীরে শ্বাস নিন। শিরদাঁড়া সোজা রেখে শরীর শান্ত রাখুন।',
      AudioCoachLanguage.english =>
        'Let us take slow, gentle breaths together. Keep your back straight and relax your body.',
    };
  }

  static String breathingInhaleCue(AudioCoachLanguage lang) {
    return switch (lang) {
      AudioCoachLanguage.hindi =>
        'नाक से सांस अंदर लीजिए... एक... दो... तीन... चार...',
      AudioCoachLanguage.bengali =>
        'নাক দিয়ে ধীরে শ্বাস নিন... এক... দুই... তিন... চার...',
      AudioCoachLanguage.english =>
        'Gently breathe in through your nose... one, two, three, four...',
    };
  }

  static String breathingExhaleCue(AudioCoachLanguage lang) {
    return switch (lang) {
      AudioCoachLanguage.hindi =>
        'अब होंठ गोल करके, धीरे-धीरे फूंक मारते हुए सांस छोड़िए... एक... दो... तीन... चार... पांच... छह...',
      AudioCoachLanguage.bengali =>
        'এবার ঠোঁট গোল করে, আস্তে আস্তে ফুঁ দিয়ে শ্বাস ছাড়ুন... এক... দুই... तीन... চার... পাঁচ... ছয়...',
      AudioCoachLanguage.english =>
        'Now purse your lips, and gently blow out... one, two, three, four, five, six...',
    };
  }

  static String breathingCompletion(AudioCoachLanguage lang, int cycles) {
    return switch (lang) {
      AudioCoachLanguage.hindi =>
        'बहुत बढ़िया! आपने $cycles चक्र पूरे कर लिए हैं। आपकी सांस और दिल की धड़कन अब अधिक शांत और सामान्य हो गई है।',
      AudioCoachLanguage.bengali =>
        'খুব ভালো! আপনি $cycles টি চক্র সম্পূর্ণ করেছেন। আপনার শ্বাস ও হৃদস্পন্দন এখন আগের চেয়ে শান্ত ও স্বাভাবিক হয়েছে।',
      AudioCoachLanguage.english =>
        'Well done! You completed $cycles breathing cycles. Your lungs and heart rate are feeling calmer and steadier.',
    };
  }

  // ===========================================================================
  // 2. HYDRATION & HEAT STRESS AUDIO SCRIPTS
  // ===========================================================================

  static String hydrationPrompt({
    required AudioCoachLanguage lang,
    bool isHotWeather = false,
    bool isElderly = false,
  }) {
    if (isHotWeather) {
      return switch (lang) {
        AudioCoachLanguage.hindi =>
          'धूप और गर्मी बहुत तेज़ है। तुरंत एक गिलास ठंडा या सादा पानी पी लीजिए। धूप से हटकर दो मिनट छांव में आराम कीजिए।',
        AudioCoachLanguage.bengali =>
          'রোদের তেজ খুব বেশি। এখনই এক গ্লাস জল খেয়ে নিন। রোদ থেকে সরে এসে কিছুক্ষণ ছায়ায় বিশ্রাম নিন।',
        AudioCoachLanguage.english =>
          'The heat is very strong outside. Please drink a full glass of water and rest in the shade for a couple of minutes.',
      };
    }

    if (isElderly) {
      return switch (lang) {
        AudioCoachLanguage.hindi =>
          'चाची या दादाजी, उम्र के साथ प्यास का अहसास कम होता है। थोड़ा पानी या नींबू पानी पी लीजिए, ताकि शरीर में ताकत बनी रहे।',
        AudioCoachLanguage.bengali =>
          'দাদু বা দিদিমা, পিপাসা না পেলেও একটু জল বা লেবুর শরবত খেয়ে নিন। এতে শরীরে বল বজায় থাকবে।',
        AudioCoachLanguage.english =>
          'Remember to take a few sips of water even if you do not feel thirsty. Staying hydrated keeps your body strong.',
      };
    }

    return switch (lang) {
      AudioCoachLanguage.hindi =>
        'थोड़ा सा पानी पीने का समय हो गया है। एक-दो घूंट पानी आपके शरीर को तरोताज़ा और स्वस्थ रखेगा।',
      AudioCoachLanguage.bengali =>
        'একটু জল খেয়ে নেওয়ার সময় হয়েছে। এক-দু চুমুক জল আপনার শরীর সতেজ ও সুস্থ রাখবে।',
      AudioCoachLanguage.english =>
        'Time to take a refreshing drink of clean water. Staying hydrated protects your health and stamina.',
    };
  }

  // ===========================================================================
  // 3. "THEN WHAT IS MY SITUATION?" (HEALTH ASSESSMENT AUDIO SCRIPT)
  // ===========================================================================

  /// Generates a warm, empathetic, human-like voice explanation of the patient's
  /// clinical situation that directly answers: "मेरी स्थिति क्या है?"
  static String whatIsMySituation({
    required AudioCoachLanguage lang,
    required RiskBand band,
    required HealthSample sample,
    String? patientName,
    int? score,
    List<String> symptoms = const [],
    double? dehydrationScore,
    String? trajectorySummary,
  }) {
    final name = (patientName != null && patientName.trim().isNotEmpty)
        ? patientName.trim()
        : null;

    return switch (lang) {
      AudioCoachLanguage.hindi => _buildHindiSituation(
        band: band,
        sample: sample,
        name: name,
        score: score,
        symptoms: symptoms,
        dehydrationScore: dehydrationScore,
        trajectorySummary: trajectorySummary,
      ),
      AudioCoachLanguage.bengali => _buildBengaliSituation(
        band: band,
        sample: sample,
        name: name,
        score: score,
        symptoms: symptoms,
        dehydrationScore: dehydrationScore,
        trajectorySummary: trajectorySummary,
      ),
      AudioCoachLanguage.english => _buildEnglishSituation(
        band: band,
        sample: sample,
        name: name,
        score: score,
        symptoms: symptoms,
        dehydrationScore: dehydrationScore,
        trajectorySummary: trajectorySummary,
      ),
    };
  }

  static String _buildHindiSituation({
    required RiskBand band,
    required HealthSample sample,
    String? name,
    int? score,
    List<String> symptoms = const [],
    double? dehydrationScore,
    String? trajectorySummary,
  }) {
    final greeting = name != null
        ? 'नमस्ते $name जी, मैं आपका स्वास्थ्य साथी बोल रहा हूँ।'
        : 'नमस्ते, मैं आपका स्वास्थ्य साथी बोल रहा हूँ।';

    final hr = sample.heartRateBpm;
    final spo2 = sample.spo2Percent;
    final temp = sample.temperatureC;

    final vitalsSpeech = StringBuffer();
    if (hr > 0) {
      if (hr < 55) {
        vitalsSpeech.write(' आपकी दिल की धड़कन $hr है, जो थोड़ी धीमी है।');
      } else if (hr > 100) {
        vitalsSpeech.write(
          ' आपकी दिल की धड़कन $hr है, जो थोड़ी तेज चल रही है।',
        );
      } else {
        vitalsSpeech.write(
          ' आपकी दिल की धड़कन $hr प्रति मिनट है, जो बिल्कुल सामान्य है।',
        );
      }
    }

    if (spo2 > 0) {
      if (spo2 < 92) {
        vitalsSpeech.write(
          ' आपके शरीर में ऑक्सीजन की मात्रा $spo2 प्रतिशत है, जो कम है।',
        );
      } else {
        vitalsSpeech.write(
          ' ऑक्सीजन का स्तर $spo2 प्रतिशत है, जो बहुत अच्छा है।',
        );
      }
    }

    if (temp > 37.8) {
      vitalsSpeech.write(' शरीर का तापमान थोड़ा गर्म है, बुखार के लक्षण हैं।');
    }

    if (dehydrationScore != null && dehydrationScore >= 3.0) {
      vitalsSpeech.write(
        ' शरीर में पानी की कमी यानी डिहाइड्रेशन के संकेत दिखाई दे रहे हैं।',
      );
    }

    if (band == RiskBand.red) {
      return '$greeting घबराइए नहीं, शांत रहिए। आपकी जांच में कुछ आंकड़े चिंताजनक हैं।$vitalsSpeech '
          'कृपया तुरंत आराम से बैठ जाएं। यदि सांस फूल रही है तो तकिया लगाकर सीधे बैठिए। '
          'अपने परिवार या साथी से कहें कि तुरंत नज़दीकी अस्पताल या 108 नंबर पर एम्बुलेंस को फोन करें। '
          'हम आपके साथ हैं, हिम्मत रखिए।';
    }

    if (band == RiskBand.yellow) {
      return '$greeting आपकी जांच पूरी हो गई है।$vitalsSpeech '
          'कुछ चीज़ों पर ध्यान देने की ज़रूरत है। आज भारी काम न करें और भरपूर मात्रा में पानी व ओआरएस का घोल पिएं। '
          'अगले चौबीस घंटे के भीतर अपने नज़दीकी स्वास्थ्य केंद्र या डॉक्टर को ज़रूर दिखा लें। अपना ध्यान रखें!';
    }

    return '$greeting आपकी पूरी जांच बहुत अच्छी आई है।$vitalsSpeech '
        'कोई खतरे की बात नहीं है, सब कुछ सुरक्षित और सामान्य है। '
        'ताज़ा पानी पीते रहिए, अच्छा खाना खाइए और स्वस्थ रहिए।';
  }

  static String _buildBengaliSituation({
    required RiskBand band,
    required HealthSample sample,
    String? name,
    int? score,
    List<String> symptoms = const [],
    double? dehydrationScore,
    String? trajectorySummary,
  }) {
    final greeting = name != null
        ? 'নমস্কার $name বাবু, আমি আপনার স্বাস্থ্য সাথী।'
        : 'নমস্কার, আমি আপনার স্বাস্থ্য সাথী।';

    final hr = sample.heartRateBpm;
    final spo2 = sample.spo2Percent;
    final temp = sample.temperatureC;

    final vitalsSpeech = StringBuffer();
    if (hr > 0) {
      if (hr < 55) {
        vitalsSpeech.write(' আপনার হৃদস্পন্দন মিনিটে $hr, যা কিছুটা ধীর।');
      } else if (hr > 100) {
        vitalsSpeech.write(
          ' আপনার হৃদস্পন্দন মিনিটে $hr, যা কিছুটা দ্রুত চলছে।',
        );
      } else {
        vitalsSpeech.write(' আপনার হৃদস্পন্দন মিনিটে $hr, যা একদম স্বাভাবিক।');
      }
    }

    if (spo2 > 0) {
      if (spo2 < 92) {
        vitalsSpeech.write(
          ' শরীরে অক্সিজেনের মাত্রা $spo2 শতাংশ, যা স্বাভাবিকের চেয়ে কম।',
        );
      } else {
        vitalsSpeech.write(
          ' অক্সিজেনের মাত্রা $spo2 শতাংশ, যা খুব ভালো ও নিরাপদ।',
        );
      }
    }

    if (temp > 37.8) {
      vitalsSpeech.write(
        ' শরীরের তাপমাত্রা বেশি, মৃদু বা তীব্র জ্বরের লক্ষণ রয়েছে।',
      );
    }

    if (dehydrationScore != null && dehydrationScore >= 3.0) {
      vitalsSpeech.write(
        ' শরীরে জলের ঘাটতি বা ডিহাইড্রেশনের লক্ষণ দেখা যাচ্ছে।',
      );
    }

    if (band == RiskBand.red) {
      return '$greeting ভয় পাবেন না, শান্ত থাকুন। আপনার স্বাস্থ্য পরীক্ষায় কিছু জরুরি লক্ষণ পাওয়া গেছে।$vitalsSpeech '
          'অনুগ্রহ করে সোজা হয়ে বসে বিশ্রাম নিন। শ্বাসকষ্ট হলে মাথা উঁচু রাখুন। '
          'পরিবারের কাউকে বলুন অবিলম্বে নিকটবর্তী হাসপাতাল বা ১০৮ নম্বরে অ্যাম্বুলেন্সে যোগাযোগ করতে। '
          'মন শক্ত রাখুন, আমরা আপনার পাশেই আছি।';
    }

    if (band == RiskBand.yellow) {
      return '$greeting আপনার স্বাস্থ্য পরীক্ষা সম্পন্ন হয়েছে।$vitalsSpeech '
          'কিছু বিষয়ে একটু নজর দেওয়া প্রয়োজন। বেশি দৌড়ঝাঁপ করবেন না, প্রচুর জল ও ওআরএস পান করুন। '
          'আগামী চব্বিশ ঘণ্টার মধ্যে আশা দিদি অথবা নিকটবর্তী স্বাস্থ্যকেন্দ্রে গিয়ে ডাক্তার দেখিয়ে নেবেন। ভালো থাকুন!';
    }

    return '$greeting খুব আনন্দের খবর! আপনার স্বাস্থ্য পরীক্ষার ফলাফল খুবই ভালো এসেছে।$vitalsSpeech '
        'ভয়ের কোনো কারণ নেই, সবকিছু একদম নিরাপদ ও স্বাভাবিক রয়েছে। '
        'পরিষ্কার জল পান করুন, পুষ্টিকর খাবার খান এবং সুস্থ থাকুন।';
  }

  static String _buildEnglishSituation({
    required RiskBand band,
    required HealthSample sample,
    String? name,
    int? score,
    List<String> symptoms = const [],
    double? dehydrationScore,
    String? trajectorySummary,
  }) {
    final greeting = name != null
        ? 'Hello $name, this is your SwasthyaSetu health companion.'
        : 'Hello, this is your SwasthyaSetu health companion.';

    final hr = sample.heartRateBpm;
    final spo2 = sample.spo2Percent;
    final temp = sample.temperatureC;

    final vitalsSpeech = StringBuffer();
    if (hr > 0) {
      if (hr < 55) {
        vitalsSpeech.write(
          ' Your heart rate is $hr beats per minute, which is slightly low.',
        );
      } else if (hr > 100) {
        vitalsSpeech.write(
          ' Your heart rate is $hr beats per minute, which is running fast.',
        );
      } else {
        vitalsSpeech.write(
          ' Your heart rate is $hr beats per minute, which is normal.',
        );
      }
    }

    if (spo2 > 0) {
      if (spo2 < 92) {
        vitalsSpeech.write(
          ' Your oxygen level is $spo2%, which is below the safe range.',
        );
      } else {
        vitalsSpeech.write(
          ' Your oxygen level is $spo2%, which is safe and healthy.',
        );
      }
    }

    if (temp > 37.8) {
      vitalsSpeech.write(
        ' Your body temperature is elevated, indicating fever.',
      );
    }

    if (dehydrationScore != null && dehydrationScore >= 3.0) {
      vitalsSpeech.write(' Signs of dehydration have been detected.');
    }

    if (band == RiskBand.red) {
      return '$greeting Please stay calm. Your vital signs indicate critical strain.$vitalsSpeech '
          'Sit upright and rest. Do not exert yourself. '
          'Please have someone contact the nearest hospital or call 108 ambulance immediately. '
          'Help is on the way, stay strong.';
    }

    if (band == RiskBand.yellow) {
      return '$greeting Your health assessment is complete.$vitalsSpeech '
          'A few measurements require attention. Rest comfortably, drink plenty of clean fluids and ORS, '
          'and please visit your nearest primary health clinic or ASHA worker within the next 24 hours. Take care!';
    }

    return '$greeting Great news! Your health check looks very reassuring.$vitalsSpeech '
        'All your core vitals are well within the safe, healthy zone. '
        'Keep drinking clean water, eat well, and stay healthy.';
  }
}
