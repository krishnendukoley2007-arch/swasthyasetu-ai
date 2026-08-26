/// Offline retrieval over the bundled clinical guideline corpus.
///
/// This is the piece that makes Tier 2 degrade to *offline explanation* rather
/// than *no explanation*. It is BM25 over the pre-tokenised `keywords` column,
/// plus a hard boost for chunks tagged with the rules that actually fired.
///
/// Why BM25 and not embeddings: the corpus is 24 chunks of clinical prose and
/// the query is a fixed vocabulary the app itself generated — rule ids, vital
/// names, symptom labels. Term overlap is near-perfect for that, needs no model
/// weights on disk, and runs in microseconds on a budget phone. An embedding
/// index would cost 20-40 MB of the storage budget to answer the same question
/// slightly differently.
///
/// The rule-tag boost matters more than the text score: a screening that fired
/// `spo2_critical` must surface the SpO2 chunk even if the worker's phrasing
/// shares no words with it.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// One retrievable guideline passage, decoupled from the drift row so the
/// scoring is testable without a database.
@immutable
class GuidelineChunk {
  final String id;
  final String source;
  final String title;
  final String body;

  /// Normalised terms, precomputed at seed time. Must have come from the same
  /// tokeniser as the query or nothing ever matches.
  final List<String> keywords;

  /// Rule ids this passage explains, e.g. `['spo2_critical']`.
  final List<String> ruleTags;

  const GuidelineChunk({
    required this.id,
    required this.source,
    required this.title,
    required this.body,
    this.keywords = const [],
    this.ruleTags = const [],
  });

  /// A short attributable citation, e.g. `WHO IMCI — Oxygen saturation below 90%`.
  String get citation => title.isEmpty ? source : '$source — $title';
}

/// A chunk plus why it was returned.
@immutable
class RetrievedChunk {
  final GuidelineChunk chunk;
  final double score;

  /// True when this chunk is tagged with a rule that actually fired, as opposed
  /// to merely sharing vocabulary with the query.
  final bool matchedRule;

  const RetrievedChunk({
    required this.chunk,
    required this.score,
    required this.matchedRule,
  });
}

class GuidelineRetriever {
  /// Standard BM25 term-frequency saturation.
  static const double k1 = 1.2;

  /// Standard BM25 length normalisation.
  static const double b = 0.75;

  /// Added to the score of a chunk tagged with a fired rule. Large on purpose —
  /// it should dominate lexical similarity, because a tag is ground truth about
  /// relevance while term overlap is a guess.
  static const double ruleTagBoost = 12.0;

  final List<GuidelineChunk> _corpus;
  final Map<String, int> _documentFrequency;
  final double _averageLength;

  GuidelineRetriever(List<GuidelineChunk> corpus)
      : _corpus = List.unmodifiable(corpus),
        _documentFrequency = _buildDocumentFrequency(corpus),
        _averageLength = corpus.isEmpty
            ? 0
            : corpus.fold<int>(0, (sum, c) => sum + c.keywords.length) /
                corpus.length;

  bool get isEmpty => _corpus.isEmpty;
  int get length => _corpus.length;

  static Map<String, int> _buildDocumentFrequency(
    List<GuidelineChunk> corpus,
  ) {
    final df = <String, int>{};
    for (final chunk in corpus) {
      for (final term in chunk.keywords.toSet()) {
        df[term] = (df[term] ?? 0) + 1;
      }
    }
    return df;
  }

  /// Best [limit] passages for [queryTerms], with [ruleIds] boosted.
  ///
  /// [queryTerms] must already be tokenised by the same tokeniser used at seed
  /// time — the caller passes `SeedService.tokenise(query)`.
  List<RetrievedChunk> search({
    required List<String> queryTerms,
    List<String> ruleIds = const [],
    int limit = 3,
    double minScore = 0.01,
  }) {
    if (_corpus.isEmpty) return const [];

    final wanted = ruleIds.toSet();
    final scored = <RetrievedChunk>[];

    for (final chunk in _corpus) {
      final matchedRule = chunk.ruleTags.any(wanted.contains);
      final lexical = _bm25(chunk, queryTerms);
      final score = lexical + (matchedRule ? ruleTagBoost : 0);

      // A chunk with neither a tag hit nor any term overlap is noise; returning
      // it would put an unrelated guideline under a worker's explanation.
      if (score <= minScore) continue;
      scored.add(
        RetrievedChunk(chunk: chunk, score: score, matchedRule: matchedRule),
      );
    }

    scored.sort((a, b) {
      // Tag matches always outrank pure text matches, then score, then id so
      // the ordering is stable across runs (and across test runs).
      if (a.matchedRule != b.matchedRule) return a.matchedRule ? -1 : 1;
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.chunk.id.compareTo(b.chunk.id);
    });

    return scored.take(limit).toList(growable: false);
  }

  double _bm25(GuidelineChunk chunk, List<String> queryTerms) {
    if (queryTerms.isEmpty || chunk.keywords.isEmpty) return 0;

    final termCounts = <String, int>{};
    for (final term in chunk.keywords) {
      termCounts[term] = (termCounts[term] ?? 0) + 1;
    }

    final docLength = chunk.keywords.length;
    var score = 0.0;

    for (final term in queryTerms.toSet()) {
      final tf = termCounts[term];
      if (tf == null) continue;

      final df = _documentFrequency[term] ?? 0;
      // Robertson-Sparck-Jones IDF, floored at zero: a term present in every
      // chunk carries no information and must not push the score negative.
      final idf = math.max(
        0.0,
        math.log((_corpus.length - df + 0.5) / (df + 0.5) + 1.0),
      );

      final norm = _averageLength == 0 ? 1.0 : docLength / _averageLength;
      score += idf * (tf * (k1 + 1)) / (tf + k1 * (1 - b + b * norm));
    }

    return score;
  }
}
