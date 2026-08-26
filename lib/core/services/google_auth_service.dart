import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:swasthyasetu_ai/data/repositories/auth_repository.dart';

/// A verified Google identity, reduced to what an account row needs.
class GoogleIdentity {
  final String email;
  final String displayName;
  final String? photoUrl;

  const GoogleIdentity({
    required this.email,
    required this.displayName,
    this.photoUrl,
  });
}

/// Thin wrapper over `google_sign_in` 7.x (Credential Manager on Android).
///
/// Why a wrapper exists at all: two failure modes must surface differently in
/// the UI — the user cancelling (do nothing, stay silent) and the OAuth client
/// not being configured for this app's signature (say exactly what to fix in
/// Google Cloud Console). The plugin unfortunately reports some configuration
/// errors AS cancellations, so configuration detection happens at
/// `initialize()` time here, before the account sheet ever opens.
///
/// Configuration: on Android this app carries no google-services.json, so the
/// plugin needs the *web* OAuth client id of the Google Cloud project:
/// build with `--dart-define=GOOGLE_SERVER_CLIENT_ID=…`. With it absent the
/// Google button explains itself instead of failing cryptically.
class GoogleAuthService {
  GoogleAuthService({String? serverClientId})
      : _serverClientId = (serverClientId ??
                (const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID')
                        .trim()
                        .isNotEmpty
                    ? const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID')
                    : defaultServerClientId))
            .trim();

  /// This project's web OAuth client id, compiled in so a build cannot silently
  /// lose Google sign-in by forgetting a flag — which is exactly what happened:
  /// a rebuild without `--dart-define` shipped an APK whose Google button only
  /// explained why it could not work.
  ///
  /// Unlike the Gemini key, this is not a secret. Google documents an OAuth
  /// client id as public information, meant to be embedded in the client, and it
  /// authorises nothing on its own — an Android sign-in is only accepted when
  /// the calling app's package name *and* signing certificate SHA-1 match the
  /// client registered in Cloud Console. A copy of this string in someone
  /// else's app gets rejected.
  ///
  /// `--dart-define=GOOGLE_SERVER_CLIENT_ID=…` still overrides it, which is how
  /// a different Cloud project builds this app without editing source.
  static const String defaultServerClientId =
      '431266496612-3kjd9eis0qc23a8fjvdlb954oardhr5e.apps.googleusercontent.com';

  final String _serverClientId;
  bool _initialized = false;

  /// True when the build was given a client id to initialize with. Android
  /// require it only when there is no google-services.json — which this build
  /// deliberately does not carry (see pubspec note).
  bool get isConfigured => _serverClientId.isNotEmpty;

  Future<GoogleIdentity> signIn() async {
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const AuthException(
        AuthFailure.googleUnavailable,
        'Google sign-in is not supported on this device.',
      );
    }
    if (!isConfigured) {
      throw const AuthException(
        AuthFailure.googleUnavailable,
        'Google sign-in is not set up for this build. Email sign-in works '
            'fully offline — use it, or rebuild with '
            '--dart-define=GOOGLE_SERVER_CLIENT_ID=<web OAuth client id>.',
      );
    }

    try {
      if (!_initialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: _serverClientId,
        );
        _initialized = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      return GoogleIdentity(
        email: account.email,
        displayName: account.displayName ?? '',
        photoUrl: account.photoUrl,
      );
    } on GoogleSignInException catch (e) {
      throw switch (e.code) {
        GoogleSignInExceptionCode.canceled => const AuthException(
            AuthFailure.googleCancelled,
          ),
        GoogleSignInExceptionCode.clientConfigurationError => AuthException(
            AuthFailure.googleUnavailable,
            'Google rejected this app\'s identity. Check the OAuth client in '
                'Google Cloud Console: package name and signing SHA-1 must '
                'match this build. (${e.description ?? 'configuration error'})',
          ),
        _ => AuthException(
            AuthFailure.googleUnavailable,
            e.description ?? 'Google sign-in failed.',
          ),
      };
    }
  }

  /// Best-effort. A failed remote sign-out must never trap the user: the local
  /// session is ended by the repository regardless.
  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // See doc comment — intentionally swallowed.
    }
  }
}
