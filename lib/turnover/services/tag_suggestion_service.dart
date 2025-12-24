import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:kashr/db/db_helper.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_suggestion.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:uuid/uuid.dart';

/// Service for generating tag suggestions based on historical data.
class TagSuggestionService {
  /// Minimum similarity threshold for considering a match.
  static const double _similarityThreshold = 0.3;

  /// Maximum number of historical turnovers to analyze.
  static const int _maxHistoricalRecords = 500;

  /// Maximum number of suggestions to return.
  static const int _maxSuggestions = 3;

  /// Generates tag suggestions for a turnover based on historical data.
  ///
  /// Returns a list of up to 3 suggestions ordered by confidence score.
  /// Uses multi-factor scoring:
  /// - Fuzzy text similarity (40%)
  /// - Tag frequency (25%)
  /// - Recency (15%)
  /// - Transaction type match (15%)
  /// - Amount similarity (5%)
  Future<List<TagSuggestion>> getSuggestionsForTurnover(
    Turnover turnover,
  ) async {
    final db = await DatabaseHelper().database;

    // Query historical tag turnovers with associated turnover and tag data
    final historicalData = await db.rawQuery(
      '''
      SELECT
        t.id as tag_id,
        t.name as tag_name,
        t.color as tag_color,
        tv.counter_part as turnover_counterpart,
        tv.purpose as turnover_purpose,
        tv.amount_value as turnover_amount,
        tv.booking_date as turnover_date,
        tv.api_turnover_type as api_turnover_type,
        tt.amount_value as tag_amount,
        tt.created_at as tag_created_at
      FROM tag_turnover tt
      INNER JOIN tag t ON tt.tag_id = t.id
      INNER JOIN turnover tv ON tt.turnover_id = tv.id
      WHERE tv.id != ?
        AND tv.amount_value ${turnover.amountValue >= Decimal.zero ? '>=' : '<'} 0
      ORDER BY tt.created_at DESC
      LIMIT ?
      ''',
      [turnover.id.uuid, _maxHistoricalRecords],
    );

    if (historicalData.isEmpty) {
      // No historical data - fall back to frequency-based suggestions
      return _getFrequencyBasedSuggestions(turnover);
    }

    // Group by tag and calculate scores
    final tagScores = <String, _TagScore>{};

    for (final row in historicalData) {
      final tagId = row['tag_id'] as String;
      final tagName = row['tag_name'] as String;
      final tagColor = row['tag_color'] as String?;
      final counterPart = row['turnover_counterpart'] as String?;
      final purpose = row['turnover_purpose'] as String;
      final apiTurnoverType = row['api_turnover_type'] as String?;
      final tagAmountInt = row['tag_amount'] as int;
      final tagAmount = (Decimal.fromInt(tagAmountInt) / Decimal.fromInt(100))
          .toDecimal(scaleOnInfinitePrecision: 2);
      final createdAt = DateTime.parse(row['tag_created_at'] as String);

      // Calculate text similarity
      final similarity = _calculateTextSimilarity(
        turnover.counterPart,
        turnover.purpose,
        counterPart,
        purpose,
      );

      // Skip if similarity is too low
      if (similarity < _similarityThreshold) continue;

      // Initialize or update tag score
      if (!tagScores.containsKey(tagId)) {
        tagScores[tagId] = _TagScore(
          tag: Tag(
            id: UuidValue.fromString(tagId),
            name: tagName,
            color: tagColor,
          ),
          similarities: [],
          amounts: [],
          dates: [],
          transactionTypes: [],
          frequency: 0,
        );
      }

      final tagScore = tagScores[tagId]!;
      tagScore.similarities.add(similarity);
      tagScore.amounts.add(tagAmount);
      tagScore.dates.add(createdAt);
      tagScore.transactionTypes.add(apiTurnoverType);
      tagScore.frequency++;
    }

    // Calculate final scores for each tag
    final suggestions = <TagSuggestion>[];
    final now = DateTime.now();

    // weights should sum up to 1
    final weightSimilarirty = 0.4;
    final weightFrequency = 0.25;
    final weightRecency = 0.15;
    final weightTransactionType = 0.15;
    final weightAmount = 0.05;

    for (final tagScore in tagScores.values) {
      // Skip tags with no matches
      if (tagScore.similarities.isEmpty) continue;

      // Calculate all scoring factors and apply weights
      final scoresAndWeights = <_ScoreAndWeight>[
        _ScoreAndWeight(
          score: _calcSimilarityScore(tagScore) * weightSimilarirty,
          weight: weightSimilarirty,
        ),

        _ScoreAndWeight(
          score: _calcFrequencyScore(tagScore, tagScores) * weightFrequency,
          weight: weightFrequency,
        ),

        _ScoreAndWeight(
          score: _calcRecencyScore(tagScore, now) * weightRecency,
          weight: weightRecency,
        ),

        _ScoreAndWeight(
          score:
              _calcAmountScore(tagScore, turnover.amountValue) * weightAmount,
          weight: weightAmount,
        ),
        if (turnover.apiTurnoverType != null)
          _ScoreAndWeight(
            score:
                _calcTransactionTypeScore(tagScore, turnover.apiTurnoverType!) *
                weightTransactionType,
            weight: weightTransactionType,
          ),
      ];

      // Calculate total score and normalize by weights used
      // This ensures fair comparison between turnovers with and without specific features
      final rawScore = scoresAndWeights.fold<double>(
        0,
        (sum, it) => sum + it.score,
      );
      final weightsUsed = scoresAndWeights.fold<double>(
        0,
        (sum, it) => sum + it.weight,
      );
      final totalScore = rawScore / weightsUsed;

      // Create suggestion
      suggestions.add(
        TagSuggestion(
          tag: tagScore.tag,
          score: totalScore,
          amountUnit: turnover.amountUnit,
        ),
      );
    }

    // Sort by score and return top N
    suggestions.sort((a, b) => b.score.compareTo(a.score));
    return suggestions.take(_maxSuggestions).toList();
  }

  /// Calculates similarity score based on text matching.
  ///
  /// Returns normalized score (0-1) representing average text similarity.
  double _calcSimilarityScore(_TagScore tagScore) {
    return tagScore.similarities.reduce((a, b) => a + b) /
        tagScore.similarities.length;
  }

  /// Calculates frequency score based on tag usage count.
  ///
  /// Returns normalized score (0-1) based on frequency relative to most used tag.
  double _calcFrequencyScore(
    _TagScore tagScore,
    Map<String, _TagScore> allScores,
  ) {
    final maxFrequency = allScores.values.map((s) => s.frequency).reduce(max);
    return tagScore.frequency / maxFrequency;
  }

  /// Calculates recency score based on how recently the tag was used.
  ///
  /// Returns normalized score (0-1) where more recent usage scores higher.
  /// Uses exponential decay with 30-day half-life.
  double _calcRecencyScore(_TagScore tagScore, DateTime now) {
    final avgDaysSinceUse =
        tagScore.dates
            .map((d) => now.difference(d).inDays)
            .reduce((a, b) => a + b) /
        tagScore.dates.length;
    return 1 / (1 + avgDaysSinceUse / 30);
  }

  /// Calculates amount similarity score.
  ///
  /// Returns normalized score (0-1) based on best match with historical amounts.
  /// Note: Historical amounts already have the same sign due to SQL filtering.
  double _calcAmountScore(_TagScore tagScore, Decimal currentAmount) {
    double bestAmountSimilarity = 0.0;

    for (final historicalAmount in tagScore.amounts) {
      final amountDifference = (currentAmount - historicalAmount).abs();
      final similarity = max(
        0.0,
        1.0 - (amountDifference / currentAmount.abs()).toDouble(),
      );
      bestAmountSimilarity = max(bestAmountSimilarity, similarity);
    }

    return bestAmountSimilarity;
  }

  /// Calculates transaction type match score.
  ///
  /// Returns normalized score (0-1).
  /// Score represents ratio of historical matches.
  double _calcTransactionTypeScore(_TagScore tagScore, String currentType) {
    final typeMatchCount = tagScore.transactionTypes
        .where((type) => type == currentType)
        .length;

    return tagScore.transactionTypes.isNotEmpty
        ? typeMatchCount / tagScore.transactionTypes.length
        : 0.0;
  }

  /// Calculates text similarity between two turnovers.
  ///
  /// Compares both counterPart and purpose fields using fuzzy matching.
  double _calculateTextSimilarity(
    String? currentCounterPart,
    String currentPurpose,
    String? historicalCounterPart,
    String historicalPurpose,
  ) {
    // Normalize strings (lowercase, trim)
    final currentCP = (currentCounterPart ?? '').toLowerCase().trim();
    final historicalCP = (historicalCounterPart ?? '').toLowerCase().trim();
    final currentP = currentPurpose.toLowerCase().trim();
    final historicalP = historicalPurpose.toLowerCase().trim();

    // Calculate similarity for counterPart (if both exist)
    double counterPartSimilarity = 0.0;
    if (currentCP.isNotEmpty && historicalCP.isNotEmpty) {
      counterPartSimilarity = currentCP.similarityTo(historicalCP);
    }

    // Calculate similarity for purpose
    final purposeSimilarity = currentP.similarityTo(historicalP);

    // If both have counterPart, weight it 60%, purpose 40%
    // Otherwise, use only purpose
    if (currentCP.isNotEmpty && historicalCP.isNotEmpty) {
      return counterPartSimilarity * 0.6 + purposeSimilarity * 0.4;
    } else {
      return purposeSimilarity;
    }
  }

  /// Falls back to frequency-based suggestions when no historical data exists.
  ///
  /// Returns the most frequently used tags regardless of similarity.
  Future<List<TagSuggestion>> _getFrequencyBasedSuggestions(
    Turnover turnover,
  ) async {
    final db = await DatabaseHelper().database;

    // Get most frequently used tags
    final result = await db.rawQuery(
      '''
      SELECT
        t.id as tag_id,
        t.name as tag_name,
        t.color as tag_color,
        COUNT(*) as usage_count
      FROM tag_turnover tt
      INNER JOIN tag t ON tt.tagId = t.id
      INNER JOIN turnover tv ON tt.turnoverId = tv.id
      WHERE tv.amountValue ${turnover.amountValue >= Decimal.zero ? '>=' : '<'} 0
      GROUP BY t.id, t.name, t.color
      ORDER BY usage_count DESC
      LIMIT ?
      ''',
      [_maxSuggestions],
    );

    return result.map((row) {
      final tag = Tag(
        id: UuidValue.fromString(row['tag_id'] as String),
        name: row['tag_name'] as String,
        color: row['tag_color'] as String?,
      );

      final usageCount = row['usage_count'] as int;

      // Score based on frequency only (low confidence)
      final score = min(0.3, usageCount / 100.0);

      return TagSuggestion(
        tag: tag,
        score: score,
        amountUnit: turnover.amountUnit,
      );
    }).toList();
  }
}

/// Internal helper class to accumulate scoring data for a tag.
class _TagScore {
  final Tag tag;
  final List<double> similarities;
  final List<Decimal> amounts;
  final List<DateTime> dates;
  final List<String?> transactionTypes;
  int frequency;

  _TagScore({
    required this.tag,
    required this.similarities,
    required this.amounts,
    required this.dates,
    required this.transactionTypes,
    required this.frequency,
  });
}

class _ScoreAndWeight {
  final double score;
  final double weight;

  _ScoreAndWeight({required this.score, required this.weight});
}
