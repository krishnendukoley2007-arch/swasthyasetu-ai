import 'dart:convert';

/// How the identity was proven. `email` accounts verified a password against
/// the local salted hash; `google` accounts came back from Google's sign-in
/// and hold no credential on the device.
enum AuthAccountProvider {
  email,
  google;

  String get storageValue => switch (this) {
        AuthAccountProvider.email => 'email',
        AuthAccountProvider.google => 'google',
      };

  static AuthAccountProvider fromStorage(String? raw) =>
      raw == 'google' ? AuthAccountProvider.google : AuthAccountProvider.email;
}

/// Who is holding the phone.
///
/// This is the login-time decision the whole app bends around: the router
/// sends each role to its own home, and the AI explanation layer is switched
/// to the matching audience (plain language + safe home care for patients,
/// clinical wording + referral steps for clinicians) so one codebase speaks
/// two languages of responsibility.
enum UserRole {
  patient,
  clinician;

  String get storageValue => switch (this) {
        UserRole.patient => 'patient',
        UserRole.clinician => 'clinician',
      };

  bool get isPatient => this == UserRole.patient;

  static UserRole fromStorage(String? raw) =>
      raw == 'clinician' ? UserRole.clinician : UserRole.patient;
}

/// A signed-in identity plus, for patients, the health profile collected at
/// registration.
///
/// The health fields live on the account rather than only on the Patients row:
/// the Patients row exists so the screening pipeline has a subject to score,
/// but the account is what the person edits — and what the AI explanation is
/// allowed to reason about (age, BMI band, conditions) when it speaks.
class UserAccount {
  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final AuthAccountProvider provider;
  final String? photoUrl;

  final int? age;
  final String sex;
  final double? heightCm;
  final double? weightKg;
  final List<String> conditions;
  final String? problems;
  final bool profileComplete;

  /// The Patients row this account screens itself as. Null for clinicians,
  /// who screen other people instead.
  final String? patientId;

  final DateTime createdAt;
  final DateTime lastLoginAt;

  const UserAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.provider,
    this.photoUrl,
    this.age,
    this.sex = '',
    this.heightCm,
    this.weightKg,
    this.conditions = const [],
    this.problems,
    this.profileComplete = false,
    this.patientId,
    required this.createdAt,
    required this.lastLoginAt,
  });

  /// Body-mass index when both measurements exist. Never rendered as a
  /// diagnosis — it is context for the risk engine and nothing more.
  double? get bmi {
    final h = heightCm;
    final w = weightKg;
    if (h == null || w == null || h <= 0) return null;
    final m = h / 100.0;
    return w / (m * m);
  }

  /// WHO banding, coarse on purpose: the UI is allowed to say "underweight" or
  /// "obese range", it is not allowed to imply disease from a ratio.
  String? get bmiBand {
    final value = bmi;
    if (value == null) return null;
    if (value < 18.5) return 'Underweight';
    if (value < 25) return 'Healthy range';
    if (value < 30) return 'Overweight';
    return 'Obese range';
  }

  /// Maps the registration profile onto the risk engine's vulnerability flags
  /// (`elderly`, `chronic`, `pregnant`, `immunocompromised`) so a screening of
  /// this person is scored against the right thresholds from the first reading.
  List<String> get vulnerabilityFlags {
    final flags = <String>[];
    final a = age;
    if (a != null && a >= 60) flags.add('elderly');
    if (conditions.any((c) => _chronicConditions.contains(c))) {
      flags.add('chronic');
    }
    if (conditions.contains('Immunocompromised')) {
      flags.add('immunocompromised');
    }
    if (conditions.contains('Pregnancy')) flags.add('pregnant');
    return flags;
  }

  /// Conditions that flip the `chronic` threshold group in `RiskEngine`.
  static const Set<String> _chronicConditions = {
    'Diabetes',
    'High blood pressure',
    'Asthma / breathing problem',
    'Heart disease',
    'Thyroid disorder',
    'Kidney disease',
  };

  /// The fixed list the registration form offers. 'None' is exclusive in the
  /// UI; it is never stored alongside a real condition.
  static const List<String> conditionOptions = [
    'Diabetes',
    'High blood pressure',
    'Asthma / breathing problem',
    'Heart disease',
    'Thyroid disorder',
    'Kidney disease',
    'Immunocompromised',
    'Pregnancy',
    'None of these',
  ];

  String get firstName {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return email;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  static List<String> decodeConditions(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } on FormatException {
      // A corrupt cell must not lock someone out of their own app.
    }
    return const [];
  }

  UserAccount copyWith({
    String? id,
    String? email,
    String? displayName,
    UserRole? role,
    AuthAccountProvider? provider,
    String? photoUrl,
    int? age,
    String? sex,
    double? heightCm,
    double? weightKg,
    List<String>? conditions,
    String? problems,
    bool? profileComplete,
    String? patientId,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) =>
      UserAccount(
        id: id ?? this.id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        provider: provider ?? this.provider,
        photoUrl: photoUrl ?? this.photoUrl,
        age: age ?? this.age,
        sex: sex ?? this.sex,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        conditions: conditions ?? this.conditions,
        problems: problems ?? this.problems,
        profileComplete: profileComplete ?? this.profileComplete,
        patientId: patientId ?? this.patientId,
        createdAt: createdAt ?? this.createdAt,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      );

  @override
  String toString() =>
      'UserAccount($id, $email, ${role.storageValue}, complete=$profileComplete)';
}
