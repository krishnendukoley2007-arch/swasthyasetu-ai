import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:swasthyasetu_ai/core/services/gemini_service.dart';
import 'package:swasthyasetu_ai/core/services/seed_service.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/domain/models/audience.dart';
import 'package:swasthyasetu_ai/domain/models/triage_result.dart';
import 'package:swasthyasetu_ai/domain/rules/guideline_retriever.dart';
import 'package:swasthyasetu_ai/domain/rules/offline_explainer.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';

/// Which tier produced an explanation. Shown to the worker, because "this came
/// from the internet" and "this came from the guidelines on your phone" are
/// materially different claims.
enum ExplanationSource {
  gemini,
  offline;

  String get storageValue => switch (this) {
        ExplanationSource.gemini => 'gemini',
        ExplanationSource.offline => 'offline',
      };

  String get label => switch (this) {
        ExplanationSource.gemini => 'Explained online',
        ExplanationSource.offline => 'Explained offline',
      };

  static ExplanationSource fromStorage(String raw) =>
      raw == 'gemini' ? ExplanationSource.gemini : ExplanationSource.offline;
}

/// An explanation plus where it came from and whether it was already on disk.
class ExplanationResult {
  final AIExplanation explanation;
  final ExplanationSource source;

  /// True when this was read from the cache rather than generated now.
  final bool fromCache;

  /// The guideline passages behind it, for the citations list.
  final List<String> citations;

  const ExplanationResult({
    required this.explanation,
    required this.source,
    required this.fromCache,
    this.citations = const [],
  });
}

/// The tiered explanation layer: online when there is a network and a key,
/// on-device retrieval plus templates otherwise, cached per screening either way.
///
/// The tiering rule is one-directional. Online is *preferred* but never
/// *required*; the offline path is always able to answer, so a worker with no
/// signal gets a real explanation rather than a spinner or an error. The rules
/// engine's band is untouched by both paths.
class ExplanationRepository {
  final AppDatabase _db;
  final GeminiService _gemini;

  /// Built once per corpus load and reused. Rebuilding the term statistics on
  /// every screening would re-read all 24 chunks for nothing.
  GuidelineRetriever? _retriever;

  ExplanationRepository(this._db, this._gemini);

  /// Loads the corpus into a retriever, once.
  Future<GuidelineRetriever> retriever() async {
    final existing = _retriever;
    if (existing != null) return existing;

    final rows = await _db.getAllGuidelineChunks();
    final built = GuidelineRetriever([
      for (final row in rows)
        GuidelineChunk(
          id: row.chunkId,
          source: row.source,
          title: row.title,
          body: row.body,
          keywords: row.keywords.split(' ').where((t) => t.isNotEmpty).toList(),
          ruleTags: _decodeTags(row.ruleTags),
        ),
    ]);

    _retriever = built;
    return built;
  }

  /// Drops the cached retriever, e.g. after the corpus is re-seeded.
  void invalidateCorpus() => _retriever = null;

  static List<String> _decodeTags(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.whereType<String>().toList() : const [];
    } catch (_) {
      return const [];
    }
  }

  /// The passages relevant to one assessment.
  Future<List<RetrievedChunk>> relevantGuidelines(
    TriageAssessment assessment, {
    int limit = 3,
  }) async {
    final index = await retriever();
    if (index.isEmpty) return const [];

    return index.search(
      // Same tokeniser as the seed step. A different one here and nothing ever
      // matches, silently.
      queryTerms: SeedService.tokenise(OfflineExplainer.queryFor(assessment)),
      ruleIds: assessment.ruleIds,
      limit: limit,
    );
  }

  /// The main entry point.
  ///
  /// [screeningId] may be null for the demo walkthrough, in which case nothing
  /// is cached — there is no row to attach it to.
  Future<ExplanationResult> explain({
    required TriageAssessment assessment,
    String? screeningId,
    String? patientName,
    String? languageCode,
    Audience audience = Audience.nurse,
    bool preferOnline = true,
    bool forceRefresh = false,
  }) async {
    if (screeningId != null && !forceRefresh) {
      final cached = await _readCache(screeningId, audience);
      if (cached != null) return cached;
    }

    if (preferOnline) {
      final online = await explainOnline(
        assessment: assessment,
        screeningId: screeningId,
        patientName: patientName,
        languageCode: languageCode,
        audience: audience,
      );
      if (online != null) return online;
      // Fell through: no key, no network, timeout, or unusable response. Not an
      // error — this is the designed degradation.
    }

    return explainOffline(
      assessment: assessment,
      screeningId: screeningId,
      patientName: patientName,
      audience: audience,
    );
  }

  /// Whatever is already stored for this screening, generating nothing.
  Future<ExplanationResult?> cached(
    String screeningId, {
    Audience audience = Audience.nurse,
  }) =>
      _readCache(screeningId, audience);

  /// The explanation the on-device corpus can produce, with nothing awaited over
  /// the network.
  ///
  /// Split out of [explain] so a caller can put words on screen immediately and
  /// upgrade later. The single-call flow awaits Gemini first and only falls back
  /// on failure, which meant a worker on a weak signal watched a spinner for the
  /// full timeout before seeing text that had been sitting on the phone the
  /// whole time.
  Future<ExplanationResult> explainOffline({
    required TriageAssessment assessment,
    String? screeningId,
    String? patientName,
    Audience audience = Audience.nurse,
  }) async {
    final retrieved = await relevantGuidelines(assessment);
    final citations =
        retrieved.map((r) => r.chunk.citation).toList(growable: false);

    final offline = OfflineExplainer.build(
      assessment: assessment,
      retrieved: retrieved,
      patientName: patientName,
    );

    await _writeCache(
      screeningId: screeningId,
      explanation: offline,
      source: ExplanationSource.offline,
      citations: citations,
      modelName: 'on-device rules + guideline retrieval',
      audience: audience,
    );

    return ExplanationResult(
      explanation: offline,
      source: ExplanationSource.offline,
      fromCache: false,
      citations: citations,
    );
  }

  /// The online tier on its own.
  ///
  /// Null means it did not answer — no key, no signal, quota, or an unusable
  /// reply. Never an error to surface, because the offline tier can always
  /// answer and the caller is expected to have shown that first.
  Future<ExplanationResult?> explainOnline({
    required TriageAssessment assessment,
    String? screeningId,
    String? patientName,
    String? languageCode,
    Audience audience = Audience.nurse,
  }) async {
    if (!_gemini.isConfigured) return null;

    final retrieved = await relevantGuidelines(assessment);
    final citations =
        retrieved.map((r) => r.chunk.citation).toList(growable: false);

    final online = await _gemini.explain(
      assessment: assessment,
      retrieved: retrieved,
      patientName: patientName,
      languageCode: languageCode,
      audience: audience,
    );
    if (online == null) return null;

    await _writeCache(
      screeningId: screeningId,
      explanation: online,
      source: ExplanationSource.gemini,
      citations: citations,
      modelName: GeminiService.model,
      audience: audience,
    );

    return ExplanationResult(
      explanation: online,
      source: ExplanationSource.gemini,
      fromCache: false,
      citations: citations,
    );
  }

  /// Symptom follow-up. Null means "needs a connection" — never a templated
  /// answer to a free-text clinical question.
  Future<String?> answerQuestion({
    required TriageAssessment assessment,
    required String question,
    Audience audience = Audience.nurse,
    String? languageCode,
  }) async {
    final retrieved = await relevantGuidelines(assessment, limit: 2);
    return _gemini.answerQuestion(
      assessment: assessment,
      question: question,
      retrieved: retrieved,
      audience: audience,
      languageCode: languageCode,
    );
  }

  /// Which audience a cached row was written for.
  ///
  /// Recorded inside `modelName` rather than in a column of its own, so adding
  /// the patient mode needed no schema migration. Rows written before the mode
  /// existed carry no marker and are read as nurse text, which is what they are.
  static Audience _audienceOf(String modelName) =>
      modelName.contains('audience:${Audience.patient.storageValue}')
          ? Audience.patient
          : Audience.nurse;

  Future<ExplanationResult?> _readCache(
    String screeningId,
    Audience audience,
  ) async {
    // Prefer the online one when both exist: it is the richer text, and the
    // offline row may have been written first while the signal was still down.
    final row = await _db.getExplanation(screeningId,
            source: ExplanationSource.gemini.storageValue) ??
        await _db.getExplanation(screeningId);
    if (row == null) return null;

    // Text written for the other audience is worse than no cache at all: a
    // patient would be told to refer themselves to a PHC, and a nurse would be
    // handed home-care advice the nurse prompt forbids. Regenerate instead.
    if (_audienceOf(row.modelName) != audience) return null;

    return ExplanationResult(
      explanation: AIExplanation(
        summary: row.summary,
        whyThisLevel: row.whyThisLevel,
        safeNextSteps: row.safeNextSteps,
        whenToEscalate: row.whenToEscalate,
        questionsToAsk: _decodeTags(row.questionsToAsk),
        disclaimer: row.disclaimer,
      ),
      source: ExplanationSource.fromStorage(row.source),
      fromCache: true,
      citations: _decodeTags(row.citations),
    );
  }

  Future<void> _writeCache({
    required String? screeningId,
    required AIExplanation explanation,
    required ExplanationSource source,
    required List<String> citations,
    required String modelName,
    required Audience audience,
  }) async {
    if (screeningId == null) return;

    await _db.upsertExplanation(
      ExplanationsCompanion.insert(
        screeningId: screeningId,
        source: source.storageValue,
        summary: explanation.summary,
        whyThisLevel: explanation.whyThisLevel,
        safeNextSteps: explanation.safeNextSteps,
        whenToEscalate: explanation.whenToEscalate,
        questionsToAsk: jsonEncode(explanation.questionsToAsk),
        citations: Value(jsonEncode(citations)),
        disclaimer: explanation.disclaimer,
        modelName: Value('$modelName · audience:${audience.storageValue}'),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteForScreening(String screeningId) =>
      _db.deleteExplanationsForScreening(screeningId);
}
