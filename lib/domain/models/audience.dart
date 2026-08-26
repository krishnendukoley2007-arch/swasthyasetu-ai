/// Who is reading the explanation.
///
/// The app was built for community health workers, and everything about the
/// original wording assumed one: refer to the PHC, escalate, never name a
/// remedy. Handing the same phone to the person who was screened made that
/// wording wrong in a way no amount of translation fixes — a patient does not
/// "refer" themselves anywhere, and telling them only what *not* to do leaves
/// them with nothing to act on.
///
/// So the audience is a first-class setting rather than a tone tweak. It changes
/// exactly one thing of substance — the prompt sent to the model, and with it
/// what the model is permitted to suggest. The screening pipeline, the rule
/// engine, the band, the score, the offline fallback and the entire chat UI are
/// identical in both modes, because none of them depend on who is holding the
/// phone.
enum Audience {
  /// The original behaviour: clinical framing, referral pathways, and a hard
  /// prohibition on suggesting any medicine, dose or home remedy.
  nurse,

  /// Patient-facing. Explains what the findings could mean and what can safely
  /// be done at home, and is allowed to give practical home care — at the app
  /// owner's explicit instruction. Still forbidden from inventing information or
  /// claiming a confirmed diagnosis from screening data.
  patient;

  String get storageValue => switch (this) {
        Audience.nurse => 'nurse',
        Audience.patient => 'patient',
      };

  /// Shown on the mode selector.
  String get label => switch (this) {
        Audience.nurse => 'I am a nurse',
        Audience.patient => 'I am a patient',
      };

  String get description => switch (this) {
        Audience.nurse => 'Clinical wording, referral steps, and no home '
            'remedies or medicines suggested.',
        Audience.patient => 'Plain wording, what the readings could mean, and '
            'safe home care you can do yourself.',
      };

  bool get isPatient => this == Audience.patient;

  /// Defaults to [nurse] for anything unrecognised, so a corrupt or missing
  /// value can never silently unlock the more permissive prompt.
  static Audience fromStorage(String? raw) =>
      raw == 'patient' ? Audience.patient : Audience.nurse;
}
