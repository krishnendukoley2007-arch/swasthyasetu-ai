/// Online explanation via Gemini Flash.
///
/// Tier 1 of the two-tier design. It is strictly optional: the app ships with no
/// key, every failure path returns null, and the caller falls back to
/// [OfflineExplainer]. Nothing in the screening flow blocks on this.
///
/// The prompt is built so the model **cannot** change the triage decision. The
/// band, score and fired rules are given as fixed facts it must restate, and the
/// response schema has no field for a risk level. A model that disagrees with
/// the rules engine has nowhere to put that disagreement.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:swasthyasetu_ai/domain/models/audience.dart';
import 'package:swasthyasetu_ai/domain/models/triage_result.dart';
import 'package:swasthyasetu_ai/domain/rules/guideline_retriever.dart';
import 'package:swasthyasetu_ai/domain/rules/offline_explainer.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';

/// Why an online attempt did not produce an answer.
///
/// The distinction matters to the person holding the phone: "you have no signal"
/// and "your key was rejected" call for completely different actions, and
/// collapsing both into a blank card leaves them retrying the wrong thing.
enum GeminiFailure {
  /// No credential entered at all.
  notConfigured,

  /// The key was rejected: revoked, restricted to a different API, or an old
  /// `AIza` Standard key, which Google stops accepting in September 2026.
  rejectedKey,

  /// Quota or rate limit.
  quota,

  /// Google answered, with a 5xx. Its side, not the phone's.
  ///
  /// Split out from [network] because collapsing the two was actively
  /// misleading: `gemini-flash` returns `503 UNAVAILABLE` under load often
  /// enough that a worker with four bars of signal was being told the phone
  /// could not reach Google, and went looking for a network they already had.
  serverBusy,

  /// Unreachable, timed out, DNS failure — the ordinary offline case.
  network,

  /// Reached the model, but the response was unusable.
  badResponse,
}

extension GeminiFailureText on GeminiFailure {
  String get label => switch (this) {
        GeminiFailure.notConfigured => 'No AI key entered',
        GeminiFailure.rejectedKey => 'Key rejected',
        GeminiFailure.quota => 'Daily limit reached',
        GeminiFailure.serverBusy => 'Google\'s AI is busy',
        GeminiFailure.network => 'No connection',
        GeminiFailure.badResponse => 'Unusable reply',
      };

  String get detail => switch (this) {
        GeminiFailure.notConfigured =>
          'Add a Gemini API key in Settings to ask follow-up questions online. '
              'The written explanation below was produced on this phone and does '
              'not need one.',
        GeminiFailure.rejectedKey =>
          'Google rejected the key. It may be revoked, restricted to a '
              'different API, or an old-style "AIza" Standard key — those stop '
              'being accepted in September 2026. Make a new key at '
              'aistudio.google.com/apikey and paste it into Settings.',
        GeminiFailure.quota =>
          'This key has used its quota for now. The offline explanation still '
              'works, and online answers should return later.',
        GeminiFailure.serverBusy =>
          'Your connection is fine — Google\'s AI service turned the request '
              'away as overloaded, and it was already retried. Asking again in '
              'a moment usually works. The explanation below is on this phone '
              'either way.',
        GeminiFailure.network =>
          'The phone could not reach Google. Nothing was sent. The explanation '
              'below is already saved on this phone.',
        GeminiFailure.badResponse =>
          'The model replied with something unusable, so nothing is shown rather '
              'than a half-parsed answer.',
      };

  /// Whether the worker can fix this themselves right now.
  bool get isActionable =>
      this == GeminiFailure.notConfigured || this == GeminiFailure.rejectedKey;

  /// Whether asking the same thing again is worth the worker's time.
  bool get isWorthRetrying =>
      this == GeminiFailure.serverBusy || this == GeminiFailure.network;
}

class GeminiService {
  /// Compiled-in fallback: `--dart-define=GEMINI_API_KEY=...`.
  ///
  /// Only a fallback. The key the app actually uses is normally the one the
  /// worker entered in Settings, because a build-time constant cannot be
  /// replaced when it expires and cannot be revoked without a new APK.
  static const String buildTimeKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Shipped so this build can talk to Gemini out of the box, at the app owner's
  /// explicit request.
  ///
  /// A credential in an APK is extractable — `strings` on the binary finds it —
  /// so this is acceptable for a demo build on known phones and not for
  /// distribution. It is the lowest-priority source: Settings overrides it, and
  /// pasting a key there is how it gets replaced once this one lapses.
  ///
  /// Empty in this build, and it stays empty: no credential is committed to the
  /// repository. The Settings field is how a key gets in, and how it gets
  /// replaced without a rebuild.
  static const String shippedKey = '';

  /// The credential in force, preferring the one entered at runtime.
  String _runtimeKey = '';

  /// Set from the stored setting at startup and whenever Settings changes it.
  void setApiKey(String key) => _runtimeKey = key.trim();

  String get apiKey => _runtimeKey.isNotEmpty
      ? _runtimeKey
      : (buildTimeKey.isNotEmpty ? buildTimeKey : shippedKey);

  /// Why the last online attempt failed, for the UI to explain itself. Null
  /// after a success, or before any attempt.
  GeminiFailure? lastFailure;

  /// Two formats reach this API. `AQ.` is the current one — every key AI Studio
  /// now issues is an "auth key" with that prefix. `AIza` is the older
  /// **Standard** key. Anything else — a bare project id, an OAuth `ya29.`
  /// token — is still sent, since refusing to try would be presumptuous about a
  /// format Google may change, but the UI is told so it can warn before the
  /// worker waits on a doomed request.
  bool get keyLooksLikeApiKey =>
      (apiKey.startsWith('AIza') && apiKey.length >= 35) ||
      (apiKey.startsWith('AQ.') && apiKey.length >= 20);

  /// True for an old-style Standard key, which is the one with a deadline.
  ///
  /// This getter used to be `keyIsEphemeral`, fired on the `AQ.` prefix, and
  /// drove a Settings banner telling the worker their key "expires". That was
  /// simply wrong: Google's own documentation states that "all new API keys
  /// created in Google AI Studio are automatically created as auth keys" — the
  /// `AQ.` ones — and that the Gemini API "will reject requests from Standard
  /// keys" from September 2026. The app was warning about the format that
  /// works and recommending the format that is being switched off. The prefix
  /// worth a banner is the other one.
  bool get keyIsLegacyStandard => apiKey.startsWith('AIza');

  /// Verified against the live API on 2026-08-23: `gemini-2.0-flash` is retired
  /// and returns 404 `NOT_FOUND`, which the old constant here would have
  /// surfaced as a generic network failure forever.
  static const String model = 'gemini-3.6-flash';

  static const String endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Fail fast on *reaching* Google. A phone with no signal should fall through
  /// to the offline explanation in seconds, not sit on a spinner.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Then wait properly for the answer. This was 12 seconds for both phases,
  /// which a thinking model on a village connection overran often enough to look
  /// like random failure — the request had landed and was being worked on, and
  /// the app hung up on it.
  static const Duration receiveTimeout = Duration(seconds: 25);

  /// Extra attempts after the first, for failures that another try could fix.
  ///
  /// The single biggest cause of "it answered, then it didn't, then it did" was
  /// that there was no second attempt at all: one transient 503 from Flash and
  /// that question was answered offline forever.
  static const int maxRetries = 2;

  final Dio _dio;
  final int _maxRetries;

  GeminiService({Dio? dio, int maxRetries = maxRetries})
      : _maxRetries = maxRetries,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: connectTimeout,
                receiveTimeout: receiveTimeout,
                headers: {'Content-Type': 'application/json'},
              ),
            );

  bool get isConfigured => apiKey.isNotEmpty;

  /// Maps a thrown Dio error onto [GeminiFailure]. Kept separate so the mapping
  /// is readable and can be reasoned about without a network.
  static GeminiFailure classify(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 400 || status == 401 || status == 403) {
        return GeminiFailure.rejectedKey;
      }
      if (status == 429) return GeminiFailure.quota;
      // 404 here means the *model* is gone, not the network. Google retires
      // model ids on a schedule, and mapping that to "no connection" sent a
      // worker looking for signal they already had.
      if (status == 404) return GeminiFailure.badResponse;
      // Google answered and the answer was "not right now".
      if (status != null && status >= 500) return GeminiFailure.serverBusy;
      return GeminiFailure.network;
    }
    return GeminiFailure.network;
  }

  /// Whether another attempt could plausibly succeed.
  ///
  /// Retried: Google's own 5xx, and a read timeout — which means the request did
  /// land and the model was merely slow. Not retried: a connect timeout or
  /// socket error, because the phone has no route to Google and two more
  /// attempts only spend twenty more seconds proving it; nor a rejected key or
  /// an exhausted quota, which fail identically every time.
  static bool isRetryable(Object error) {
    if (error is! DioException) return false;
    final status = error.response?.statusCode;
    if (status != null) return status >= 500;
    return error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
  }

  /// Short, and deliberately not much longer on the second go: a health worker
  /// is standing in front of somebody. Two retries at these delays add under two
  /// seconds to the worst case.
  static Duration backoffFor(int attempt) =>
      Duration(milliseconds: 400 + 800 * attempt);

  /// One `generateContent` call, retried where retrying is honest.
  ///
  /// Every request in this class goes through here, so the retry policy is in
  /// one place and `explain`, `answerQuestion` and `testKey` cannot drift apart.
  Future<Map<String, dynamic>?> _generate(Map<String, dynamic> body) async {
    for (var attempt = 0;; attempt++) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '$endpoint/$model:generateContent',
          queryParameters: {'key': apiKey},
          data: body,
        );
        return response.data;
      } catch (error) {
        if (attempt >= _maxRetries || !isRetryable(error)) rethrow;
        await Future<void>.delayed(backoffFor(attempt));
      }
    }
  }

  /// Returns null on any failure — no key, no network, timeout, bad JSON, safety
  /// block. The caller must treat null as "use the offline path", never as an
  /// error to show the worker.
  Future<AIExplanation?> explain({
    required TriageAssessment assessment,
    List<RetrievedChunk> retrieved = const [],
    String? patientName,
    String? languageCode,
    Audience audience = Audience.nurse,
  }) async {
    if (!isConfigured) {
      lastFailure = GeminiFailure.notConfigured;
      return null;
    }

    try {
      final data = await _generate({
        'contents': [
          {
            'parts': [
              {
                'text': audience.isPatient
                    ? _buildPatientPrompt(
                        assessment: assessment,
                        retrieved: retrieved,
                        patientName: patientName,
                        languageCode: languageCode,
                      )
                    : _buildPrompt(
                        assessment: assessment,
                        retrieved: retrieved,
                        patientName: patientName,
                        languageCode: languageCode,
                      ),
              },
            ],
          },
        ],
        'generationConfig': {
          // Low temperature: this is a restatement task, not a creative one.
          'temperature': 0.2,
          // Generous, because on a thinking model the reasoning tokens are
          // charged against this same budget. At 1024 the model spent the
          // whole allowance thinking and returned `finishReason: MAX_TOKENS`
          // with an empty body — which read as "AI unavailable" in the UI.
          'maxOutputTokens': 3072,
          'responseMimeType': 'application/json',
          ..._thinkingConfig,
        },
      });

      final text = _extractText(data);
      if (text == null) {
        lastFailure = GeminiFailure.badResponse;
        return null;
      }

      lastFailure = null;
      return _parse(text, assessment: assessment, retrieved: retrieved);
    } catch (e) {
      lastFailure = classify(e);
      return null;
    }
  }

  /// Free-text follow-up, grounded in the same screening.
  ///
  /// Returns null offline, which is how the UI knows to say the Q&A needs a
  /// connection rather than to answer a clinical question from a template.
  Future<String?> answerQuestion({
    required TriageAssessment assessment,
    required String question,
    List<RetrievedChunk> retrieved = const [],
    Audience audience = Audience.nurse,
    String? languageCode,
  }) async {
    if (!isConfigured) {
      lastFailure = GeminiFailure.notConfigured;
      return null;
    }
    if (question.trim().isEmpty) return null;

    try {
      final data = await _generate({
        'contents': [
          {
            'parts': [
              {
                'text': audience.isPatient
                    ? _patientQuestionPrompt(
                        assessment: assessment,
                        question: question,
                        retrieved: retrieved,
                        languageCode: languageCode,
                      )
                    : _nurseQuestionPrompt(
                        assessment: assessment,
                        question: question,
                        retrieved: retrieved,
                      ),
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          // Same budget as the main explanation, and for the same reason. At
          // 1600 the reasoning tokens could consume the whole allowance and the
          // model returned `finishReason: MAX_TOKENS` with no text part at all —
          // which the UI showed as a flat failure. The main explanation was
          // raised to 3072 when this was first hit; this path was missed, so
          // short questions were answered and longer ones silently were not.
          'maxOutputTokens': 3072,
          ..._thinkingConfig,
        },
      });

      final text = _extractText(data)?.trim();
      if (text == null || text.isEmpty) {
        lastFailure = GeminiFailure.badResponse;
        return null;
      }
      lastFailure = null;
      return text;
    } catch (e) {
      lastFailure = classify(e);
      return null;
    }
  }

  /// A cheap round-trip so Settings can verify a pasted key immediately, instead
  /// of the worker discovering it was wrong mid-screening.
  Future<GeminiFailure?> testKey() async {
    if (!isConfigured) return GeminiFailure.notConfigured;
    try {
      await _generate({
        'contents': [
          {'parts': [{'text': 'Reply with the single word: ok'}]},
        ],
        'generationConfig': {
          // 8 was enough on a non-thinking model; here the whole budget would
          // go to reasoning and the round trip would look like a failure.
          'maxOutputTokens': 600,
          ..._thinkingConfig,
        },
      });
      lastFailure = null;
      return null;
    } catch (e) {
      final failure = classify(e);
      lastFailure = failure;
      return failure;
    }
  }

  static const String _systemRules = '''
You explain a screening result to a community health worker in rural India.

Hard rules:
- A deterministic rule engine has ALREADY decided the risk band and score. You
  do not decide, question, or adjust them. Restate them.
- Never diagnose. Never name a disease as the cause.
- Never suggest a medicine, a dose, or a home remedy.
- Plain language, short sentences. Assume the reader is not a clinician.
- If the facts are insufficient, say so plainly.''';

  /// The patient-facing preamble.
  ///
  /// Deliberately different in one substantive way from [_systemRules]: it drops
  /// the blanket ban on home remedies, because a person reading their own result
  /// needs something they can actually do, and "refer to the PHC" is not an
  /// instruction a patient can follow. That widening is the app owner's explicit
  /// decision. The two limits that remain are the ones that keep it honest —
  /// nothing invented, and no diagnosis claimed from screening data — and the
  /// band still comes from the rule engine, not from here.
  static const String _patientSystemRules = '''
You are a patient-facing health assistant.

Analyze the patient's actual vital signs, ECG, symptoms, and available medical guidance. Focus mainly on **what may be happening, what the findings could mean, what the patient can safely do at home, what to monitor, and when medical care is needed**.

Give practical, evidence-based home care and remedies when appropriate. Do not invent information or claim a confirmed diagnosis from screening data. If findings could be serious, clearly explain when to seek urgent or emergency care.

Use the risk score only as supporting information and explain it in one short line.''';

  /// Which language to write in, shared by both audiences.
  ///
  /// Not optional for the patient path: the people most likely to be handed
  /// their own result are the ones least likely to read English.
  static String _languageName(String? languageCode) => switch (languageCode) {
        'bn' => 'Bengali (Bangla script)',
        'hi' => 'Hindi (Devanagari script)',
        _ => 'English',
      };

  /// The five keys both audiences return.
  ///
  /// Identical on purpose. The parser, the cache columns and every bubble in the
  /// chat are shared, so switching audience changes the wording and nothing
  /// structural.
  static const String _jsonContract = '''
Return ONLY a JSON object with exactly these keys:
{
  "summary": "...",
  "whyThisLevel": "...",
  "safeNextSteps": "...",
  "whenToEscalate": "...",
  "questionsToAsk": ["...", "...", "..."]
}''';

  String _buildPatientPrompt({
    required TriageAssessment assessment,
    required List<RetrievedChunk> retrieved,
    String? patientName,
    String? languageCode,
  }) {
    return '''
$_patientSystemRules

Write in ${_languageName(languageCode)}.

PATIENT DATA:
${_patientFactsBlock(assessment, retrieved)}
${patientName == null || patientName.isEmpty ? '' : 'Name: $patientName\n'}
$_jsonContract''';
  }

  /// The compact, pipe-separated form the patient prompt asks for.
  String _patientFactsBlock(
    TriageAssessment assessment,
    List<RetrievedChunk> retrieved,
  ) {
    final s = assessment.sample;
    final rules = assessment.firedRules.isEmpty
        ? 'none'
        : assessment.firedRules.map((r) => '${r.id} ${r.title}').join('; ');

    return '''
Risk: ${assessment.band.storageValue}, Score: ${assessment.score}/100
Heart rate: ${s.heartRateBpm} bpm | SpO2: ${s.spo2Percent}% | Temperature: ${s.temperatureC.toStringAsFixed(1)} °C
ECG quality: ${(s.ecgSignalQuality * 100).round()}% | Symptoms: ${assessment.symptoms.isEmpty ? 'none' : assessment.symptoms.join(', ')}
Vulnerability: ${assessment.flags.isEmpty ? 'none' : assessment.flags.map((f) => f.id).join(', ')} | Rules: $rules
Guidance: ${retrieved.isEmpty ? 'none available offline' : _referenceBlock(retrieved)}''';
  }

  String _nurseQuestionPrompt({
    required TriageAssessment assessment,
    required String question,
    required List<RetrievedChunk> retrieved,
  }) {
    return '''
$_systemRules

Screening facts (fixed, do not contradict):
${_factsBlock(assessment)}

${retrieved.isEmpty ? '' : 'Reference guideline text:\n${_referenceBlock(retrieved)}\n'}
A community health worker asks: "${question.trim()}"

Answer in under 80 words, plain language, no diagnosis, no medicine names or
doses. Do not repeat the screening numbers back unless they are the answer. If
the question cannot be answered safely from the facts above, say so and tell
them to refer instead.''';
  }

  /// The follow-up, patient side.
  ///
  /// Mirrors [_patientSystemRules] rather than the nurse rules: it may suggest
  /// home care, because refusing to while the main explanation does would be
  /// incoherent to the person reading both.
  String _patientQuestionPrompt({
    required TriageAssessment assessment,
    required String question,
    required List<RetrievedChunk> retrieved,
    String? languageCode,
  }) {
    return '''
$_patientSystemRules

Write in ${_languageName(languageCode)}.

PATIENT DATA:
${_patientFactsBlock(assessment, retrieved)}

The patient asks: "${question.trim()}"

Answer in under 100 words, in plain language they can act on. Practical home
care is welcome where it is safe. Do not claim a diagnosis and do not invent
anything the data does not support. If the question cannot be answered safely
from the data above, say so plainly and tell them to see a health worker or
doctor.''';
  }

  String _buildPrompt({
    required TriageAssessment assessment,
    required List<RetrievedChunk> retrieved,
    String? patientName,
    String? languageCode,
  }) {
    final language = switch (languageCode) {
      'bn' => 'Bengali (Bangla script)',
      'hi' => 'Hindi (Devanagari script)',
      _ => 'English',
    };

    return '''
$_systemRules

Write in $language.

Screening facts (fixed, do not contradict):
${_factsBlock(assessment)}
${patientName == null || patientName.isEmpty ? '' : 'Person: $patientName\n'}
${retrieved.isEmpty ? '' : 'Reference guideline text you may draw on:\n${_referenceBlock(retrieved)}\n'}
Return ONLY a JSON object with exactly these keys:
{
  "summary": "2-3 sentences: what was measured and what band it landed in",
  "whyThisLevel": "which findings produced the score, referring only to the rules listed above",
  "safeNextSteps": "what the worker should do now; referral and monitoring only",
  "whenToEscalate": "the danger signs that mean go immediately",
  "questionsToAsk": ["3 to 5 short questions for the worker to ask the person"]
}''';
  }

  String _factsBlock(TriageAssessment assessment) {
    final s = assessment.sample;
    final rules = assessment.firedRules.isEmpty
        ? '- none (all values inside the screening range)'
        : assessment.firedRules
            .map((r) => '- ${r.id}: ${r.title} — ${r.detail} (+${r.points})')
            .join('\n');

    return '''
- Risk band: ${assessment.band.storageValue}
- Risk score: ${assessment.score} of 100
- Recommended action (fixed): ${assessment.recommendedAction}
- Heart rate: ${s.heartRateBpm} bpm
- SpO2: ${s.spo2Percent}%
- Temperature: ${s.temperatureC.toStringAsFixed(1)} C
- ECG signal quality: ${(s.ecgSignalQuality * 100).round()}%
- Reported symptoms: ${assessment.symptoms.isEmpty ? 'none' : assessment.symptoms.join(', ')}
- Vulnerability flags: ${assessment.flags.isEmpty ? 'none' : assessment.flags.map((f) => f.id).join(', ')}
- Rules that fired:
$rules''';
  }

  String _referenceBlock(List<RetrievedChunk> retrieved) => retrieved
      .map((r) => '[${r.chunk.source}] ${r.chunk.title}: ${r.chunk.body}')
      .join('\n\n');

  /// Keep the reasoning budget small.
  ///
  /// Every one of these calls is a restatement of facts the rules engine already
  /// decided, so deep reasoning buys nothing and costs both latency and output
  /// budget on a phone with one bar of signal.
  static const Map<String, dynamic> _thinkingConfig = {
    'thinkingConfig': {'thinkingLevel': 'low'},
  };

  String? _extractText(Map<String, dynamic>? body) {
    if (body == null) return null;
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;

    final content = (candidates.first as Map)['content'];
    // A thinking model that exhausts its budget returns a candidate with no
    // content at all — `finishReason: MAX_TOKENS` and nothing else. Treated as
    // an unusable reply so the caller falls back offline.
    if (content is! Map) return null;

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return null;

    // Scan every part rather than taking the first. Reasoning models emit
    // thought parts alongside the answer, and `parts.first` can be a thought —
    // which would be shown to a health worker as the explanation itself.
    for (final part in parts) {
      if (part is! Map) continue;
      if (part['thought'] == true) continue;
      final text = part['text'];
      if (text is String && text.trim().isNotEmpty) return text;
    }
    return null;
  }

  AIExplanation? _parse(
    String raw, {
    required TriageAssessment assessment,
    required List<RetrievedChunk> retrieved,
  }) {
    // Models still wrap JSON in a fence sometimes, even with a JSON mime type.
    final cleaned = raw
        .replaceAll(RegExp(r'^\s*```(?:json)?', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*$', multiLine: true), '')
        .trim();

    try {
      final json = jsonDecode(cleaned);
      if (json is! Map<String, dynamic>) return null;

      String field(String key) {
        final value = json[key];
        return value is String ? value.trim() : '';
      }

      final summary = field('summary');
      // An empty summary means the model returned something unusable; the
      // offline path is better than a card with blank sections.
      if (summary.isEmpty) return null;

      final questions = json['questionsToAsk'];

      return AIExplanation(
        summary: summary,
        whyThisLevel: field('whyThisLevel'),
        safeNextSteps: field('safeNextSteps'),
        whenToEscalate: field('whenToEscalate'),
        questionsToAsk: questions is List
            ? questions.whereType<String>().toList()
            : const [],
        // The disclaimer is ours, never the model's. It is the one sentence that
        // must not vary with a generation.
        disclaimer: '${OfflineExplainer.disclaimer}\n\n'
            'Explained by $model. The risk band above came from the rule engine, '
            'not from the model.',
        isDemo: assessment.isDemo,
      );
    } catch (_) {
      return null;
    }
  }
}
