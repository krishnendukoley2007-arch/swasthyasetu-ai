// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appName => 'স্বাস্থ্যসেতু AI';

  @override
  String get bootstrapping => 'অফলাইন ডেটা প্রস্তুত করা হচ্ছে…';

  @override
  String get actionBack => 'পিছনে';

  @override
  String get actionCancel => 'বাতিল';

  @override
  String get actionContinue => 'এগিয়ে যান';

  @override
  String get actionSave => 'সংরক্ষণ';

  @override
  String get actionRetry => 'আবার চেষ্টা করুন';

  @override
  String get actionClose => 'বন্ধ করুন';

  @override
  String get actionChange => 'বদলান';

  @override
  String get actionDone => 'সম্পন্ন';

  @override
  String get actionAdd => 'যোগ করুন';

  @override
  String get notMeasured => 'মাপা হয়নি';

  @override
  String get loading => 'লোড হচ্ছে…';

  @override
  String get dbUnavailable =>
      'স্থানীয় ডেটাবেস সাড়া দেয়নি। কোনো তথ্য হারায়নি।';

  @override
  String get navHome => 'হোম';

  @override
  String get navPatients => 'রোগী';

  @override
  String get navScreening => 'নতুন স্ক্রিনিং';

  @override
  String get navHistory => 'ইতিহাস';

  @override
  String get navDevices => 'ডিভাইস';

  @override
  String get navSync => 'আপলোড বাকি';

  @override
  String get navCommunity => 'সম্প্রদায়';

  @override
  String get navSettings => 'সেটিংস';

  @override
  String get navSos => 'জরুরি SOS';

  @override
  String get homeOverview => 'সারসংক্ষেপ';

  @override
  String get homeQuickActions => 'দ্রুত কাজ';

  @override
  String get homeStatToday => 'আজ';

  @override
  String get homeStatPending => 'আপলোড বাকি';

  @override
  String get homeStatHighRisk => 'উচ্চ ঝুঁকি';

  @override
  String get homeStatPatients => 'সক্রিয় রোগী';

  @override
  String get homeLastScreening => 'শেষ স্ক্রিনিং';

  @override
  String get homeNoScreeningsYet =>
      'এই ফোনে এখনো কোনো স্ক্রিনিং নথিভুক্ত হয়নি।';

  @override
  String get homeDisclaimer =>
      'এই অ্যাপ স্বাস্থ্যকর্মীর বিচারে সহায়তা করে। এটি রোগ নির্ণয় করে না এবং চিকিৎসকের বিকল্প নয়।';

  @override
  String get patientsTitle => 'রোগী';

  @override
  String get patientsSearchHint => 'নাম, আইডি বা গ্রাম খুঁজুন';

  @override
  String get patientsNoneYet => 'এখনো কোনো রোগী নেই';

  @override
  String get patientsNoneYetBody =>
      'স্ক্রিনিং শুরু করতে প্রথম রোগী যোগ করুন। সবকিছু এই ফোনেই থাকে।';

  @override
  String get patientsNoMatches => 'কিছু মেলেনি';

  @override
  String get patientsAdd => 'রোগী যোগ করুন';

  @override
  String get patientsNeverScreened => 'কখনো স্ক্রিনিং হয়নি';

  @override
  String patientAge(int years) {
    return 'বয়স $years';
  }

  @override
  String get screeningNewTitle => 'নতুন স্ক্রিনিং';

  @override
  String get screeningSelectPatient => 'রোগী বাছুন';

  @override
  String get screeningSelectDevice => 'ডিভাইস বাছুন';

  @override
  String get screeningScanForDevices => 'ডিভাইস খুঁজুন';

  @override
  String get screeningUseDemoDevice => 'ডেমো ডিভাইস ব্যবহার করুন';

  @override
  String get screeningChangeDevice => 'ডিভাইস বদলান';

  @override
  String get screeningDisconnect => 'সংযোগ বিচ্ছিন্ন করুন';

  @override
  String get screeningStart => 'স্ক্রিনিং শুরু করুন';

  @override
  String get screeningStepPlaceFinger => 'সেন্সরে আঙুল রাখুন';

  @override
  String get screeningStepAttachElectrodes => 'ECG ইলেকট্রোড লাগান';

  @override
  String get screeningStepRemainStill => 'স্থির থাকুন';

  @override
  String get screeningStepMeasureTemperature => 'তাপমাত্রা মাপুন';

  @override
  String get screeningLiveTitle => 'লাইভ ভাইটালস';

  @override
  String get screeningEcgTitle => 'ECG লাইভ দৃশ্য';

  @override
  String get screeningWaitingForBoard =>
      'সেন্সর বোর্ড থেকে রিডিংয়ের অপেক্ষায়…';

  @override
  String get screeningNoBoard =>
      'কোনো সেন্সর বোর্ড যুক্ত নেই, তাই এই সংখ্যাগুলো অ্যাপের তৈরি। এগুলো কোনো রোগীর রিডিং নয়।';

  @override
  String get screeningDemoBadge => 'ডেমো';

  @override
  String get screeningLiveBadge => 'লাইভ';

  @override
  String get screeningStop => 'থামিয়ে এগিয়ে যান';

  @override
  String get vitalHeartRate => 'হৃৎস্পন্দন';

  @override
  String get vitalSpo2 => 'অক্সিজেন (SpO₂)';

  @override
  String get vitalTemperature => 'তাপমাত্রা';

  @override
  String get vitalBloodPressure => 'রক্তচাপ';

  @override
  String get vitalRespiration => 'শ্বাসের হার';

  @override
  String get vitalEcgRhythm => 'ছন্দ';

  @override
  String get vitalSignalQuality => 'সিগন্যালের মান';

  @override
  String get symptomsTitle => 'উপসর্গ';

  @override
  String get symptomsSelectTitle => 'উপসর্গ বাছুন';

  @override
  String get symptomsSelectSubtitle =>
      'এই স্ক্রিনিংয়ে রোগী যা যা জানিয়েছেন সব বাছুন';

  @override
  String get symptomsDuration => 'কত দিন ধরে';

  @override
  String get symptomsNotes => 'অন্যান্য মন্তব্য (ঐচ্ছিক)';

  @override
  String get symptomsNotesHint => 'আর কিছু লিখে রাখার মতো…';

  @override
  String get symptomsContinue => 'ট্রায়াজে যান';

  @override
  String get symptomsNoneReported => 'কোনো উপসর্গ জানানো হয়নি';

  @override
  String get durationUnder24h => '২৪ ঘণ্টার কম';

  @override
  String get duration1to3Days => '১–৩ দিন';

  @override
  String get duration4to7Days => '৪–৭ দিন';

  @override
  String get duration1to2Weeks => '১–২ সপ্তাহ';

  @override
  String get durationOver2Weeks => '২ সপ্তাহের বেশি';

  @override
  String get triageTitle => 'ট্রায়াজ ফলাফল';

  @override
  String get triageBandGreen => 'স্বাভাবিক';

  @override
  String get triageBandYellow => 'নজর দেওয়া দরকার';

  @override
  String get triageBandRed => 'জরুরি';

  @override
  String get triageBandGreenShort => 'স্বাভাবিক';

  @override
  String get triageBandYellowShort => 'নজর দিন';

  @override
  String get triageBandRedShort => 'জরুরি';

  @override
  String get triageRecommendedAction => 'এখন কী করবেন';

  @override
  String get triageWhyThisBand => 'কেন এই ফলাফল';

  @override
  String get triageExplainThis => 'ব্যাখ্যা করুন';

  @override
  String get triageSaveScreening => 'স্ক্রিনিং সংরক্ষণ করুন';

  @override
  String get triageSaved => 'স্ক্রিনিং এই ফোনে সংরক্ষিত হয়েছে';

  @override
  String get triageNotADiagnosis =>
      'এটি নির্দিষ্ট নিয়মভিত্তিক ট্রায়াজ সহায়তা, রোগ নির্ণয় নয়।';

  @override
  String get escalationEmergency => 'এখনই চিকিৎসা নিন';

  @override
  String get escalationClinicVisit => 'ক্লিনিকে দেখান';

  @override
  String get escalationFollowUp => 'পরে আবার দেখুন';

  @override
  String get escalationRoutine => 'নিয়মিত পর্যবেক্ষণ';

  @override
  String get rhythmRegular => 'নিয়মিত ছন্দ';

  @override
  String get rhythmFast => 'দ্রুত ছন্দ';

  @override
  String get rhythmSlow => 'ধীর ছন্দ';

  @override
  String get rhythmIrregular => 'অনিয়মিত ছন্দ';

  @override
  String get rhythmNoisy => 'সিগন্যাল খুব অস্পষ্ট';

  @override
  String get rhythmUnclassified => 'শ্রেণিবদ্ধ নয়';

  @override
  String get bpCalibrated => 'ক্যালিব্রেট করা অনুমান';

  @override
  String get bpEstimated => 'ক্যালিব্রেশন ছাড়া অনুমান';

  @override
  String get bpExperimental => 'পরীক্ষামূলক — চিকিৎসার কাজে নয়';

  @override
  String get syncUploaded => 'আপলোড হয়েছে';

  @override
  String get syncUploading => 'আপলোড হচ্ছে';

  @override
  String get syncFailed => 'আপলোড ব্যর্থ';

  @override
  String get syncWaiting => 'আপলোডের অপেক্ষায়';

  @override
  String get sosTitle => 'জরুরি SOS';

  @override
  String get sosStart => 'SOS শুরু করুন';

  @override
  String get sosSendNow => 'এখনই পাঠান';

  @override
  String get sosSendSms => 'জরুরি SMS পাঠান';

  @override
  String get sosHowItWorks =>
      'ইন্টারনেট ছাড়াই কাজ করে। বাতিল করার জন্য সময় পাবেন, তারপর আপনার মেসেজিং অ্যাপ সতর্কবার্তা নিয়ে খুলবে।';

  @override
  String sosCountdown(int seconds) {
    return '$seconds সেকেন্ডে পাঠানো হবে — থামাতে বাতিল চাপুন';
  }

  @override
  String get sosCancelled => 'SOS বাতিল হয়েছে। কিছুই পাঠানো হয়নি।';

  @override
  String get sosMessagePreview => 'বার্তার প্রাকদর্শন';

  @override
  String sosRecipients(int count) {
    return 'যাদের পাঠানো হবে ($count)';
  }

  @override
  String get sosNoContacts => 'কোনো যোগাযোগ সেট করা নেই।';

  @override
  String get sosNoContactsBody =>
      'পাঠানোর আগে অন্তত একটি জরুরি যোগাযোগ যোগ করুন।';

  @override
  String get sosAddContact => 'যোগাযোগ যোগ করুন';

  @override
  String get sosMessagingAppOpened => 'মেসেজিং অ্যাপ খুলেছে';

  @override
  String get sosPressSendInApp => 'পাঠাতে আপনার মেসেজিং অ্যাপে send চাপুন।';

  @override
  String get sosCouldNotSend => 'পাঠানো গেল না';

  @override
  String get sosRecordedEitherWay =>
      'যাই হোক, এই চেষ্টা SOS লগে নথিভুক্ত থাকে।';

  @override
  String get sosRecentActivity => 'সাম্প্রতিক SOS কার্যকলাপ';

  @override
  String get sosNoneRaised => 'এই ফোন থেকে কোনো SOS পাঠানো হয়নি।';

  @override
  String get sosLocationShared => 'অবস্থান পাঠানো হয়েছে';

  @override
  String get sosLocationNotShared => 'অবস্থান নেই — সম্মতি বন্ধ';

  @override
  String get sosContactsTitle => 'জরুরি যোগাযোগ';

  @override
  String get sosContactsNoneYet => 'এখনো কেউ নেই — SOS কোথাও যাবে না';

  @override
  String get sosFallDetected => 'পড়ে যাওয়া শনাক্ত হয়েছে';

  @override
  String get sosFallCancel => 'আমি ঠিক আছি, বাতিল';

  @override
  String get consentTitle => 'ডেটা ও গোপনীয়তা';

  @override
  String get consentLocation => 'স্ক্রিনিংয়ের সঙ্গে অবস্থান যোগ করুন';

  @override
  String get consentLocationBody =>
      'সাধারণভাবে বন্ধ। নতুন স্ক্রিনিংয়ে স্থানাঙ্ক যোগ করে যাতে প্রাদুর্ভাবের গুচ্ছ দেখা যায়। যেকোনো সময় বন্ধ করতে পারেন; পুরনো স্ক্রিনিং যেমন সংরক্ষিত হয়েছিল তেমনই থাকে।';

  @override
  String get consentAi => 'রিডিং অনলাইন AI-তে পাঠান';

  @override
  String get consentAiBody =>
      'সাধারণভাবে বন্ধ। চালু থাকলে স্ক্রিনিংয়ের সংখ্যাগুলো ব্যাখ্যা লেখার জন্য Google Gemini-তে যায়। বন্ধ থাকলে ব্যাখ্যা ফোনের ভিতরের নির্দেশিকা থেকে আসে এবং কিছুই ফোনের বাইরে যায় না।';

  @override
  String get consentSync => 'স্বাস্থ্যকেন্দ্রে আপলোড করুন';

  @override
  String get consentSyncBody =>
      'সাধারণভাবে বন্ধ। চালু থাকলে সংরক্ষিত স্ক্রিনিং সারিতে যায় এবং সংযোগ পেলে আপলোড হয়। বন্ধ থাকলে সবকিছু এই ফোনেই থাকে।';

  @override
  String get consentGranted => 'চালু';

  @override
  String get consentDenied => 'বন্ধ';

  @override
  String get consentExportData => 'আমার ডেটা রপ্তানি করুন';

  @override
  String get consentDeleteData => 'এই ফোনের সব ডেটা মুছুন';

  @override
  String get consentDeleteConfirm => 'সব মুছে ফেলবেন?';

  @override
  String get consentDeleteConfirmBody =>
      'এই ফোনে সংরক্ষিত প্রতিটি রোগী, স্ক্রিনিং ও তরঙ্গরেখা মুছে যাবে। যা আগে আপলোড হয়েছে তাতে প্রভাব পড়ে না। এটি ফেরানো যায় না।';

  @override
  String get settingsTitle => 'সেটিংস';

  @override
  String get settingsLanguage => 'অ্যাপের ভাষা';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageHindi => 'हिन्दी (Hindi)';

  @override
  String get settingsLanguageBengali => 'বাংলা (Bengali)';

  @override
  String get settingsDisplay => 'প্রদর্শন';

  @override
  String get settingsHighContrast => 'উচ্চ কনট্রাস্ট';

  @override
  String get settingsHighContrastBody =>
      'রোদে ব্যবহারের জন্য গাঢ় রং ও স্পষ্ট রেখা';

  @override
  String get settingsEmergency => 'জরুরি';

  @override
  String get settingsFallDetection => 'পড়ে যাওয়া শনাক্তকরণ';

  @override
  String get settingsCancelWindow => 'বাতিলের সময়';

  @override
  String get settingsCancelWindowBody =>
      'স্বয়ংক্রিয় SOS থামাতে আপনি কতটা সময় পান';
}
