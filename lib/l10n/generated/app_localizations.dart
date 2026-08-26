import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'SwasthyaSetu AI'**
  String get appName;

  /// No description provided for @bootstrapping.
  ///
  /// In en, this message translates to:
  /// **'Preparing offline data…'**
  String get bootstrapping;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @notMeasured.
  ///
  /// In en, this message translates to:
  /// **'Not measured'**
  String get notMeasured;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @dbUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The local database did not respond. No data has been lost.'**
  String get dbUnavailable;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get navPatients;

  /// No description provided for @navScreening.
  ///
  /// In en, this message translates to:
  /// **'New screening'**
  String get navScreening;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get navDevices;

  /// No description provided for @navSync.
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get navSync;

  /// No description provided for @navCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get navCommunity;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navSos.
  ///
  /// In en, this message translates to:
  /// **'Emergency SOS'**
  String get navSos;

  /// No description provided for @homeOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get homeOverview;

  /// No description provided for @homeQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get homeQuickActions;

  /// No description provided for @homeStatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeStatToday;

  /// No description provided for @homeStatPending.
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get homeStatPending;

  /// No description provided for @homeStatHighRisk.
  ///
  /// In en, this message translates to:
  /// **'High risk'**
  String get homeStatHighRisk;

  /// No description provided for @homeStatPatients.
  ///
  /// In en, this message translates to:
  /// **'Active patients'**
  String get homeStatPatients;

  /// No description provided for @homeLastScreening.
  ///
  /// In en, this message translates to:
  /// **'Last screening'**
  String get homeLastScreening;

  /// No description provided for @homeNoScreeningsYet.
  ///
  /// In en, this message translates to:
  /// **'No screening recorded on this device yet.'**
  String get homeNoScreeningsYet;

  /// No description provided for @homeDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This app supports a health worker\'s judgement. It does not diagnose and does not replace a clinician.'**
  String get homeDisclaimer;

  /// No description provided for @patientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get patientsTitle;

  /// No description provided for @patientsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search name, ID or village'**
  String get patientsSearchHint;

  /// No description provided for @patientsNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No patients yet'**
  String get patientsNoneYet;

  /// No description provided for @patientsNoneYetBody.
  ///
  /// In en, this message translates to:
  /// **'Add the first patient to start screening. Everything is stored on this phone.'**
  String get patientsNoneYetBody;

  /// No description provided for @patientsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get patientsNoMatches;

  /// No description provided for @patientsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add patient'**
  String get patientsAdd;

  /// No description provided for @patientsNeverScreened.
  ///
  /// In en, this message translates to:
  /// **'Never screened'**
  String get patientsNeverScreened;

  /// No description provided for @patientAge.
  ///
  /// In en, this message translates to:
  /// **'Age {years}'**
  String patientAge(int years);

  /// No description provided for @screeningNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New screening'**
  String get screeningNewTitle;

  /// No description provided for @screeningSelectPatient.
  ///
  /// In en, this message translates to:
  /// **'Select a patient'**
  String get screeningSelectPatient;

  /// No description provided for @screeningSelectDevice.
  ///
  /// In en, this message translates to:
  /// **'Select a device'**
  String get screeningSelectDevice;

  /// No description provided for @screeningScanForDevices.
  ///
  /// In en, this message translates to:
  /// **'Scan for devices'**
  String get screeningScanForDevices;

  /// No description provided for @screeningUseDemoDevice.
  ///
  /// In en, this message translates to:
  /// **'Use demo device'**
  String get screeningUseDemoDevice;

  /// No description provided for @screeningChangeDevice.
  ///
  /// In en, this message translates to:
  /// **'Change device'**
  String get screeningChangeDevice;

  /// No description provided for @screeningDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get screeningDisconnect;

  /// No description provided for @screeningStart.
  ///
  /// In en, this message translates to:
  /// **'Start screening'**
  String get screeningStart;

  /// No description provided for @screeningStepPlaceFinger.
  ///
  /// In en, this message translates to:
  /// **'Place finger on sensor'**
  String get screeningStepPlaceFinger;

  /// No description provided for @screeningStepAttachElectrodes.
  ///
  /// In en, this message translates to:
  /// **'Attach ECG electrodes'**
  String get screeningStepAttachElectrodes;

  /// No description provided for @screeningStepRemainStill.
  ///
  /// In en, this message translates to:
  /// **'Remain still'**
  String get screeningStepRemainStill;

  /// No description provided for @screeningStepMeasureTemperature.
  ///
  /// In en, this message translates to:
  /// **'Measure temperature'**
  String get screeningStepMeasureTemperature;

  /// No description provided for @screeningLiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Live vitals'**
  String get screeningLiveTitle;

  /// No description provided for @screeningEcgTitle.
  ///
  /// In en, this message translates to:
  /// **'ECG live view'**
  String get screeningEcgTitle;

  /// No description provided for @screeningWaitingForBoard.
  ///
  /// In en, this message translates to:
  /// **'Waiting for readings from the sensor board…'**
  String get screeningWaitingForBoard;

  /// No description provided for @screeningNoBoard.
  ///
  /// In en, this message translates to:
  /// **'No sensor board is connected, so these figures are generated by the app. They are not a reading from any patient.'**
  String get screeningNoBoard;

  /// No description provided for @screeningDemoBadge.
  ///
  /// In en, this message translates to:
  /// **'DEMO'**
  String get screeningDemoBadge;

  /// No description provided for @screeningLiveBadge.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get screeningLiveBadge;

  /// No description provided for @screeningStop.
  ///
  /// In en, this message translates to:
  /// **'Stop and continue'**
  String get screeningStop;

  /// No description provided for @vitalHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get vitalHeartRate;

  /// No description provided for @vitalSpo2.
  ///
  /// In en, this message translates to:
  /// **'Oxygen (SpO₂)'**
  String get vitalSpo2;

  /// No description provided for @vitalTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get vitalTemperature;

  /// No description provided for @vitalBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure'**
  String get vitalBloodPressure;

  /// No description provided for @vitalRespiration.
  ///
  /// In en, this message translates to:
  /// **'Breathing rate'**
  String get vitalRespiration;

  /// No description provided for @vitalEcgRhythm.
  ///
  /// In en, this message translates to:
  /// **'Rhythm'**
  String get vitalEcgRhythm;

  /// No description provided for @vitalSignalQuality.
  ///
  /// In en, this message translates to:
  /// **'Signal quality'**
  String get vitalSignalQuality;

  /// No description provided for @symptomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get symptomsTitle;

  /// No description provided for @symptomsSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select symptoms'**
  String get symptomsSelectTitle;

  /// No description provided for @symptomsSelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check everything the patient reports for this screening'**
  String get symptomsSelectSubtitle;

  /// No description provided for @symptomsDuration.
  ///
  /// In en, this message translates to:
  /// **'How long'**
  String get symptomsDuration;

  /// No description provided for @symptomsNotes.
  ///
  /// In en, this message translates to:
  /// **'Other notes (optional)'**
  String get symptomsNotes;

  /// No description provided for @symptomsNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Anything else worth recording…'**
  String get symptomsNotesHint;

  /// No description provided for @symptomsContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue to triage'**
  String get symptomsContinue;

  /// No description provided for @symptomsNoneReported.
  ///
  /// In en, this message translates to:
  /// **'No symptoms reported'**
  String get symptomsNoneReported;

  /// No description provided for @durationUnder24h.
  ///
  /// In en, this message translates to:
  /// **'Under 24 hours'**
  String get durationUnder24h;

  /// No description provided for @duration1to3Days.
  ///
  /// In en, this message translates to:
  /// **'1–3 days'**
  String get duration1to3Days;

  /// No description provided for @duration4to7Days.
  ///
  /// In en, this message translates to:
  /// **'4–7 days'**
  String get duration4to7Days;

  /// No description provided for @duration1to2Weeks.
  ///
  /// In en, this message translates to:
  /// **'1–2 weeks'**
  String get duration1to2Weeks;

  /// No description provided for @durationOver2Weeks.
  ///
  /// In en, this message translates to:
  /// **'Over 2 weeks'**
  String get durationOver2Weeks;

  /// No description provided for @triageTitle.
  ///
  /// In en, this message translates to:
  /// **'Triage result'**
  String get triageTitle;

  /// No description provided for @triageBandGreen.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get triageBandGreen;

  /// No description provided for @triageBandYellow.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get triageBandYellow;

  /// No description provided for @triageBandRed.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get triageBandRed;

  /// No description provided for @triageBandGreenShort.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get triageBandGreenShort;

  /// No description provided for @triageBandYellowShort.
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get triageBandYellowShort;

  /// No description provided for @triageBandRedShort.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get triageBandRedShort;

  /// No description provided for @triageRecommendedAction.
  ///
  /// In en, this message translates to:
  /// **'What to do now'**
  String get triageRecommendedAction;

  /// No description provided for @triageWhyThisBand.
  ///
  /// In en, this message translates to:
  /// **'Why this result'**
  String get triageWhyThisBand;

  /// No description provided for @triageExplainThis.
  ///
  /// In en, this message translates to:
  /// **'Explain this'**
  String get triageExplainThis;

  /// No description provided for @triageSaveScreening.
  ///
  /// In en, this message translates to:
  /// **'Save screening'**
  String get triageSaveScreening;

  /// No description provided for @triageSaved.
  ///
  /// In en, this message translates to:
  /// **'Screening saved to this phone'**
  String get triageSaved;

  /// No description provided for @triageNotADiagnosis.
  ///
  /// In en, this message translates to:
  /// **'This is a triage aid based on fixed rules, not a diagnosis.'**
  String get triageNotADiagnosis;

  /// No description provided for @escalationEmergency.
  ///
  /// In en, this message translates to:
  /// **'Seek care now'**
  String get escalationEmergency;

  /// No description provided for @escalationClinicVisit.
  ///
  /// In en, this message translates to:
  /// **'Clinic review'**
  String get escalationClinicVisit;

  /// No description provided for @escalationFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow up'**
  String get escalationFollowUp;

  /// No description provided for @escalationRoutine.
  ///
  /// In en, this message translates to:
  /// **'Routine monitoring'**
  String get escalationRoutine;

  /// No description provided for @rhythmRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular rhythm'**
  String get rhythmRegular;

  /// No description provided for @rhythmFast.
  ///
  /// In en, this message translates to:
  /// **'Fast rhythm'**
  String get rhythmFast;

  /// No description provided for @rhythmSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow rhythm'**
  String get rhythmSlow;

  /// No description provided for @rhythmIrregular.
  ///
  /// In en, this message translates to:
  /// **'Irregular rhythm'**
  String get rhythmIrregular;

  /// No description provided for @rhythmNoisy.
  ///
  /// In en, this message translates to:
  /// **'Signal too noisy'**
  String get rhythmNoisy;

  /// No description provided for @rhythmUnclassified.
  ///
  /// In en, this message translates to:
  /// **'Not classified'**
  String get rhythmUnclassified;

  /// No description provided for @bpCalibrated.
  ///
  /// In en, this message translates to:
  /// **'Calibrated estimate'**
  String get bpCalibrated;

  /// No description provided for @bpEstimated.
  ///
  /// In en, this message translates to:
  /// **'Uncalibrated estimate'**
  String get bpEstimated;

  /// No description provided for @bpExperimental.
  ///
  /// In en, this message translates to:
  /// **'Experimental — not for clinical use'**
  String get bpExperimental;

  /// No description provided for @syncUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get syncUploaded;

  /// No description provided for @syncUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get syncUploading;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get syncFailed;

  /// No description provided for @syncWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to upload'**
  String get syncWaiting;

  /// No description provided for @sosTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency SOS'**
  String get sosTitle;

  /// No description provided for @sosStart.
  ///
  /// In en, this message translates to:
  /// **'Start SOS'**
  String get sosStart;

  /// No description provided for @sosSendNow.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get sosSendNow;

  /// No description provided for @sosSendSms.
  ///
  /// In en, this message translates to:
  /// **'Send emergency SMS'**
  String get sosSendSms;

  /// No description provided for @sosHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'Works without internet. You get a countdown to cancel, then your messaging app opens with the alert ready to send.'**
  String get sosHowItWorks;

  /// No description provided for @sosCountdown.
  ///
  /// In en, this message translates to:
  /// **'Sending in {seconds} s — tap cancel to stop'**
  String sosCountdown(int seconds);

  /// No description provided for @sosCancelled.
  ///
  /// In en, this message translates to:
  /// **'SOS cancelled. Nothing was sent.'**
  String get sosCancelled;

  /// No description provided for @sosMessagePreview.
  ///
  /// In en, this message translates to:
  /// **'Message preview'**
  String get sosMessagePreview;

  /// No description provided for @sosRecipients.
  ///
  /// In en, this message translates to:
  /// **'Will be messaged ({count})'**
  String sosRecipients(int count);

  /// No description provided for @sosNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts configured.'**
  String get sosNoContacts;

  /// No description provided for @sosNoContactsBody.
  ///
  /// In en, this message translates to:
  /// **'Add at least one emergency contact before you can send.'**
  String get sosNoContactsBody;

  /// No description provided for @sosAddContact.
  ///
  /// In en, this message translates to:
  /// **'Add a contact'**
  String get sosAddContact;

  /// No description provided for @sosMessagingAppOpened.
  ///
  /// In en, this message translates to:
  /// **'Messaging app opened'**
  String get sosMessagingAppOpened;

  /// No description provided for @sosPressSendInApp.
  ///
  /// In en, this message translates to:
  /// **'Press send in your messaging app to deliver it.'**
  String get sosPressSendInApp;

  /// No description provided for @sosCouldNotSend.
  ///
  /// In en, this message translates to:
  /// **'Could not send'**
  String get sosCouldNotSend;

  /// No description provided for @sosRecordedEitherWay.
  ///
  /// In en, this message translates to:
  /// **'This attempt is recorded in the SOS log either way.'**
  String get sosRecordedEitherWay;

  /// No description provided for @sosRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent SOS activity'**
  String get sosRecentActivity;

  /// No description provided for @sosNoneRaised.
  ///
  /// In en, this message translates to:
  /// **'No SOS has been raised on this device.'**
  String get sosNoneRaised;

  /// No description provided for @sosLocationShared.
  ///
  /// In en, this message translates to:
  /// **'Location shared'**
  String get sosLocationShared;

  /// No description provided for @sosLocationNotShared.
  ///
  /// In en, this message translates to:
  /// **'No location — consent is off'**
  String get sosLocationNotShared;

  /// No description provided for @sosContactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency contacts'**
  String get sosContactsTitle;

  /// No description provided for @sosContactsNoneYet.
  ///
  /// In en, this message translates to:
  /// **'None yet — an SOS has nowhere to go'**
  String get sosContactsNoneYet;

  /// No description provided for @sosFallDetected.
  ///
  /// In en, this message translates to:
  /// **'A fall was detected'**
  String get sosFallDetected;

  /// No description provided for @sosFallCancel.
  ///
  /// In en, this message translates to:
  /// **'I\'m fine, cancel'**
  String get sosFallCancel;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'Data and privacy'**
  String get consentTitle;

  /// No description provided for @consentLocation.
  ///
  /// In en, this message translates to:
  /// **'Tag screenings with location'**
  String get consentLocation;

  /// No description provided for @consentLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Off by default. Adds a coordinate to new screenings so outbreak clusters can be seen. You can turn this off at any time, and past screenings keep whatever they were saved with.'**
  String get consentLocationBody;

  /// No description provided for @consentAi.
  ///
  /// In en, this message translates to:
  /// **'Send readings to online AI'**
  String get consentAi;

  /// No description provided for @consentAiBody.
  ///
  /// In en, this message translates to:
  /// **'Off by default. When on, a screening\'s numbers are sent to Google Gemini to write the explanation. When off, explanations come from the on-device guideline library and nothing leaves this phone.'**
  String get consentAiBody;

  /// No description provided for @consentSync.
  ///
  /// In en, this message translates to:
  /// **'Upload to the health facility'**
  String get consentSync;

  /// No description provided for @consentSyncBody.
  ///
  /// In en, this message translates to:
  /// **'Off by default. When on, saved screenings are queued and uploaded when there is a connection. When off, everything stays on this phone.'**
  String get consentSyncBody;

  /// No description provided for @consentGranted.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get consentGranted;

  /// No description provided for @consentDenied.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get consentDenied;

  /// No description provided for @consentExportData.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get consentExportData;

  /// No description provided for @consentDeleteData.
  ///
  /// In en, this message translates to:
  /// **'Delete all data on this phone'**
  String get consentDeleteData;

  /// No description provided for @consentDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete everything?'**
  String get consentDeleteConfirm;

  /// No description provided for @consentDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Every patient, screening and waveform stored on this phone is removed. Anything already uploaded is not affected. This cannot be undone.'**
  String get consentDeleteConfirmBody;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी (Hindi)'**
  String get settingsLanguageHindi;

  /// No description provided for @settingsLanguageBengali.
  ///
  /// In en, this message translates to:
  /// **'বাংলা (Bengali)'**
  String get settingsLanguageBengali;

  /// No description provided for @settingsDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsDisplay;

  /// No description provided for @settingsHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get settingsHighContrast;

  /// No description provided for @settingsHighContrastBody.
  ///
  /// In en, this message translates to:
  /// **'Stronger colours and outlines for use in sunlight'**
  String get settingsHighContrastBody;

  /// No description provided for @settingsEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get settingsEmergency;

  /// No description provided for @settingsFallDetection.
  ///
  /// In en, this message translates to:
  /// **'Fall detection'**
  String get settingsFallDetection;

  /// No description provided for @settingsCancelWindow.
  ///
  /// In en, this message translates to:
  /// **'Cancel window'**
  String get settingsCancelWindow;

  /// No description provided for @settingsCancelWindowBody.
  ///
  /// In en, this message translates to:
  /// **'How long you get to stop an automatic SOS'**
  String get settingsCancelWindowBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
