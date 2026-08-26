import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/data/repositories/settings_repository.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:uuid/uuid.dart';

/// Why an email sign-in/registration failed, mapped to copy in the UI.
enum AuthFailure {
  emailInUse,
  wrongCredentials,
  weakPassword,
  invalidEmail,
  googleUnavailable,
  googleCancelled,
}

class AuthException implements Exception {
  final AuthFailure failure;
  final String? detail;
  const AuthException(this.failure, [this.detail]);

  @override
  String toString() => 'AuthException($failure)';
}

/// Local-first account store.
///
/// Every account lives on this phone in SQLite. Passwords are never stored —
/// only a salted PBKDF2-HMAC-SHA256 digest — so a stolen database file does
/// not leak reusable credentials, and the whole flow works with zero
/// connectivity, which is the normal condition at the camps this app serves.
///
/// Google sign-in is layered on top: a successful Google flow creates (or
/// reuses) a local account row keyed by the Google email, with no password.
class AuthRepository {
  AuthRepository(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  /// 20k iterations: ~50 ms on a budget phone, far beyond brute-force reach
  /// for a 6+ character password on a stolen offline dump.
  static const int _iterations = 20000;
  static const int _saltBytes = 16;
  static const int _keyBytes = 32;

  // ──────────────────────────── Session ────────────────────────────

  Future<String?> activeAccountId() =>
      _db.getSetting(SettingKeys.authActiveAccountId);

  Future<UserAccount?> activeAccount() async {
    final id = await activeAccountId();
    if (id == null) return null;
    final row = await _db.getAuthAccount(id);
    return row == null ? null : _toAccount(row);
  }

  Future<void> _startSession(String accountId) =>
      _db.setSetting(SettingKeys.authActiveAccountId, accountId);

  Future<void> endSession() =>
      _db.deleteSetting(SettingKeys.authActiveAccountId);

  // ──────────────────────────── Email ────────────────────────────

  /// Registers an email/password account. Throws [AuthException] on the
  /// failure modes the form needs to render distinctly.
  Future<UserAccount> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    final normalised = _normaliseEmail(email);
    if (!_looksLikeEmail(normalised)) {
      throw const AuthException(AuthFailure.invalidEmail);
    }
    if (password.length < 6) {
      throw const AuthException(AuthFailure.weakPassword);
    }
    if (await _db.getAuthAccountByEmail(normalised) != null) {
      throw const AuthException(AuthFailure.emailInUse);
    }

    final salt = _randomBytes(_saltBytes);
    final hash = _deriveKey(password, salt);
    final now = DateTime.now();
    final account = AuthAccountRow(
      id: 'ACC-${_uuid.v4()}',
      email: normalised,
      displayName: displayName.trim(),
      role: role.storageValue,
      provider: AuthAccountProvider.email.storageValue,
      passwordHash: base64Encode(hash),
      passwordSalt: base64Encode(salt),
      photoUrl: null,
      age: null,
      sex: '',
      heightCm: null,
      weightKg: null,
      conditions: '[]',
      problems: null,
      profileComplete: false,
      patientId: null,
      createdAt: now,
      lastLoginAt: now,
    );
    await _db.upsertAuthAccount(account.toCompanion(true));
    final created = _toAccount(account);
    await _startSession(created.id);
    return created;
  }

  Future<UserAccount> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final row = await _db.getAuthAccountByEmail(_normaliseEmail(email));
    if (row == null || row.passwordHash == null || row.passwordSalt == null) {
      // One message for "no such account", "Google account — has no password"
      // and "wrong password": which of them it was is account enumeration
      // bait, and on a shared camp phone that distinction matters.
      throw const AuthException(AuthFailure.wrongCredentials);
    }
    final candidate = _deriveKey(password, base64Decode(row.passwordSalt!));
    final expected = base64Decode(row.passwordHash!);
    if (!_constantTimeEquals(candidate, expected)) {
      throw const AuthException(AuthFailure.wrongCredentials);
    }
    await _touchLogin(row.id);
    await _startSession(row.id);
    return _toAccount((await _db.getAuthAccount(row.id))!);
  }

  // ──────────────────────────── Google ────────────────────────────

  /// Creates or reuses the account for a verified Google identity. A returning
  /// account keeps its original role — the role the picker was showing when
  /// the button was tapped never overrides what is on record.
  Future<UserAccount> signInWithGoogleIdentity({
    required String email,
    required String displayName,
    String? photoUrl,
    required UserRole roleForNewAccounts,
  }) async {
    final normalised = _normaliseEmail(email);
    final existing = await _db.getAuthAccountByEmail(normalised);
    if (existing != null) {
      await _touchLogin(existing.id);
      await _startSession(existing.id);
      return _toAccount((await _db.getAuthAccount(existing.id))!);
    }
    final now = DateTime.now();
    final account = AuthAccountRow(
      id: 'ACC-${_uuid.v4()}',
      email: normalised,
      displayName: displayName.trim().isEmpty ? normalised : displayName.trim(),
      role: roleForNewAccounts.storageValue,
      provider: AuthAccountProvider.google.storageValue,
      passwordHash: null,
      passwordSalt: null,
      photoUrl: photoUrl,
      age: null,
      sex: '',
      heightCm: null,
      weightKg: null,
      conditions: '[]',
      problems: null,
      profileComplete: false,
      patientId: null,
      createdAt: now,
      lastLoginAt: now,
    );
    await _db.upsertAuthAccount(account.toCompanion(true));
    final created = _toAccount(account);
    await _startSession(created.id);
    return created;
  }

  // ──────────────────────────── Profile ────────────────────────────

  /// Writes the registration profile and links the account to its screening
  /// subject (the Patients row created by the caller).
  Future<UserAccount> completeProfile({
    required String accountId,
    required String displayName,
    required int age,
    required String sex,
    required double heightCm,
    required double weightKg,
    required List<String> conditions,
    String? problems,
    required String patientId,
  }) async {
    await _db.patchAuthAccount(
      accountId,
      AuthAccountsCompanion(
        displayName: Value(displayName.trim()),
        age: Value(age),
        sex: Value(sex),
        heightCm: Value(heightCm),
        weightKg: Value(weightKg),
        conditions: Value(jsonEncode(conditions)),
        problems: Value(
          problems == null || problems.trim().isEmpty
              ? null
              : problems.trim(),
        ),
        profileComplete: const Value(true),
        patientId: Value(patientId),
      ),
    );
    return _toAccount((await _db.getAuthAccount(accountId))!);
  }

  Future<UserAccount> reload(String accountId) async =>
      _toAccount((await _db.getAuthAccount(accountId))!);

  // ──────────────────────────── Internals ────────────────────────────

  Future<void> _touchLogin(String id) => _db.patchAuthAccount(
        id,
        AuthAccountsCompanion(lastLoginAt: Value(DateTime.now())),
      );

  static String _normaliseEmail(String raw) => raw.trim().toLowerCase();

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  static List<int> _randomBytes(int count) {
    final rng = Random.secure();
    return List<int>.generate(count, (_) => rng.nextInt(256));
  }

  static List<int> _deriveKey(String password, List<int> salt) =>
      _pbkdf2Sha256(utf8.encode(password), salt, _iterations, _keyBytes);

  /// PBKDF2-HMAC-SHA256, RFC 2898. Written against `crypto`'s Hmac rather than
  /// pulled from a password-hashing package so the dependency surface stays at
  /// one audit-able Google package.
  static List<int> _pbkdf2Sha256(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyBytes,
  ) {
    final hmac = Hmac(sha256, password);
    const hashLen = 32; // SHA-256 output size
    final blockCount = (keyBytes / hashLen).ceil();
    final out = <int>[];

    for (var block = 1; block <= blockCount; block++) {
      // U1 = HMAC(password, salt || INT32_BE(block))
      final blockIndex = ByteData(4)..setUint32(0, block, Endian.big);
      var u = hmac.convert([...salt, ...blockIndex.buffer.asUint8List()]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < hashLen; j++) {
          t[j] ^= u[j];
        }
      }
      out.addAll(t);
    }
    return out.sublist(0, keyBytes);
  }

  /// Length-checked, constant-time compare — the obvious way to get this wrong
  /// is `listEquals`, which short-circuits and leaks position by timing.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static UserAccount _toAccount(AuthAccountRow r) => UserAccount(
        id: r.id,
        email: r.email,
        displayName: r.displayName,
        role: UserRole.fromStorage(r.role),
        provider: AuthAccountProvider.fromStorage(r.provider),
        photoUrl: r.photoUrl,
        age: r.age,
        sex: r.sex,
        heightCm: r.heightCm,
        weightKg: r.weightKg,
        conditions: UserAccount.decodeConditions(r.conditions),
        problems: r.problems,
        profileComplete: r.profileComplete,
        patientId: r.patientId,
        createdAt: r.createdAt,
        lastLoginAt: r.lastLoginAt,
      );
}
