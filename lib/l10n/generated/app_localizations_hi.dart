// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'स्वास्थ्यसेतु AI';

  @override
  String get bootstrapping => 'ऑफ़लाइन डेटा तैयार किया जा रहा है…';

  @override
  String get actionBack => 'वापस';

  @override
  String get actionCancel => 'रद्द करें';

  @override
  String get actionContinue => 'आगे बढ़ें';

  @override
  String get actionSave => 'सहेजें';

  @override
  String get actionRetry => 'फिर कोशिश करें';

  @override
  String get actionClose => 'बंद करें';

  @override
  String get actionChange => 'बदलें';

  @override
  String get actionDone => 'पूरा हुआ';

  @override
  String get actionAdd => 'जोड़ें';

  @override
  String get notMeasured => 'मापा नहीं गया';

  @override
  String get loading => 'लोड हो रहा है…';

  @override
  String get dbUnavailable =>
      'स्थानीय डेटाबेस ने जवाब नहीं दिया। कोई डेटा नहीं खोया है।';

  @override
  String get navHome => 'होम';

  @override
  String get navPatients => 'मरीज़';

  @override
  String get navScreening => 'नई जाँच';

  @override
  String get navHistory => 'इतिहास';

  @override
  String get navDevices => 'उपकरण';

  @override
  String get navSync => 'अपलोड बाकी';

  @override
  String get navCommunity => 'समुदाय';

  @override
  String get navSettings => 'सेटिंग्स';

  @override
  String get navSos => 'आपातकालीन SOS';

  @override
  String get homeOverview => 'सारांश';

  @override
  String get homeQuickActions => 'त्वरित कार्य';

  @override
  String get homeStatToday => 'आज';

  @override
  String get homeStatPending => 'अपलोड बाकी';

  @override
  String get homeStatHighRisk => 'उच्च जोखिम';

  @override
  String get homeStatPatients => 'सक्रिय मरीज़';

  @override
  String get homeLastScreening => 'पिछली जाँच';

  @override
  String get homeNoScreeningsYet => 'इस फ़ोन पर अभी तक कोई जाँच दर्ज नहीं है।';

  @override
  String get homeDisclaimer =>
      'यह ऐप स्वास्थ्यकर्मी के निर्णय में सहायता करता है। यह रोग की पहचान नहीं करता और डॉक्टर का विकल्प नहीं है।';

  @override
  String get patientsTitle => 'मरीज़';

  @override
  String get patientsSearchHint => 'नाम, आईडी या गाँव खोजें';

  @override
  String get patientsNoneYet => 'अभी कोई मरीज़ नहीं';

  @override
  String get patientsNoneYetBody =>
      'जाँच शुरू करने के लिए पहला मरीज़ जोड़ें। सब कुछ इसी फ़ोन में रहता है।';

  @override
  String get patientsNoMatches => 'कोई मेल नहीं';

  @override
  String get patientsAdd => 'मरीज़ जोड़ें';

  @override
  String get patientsNeverScreened => 'कभी जाँच नहीं हुई';

  @override
  String patientAge(int years) {
    return 'उम्र $years';
  }

  @override
  String get screeningNewTitle => 'नई जाँच';

  @override
  String get screeningSelectPatient => 'मरीज़ चुनें';

  @override
  String get screeningSelectDevice => 'उपकरण चुनें';

  @override
  String get screeningScanForDevices => 'उपकरण खोजें';

  @override
  String get screeningUseDemoDevice => 'डेमो उपकरण चुनें';

  @override
  String get screeningChangeDevice => 'उपकरण बदलें';

  @override
  String get screeningDisconnect => 'कनेक्शन हटाएँ';

  @override
  String get screeningStart => 'जाँच शुरू करें';

  @override
  String get screeningStepPlaceFinger => 'सेंसर पर उंगली रखें';

  @override
  String get screeningStepAttachElectrodes => 'ECG इलेक्ट्रोड लगाएँ';

  @override
  String get screeningStepRemainStill => 'स्थिर रहें';

  @override
  String get screeningStepMeasureTemperature => 'तापमान मापें';

  @override
  String get screeningLiveTitle => 'लाइव वाइटल्स';

  @override
  String get screeningEcgTitle => 'ECG लाइव दृश्य';

  @override
  String get screeningWaitingForBoard => 'सेंसर बोर्ड से रीडिंग का इंतज़ार…';

  @override
  String get screeningNoBoard =>
      'कोई सेंसर बोर्ड जुड़ा नहीं है, इसलिए ये आँकड़े ऐप ने बनाए हैं। ये किसी मरीज़ की रीडिंग नहीं हैं।';

  @override
  String get screeningDemoBadge => 'डेमो';

  @override
  String get screeningLiveBadge => 'लाइव';

  @override
  String get screeningStop => 'रोकें और आगे बढ़ें';

  @override
  String get vitalHeartRate => 'हृदय गति';

  @override
  String get vitalSpo2 => 'ऑक्सीजन (SpO₂)';

  @override
  String get vitalTemperature => 'तापमान';

  @override
  String get vitalBloodPressure => 'रक्तचाप';

  @override
  String get vitalRespiration => 'साँस की दर';

  @override
  String get vitalEcgRhythm => 'लय';

  @override
  String get vitalSignalQuality => 'सिग्नल गुणवत्ता';

  @override
  String get symptomsTitle => 'लक्षण';

  @override
  String get symptomsSelectTitle => 'लक्षण चुनें';

  @override
  String get symptomsSelectSubtitle =>
      'मरीज़ ने इस जाँच में जो भी बताया है, सब चुनें';

  @override
  String get symptomsDuration => 'कितने समय से';

  @override
  String get symptomsNotes => 'अन्य टिप्पणी (वैकल्पिक)';

  @override
  String get symptomsNotesHint => 'और कुछ दर्ज करने योग्य…';

  @override
  String get symptomsContinue => 'ट्राइएज पर जाएँ';

  @override
  String get symptomsNoneReported => 'कोई लक्षण नहीं बताया गया';

  @override
  String get durationUnder24h => '24 घंटे से कम';

  @override
  String get duration1to3Days => '1–3 दिन';

  @override
  String get duration4to7Days => '4–7 दिन';

  @override
  String get duration1to2Weeks => '1–2 सप्ताह';

  @override
  String get durationOver2Weeks => '2 सप्ताह से अधिक';

  @override
  String get triageTitle => 'ट्राइएज परिणाम';

  @override
  String get triageBandGreen => 'सामान्य';

  @override
  String get triageBandYellow => 'ध्यान देने योग्य';

  @override
  String get triageBandRed => 'अत्यावश्यक';

  @override
  String get triageBandGreenShort => 'सामान्य';

  @override
  String get triageBandYellowShort => 'ध्यान दें';

  @override
  String get triageBandRedShort => 'अत्यावश्यक';

  @override
  String get triageRecommendedAction => 'अब क्या करें';

  @override
  String get triageWhyThisBand => 'यह परिणाम क्यों';

  @override
  String get triageExplainThis => 'समझाएँ';

  @override
  String get triageSaveScreening => 'जाँच सहेजें';

  @override
  String get triageSaved => 'जाँच इस फ़ोन में सहेजी गई';

  @override
  String get triageNotADiagnosis =>
      'यह तय नियमों पर आधारित ट्राइएज सहायता है, रोग की पहचान नहीं।';

  @override
  String get escalationEmergency => 'तुरंत इलाज कराएँ';

  @override
  String get escalationClinicVisit => 'क्लिनिक में दिखाएँ';

  @override
  String get escalationFollowUp => 'बाद में जाँच करें';

  @override
  String get escalationRoutine => 'नियमित निगरानी';

  @override
  String get rhythmRegular => 'नियमित लय';

  @override
  String get rhythmFast => 'तेज़ लय';

  @override
  String get rhythmSlow => 'धीमी लय';

  @override
  String get rhythmIrregular => 'अनियमित लय';

  @override
  String get rhythmNoisy => 'सिग्नल बहुत अस्पष्ट';

  @override
  String get rhythmUnclassified => 'वर्गीकृत नहीं';

  @override
  String get bpCalibrated => 'कैलिब्रेटेड अनुमान';

  @override
  String get bpEstimated => 'बिना कैलिब्रेशन का अनुमान';

  @override
  String get bpExperimental => 'प्रयोगात्मक — चिकित्सा उपयोग के लिए नहीं';

  @override
  String get syncUploaded => 'अपलोड हो गया';

  @override
  String get syncUploading => 'अपलोड हो रहा है';

  @override
  String get syncFailed => 'अपलोड विफल';

  @override
  String get syncWaiting => 'अपलोड की प्रतीक्षा';

  @override
  String get sosTitle => 'आपातकालीन SOS';

  @override
  String get sosStart => 'SOS शुरू करें';

  @override
  String get sosSendNow => 'अभी भेजें';

  @override
  String get sosSendSms => 'आपातकालीन SMS भेजें';

  @override
  String get sosHowItWorks =>
      'इंटरनेट के बिना काम करता है। रद्द करने के लिए आपको समय मिलता है, फिर आपका मैसेजिंग ऐप अलर्ट के साथ खुलता है।';

  @override
  String sosCountdown(int seconds) {
    return '$seconds सेकंड में भेजा जाएगा — रोकने के लिए रद्द करें';
  }

  @override
  String get sosCancelled => 'SOS रद्द किया गया। कुछ नहीं भेजा गया।';

  @override
  String get sosMessagePreview => 'संदेश का पूर्वावलोकन';

  @override
  String sosRecipients(int count) {
    return 'इन्हें संदेश जाएगा ($count)';
  }

  @override
  String get sosNoContacts => 'कोई संपर्क सेट नहीं है।';

  @override
  String get sosNoContactsBody =>
      'भेजने से पहले कम से कम एक आपातकालीन संपर्क जोड़ें।';

  @override
  String get sosAddContact => 'संपर्क जोड़ें';

  @override
  String get sosMessagingAppOpened => 'मैसेजिंग ऐप खुल गया';

  @override
  String get sosPressSendInApp =>
      'भेजने के लिए अपने मैसेजिंग ऐप में send दबाएँ।';

  @override
  String get sosCouldNotSend => 'भेजा नहीं जा सका';

  @override
  String get sosRecordedEitherWay =>
      'यह प्रयास SOS लॉग में दोनों ही स्थिति में दर्ज है।';

  @override
  String get sosRecentActivity => 'हाल की SOS गतिविधि';

  @override
  String get sosNoneRaised => 'इस फ़ोन से कोई SOS नहीं भेजा गया है।';

  @override
  String get sosLocationShared => 'स्थान साझा किया गया';

  @override
  String get sosLocationNotShared => 'स्थान नहीं — सहमति बंद है';

  @override
  String get sosContactsTitle => 'आपातकालीन संपर्क';

  @override
  String get sosContactsNoneYet => 'अभी कोई नहीं — SOS कहीं नहीं जाएगा';

  @override
  String get sosFallDetected => 'गिरने का पता चला';

  @override
  String get sosFallCancel => 'मैं ठीक हूँ, रद्द करें';

  @override
  String get consentTitle => 'डेटा और निजता';

  @override
  String get consentLocation => 'जाँच के साथ स्थान दर्ज करें';

  @override
  String get consentLocationBody =>
      'डिफ़ॉल्ट रूप से बंद। नई जाँच में निर्देशांक जोड़ता है ताकि प्रकोप के समूह दिखें। आप इसे कभी भी बंद कर सकते हैं; पुरानी जाँच जैसी सहेजी गई थी वैसी ही रहती है।';

  @override
  String get consentAi => 'रीडिंग ऑनलाइन AI को भेजें';

  @override
  String get consentAiBody =>
      'डिफ़ॉल्ट रूप से बंद। चालू होने पर जाँच के आँकड़े व्याख्या लिखने के लिए Google Gemini को भेजे जाते हैं। बंद होने पर व्याख्या फ़ोन में मौजूद दिशानिर्देशों से आती है और कुछ भी फ़ोन से बाहर नहीं जाता।';

  @override
  String get consentSync => 'स्वास्थ्य केंद्र को अपलोड करें';

  @override
  String get consentSyncBody =>
      'डिफ़ॉल्ट रूप से बंद। चालू होने पर सहेजी गई जाँच कतार में जाती है और कनेक्शन मिलने पर अपलोड होती है। बंद होने पर सब कुछ इसी फ़ोन में रहता है।';

  @override
  String get consentGranted => 'चालू';

  @override
  String get consentDenied => 'बंद';

  @override
  String get consentExportData => 'मेरा डेटा निर्यात करें';

  @override
  String get consentDeleteData => 'इस फ़ोन का सारा डेटा मिटाएँ';

  @override
  String get consentDeleteConfirm => 'सब कुछ मिटाएँ?';

  @override
  String get consentDeleteConfirmBody =>
      'इस फ़ोन में सहेजा हर मरीज़, जाँच और तरंग हटा दी जाएगी। जो पहले अपलोड हो चुका है उस पर असर नहीं पड़ता। इसे वापस नहीं लाया जा सकता।';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get settingsLanguage => 'ऐप की भाषा';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageHindi => 'हिन्दी (Hindi)';

  @override
  String get settingsLanguageBengali => 'বাংলা (Bengali)';

  @override
  String get settingsDisplay => 'प्रदर्शन';

  @override
  String get settingsHighContrast => 'उच्च कंट्रास्ट';

  @override
  String get settingsHighContrastBody =>
      'धूप में उपयोग के लिए गहरे रंग और स्पष्ट किनारे';

  @override
  String get settingsEmergency => 'आपातकाल';

  @override
  String get settingsFallDetection => 'गिरने का पता लगाना';

  @override
  String get settingsCancelWindow => 'रद्द करने का समय';

  @override
  String get settingsCancelWindowBody =>
      'स्वतः SOS रोकने के लिए आपको कितना समय मिलता है';
}
