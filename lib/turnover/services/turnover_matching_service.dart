import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:uuid/uuid.dart';

// up to this count of days tag turnovers are considered candidates for a match.
const dateMatchingWindow = 7;

class TurnoverMatchingService {
  final TagTurnoverRepository _tagTurnoverRepository;

  TurnoverMatchingService(this._tagTurnoverRepository);

  /// Find potential matches for a synced turnover
  /// Returns list sorted by confidence (highest first)
  Future<List<TagTurnoverMatch>> findMatches(Turnover syncedTurnover) async {
    final bookingDate =
        syncedTurnover.bookingDate ??
        DateTime.now() /* we expect a synced turnover without a booking date to be booked very soon,
                          so now() is a good fallback for the algorithm. */;

    // Get unmatched TagTurnovers in time window
    final startDate = bookingDate.subtract(
      const Duration(days: dateMatchingWindow),
    );
    final endDate = bookingDate.add(const Duration(days: dateMatchingWindow));

    final candidates = await _tagTurnoverRepository.getUnmatched(
      accountId: syncedTurnover.accountId,
      startDate: startDate,
      endDate: endDate,
    );

    final matches = <TagTurnoverMatch>[];

    for (final tagTurnover in candidates) {
      final confidence = _calculateConfidence(tagTurnover, syncedTurnover);

      if (confidence >= 0.6) {
        matches.add(
          TagTurnoverMatch(
            tagTurnoverId: tagTurnover.id!,
            turnoverId: syncedTurnover.id!,
            confidence: confidence,
          ),
        );
      }
    }

    // Sort by confidence (highest first)
    matches.sort((a, b) => b.confidence.compareTo(a.confidence));
    return matches;
  }

  /// Confirm a match: link TagTurnover to Turnover
  Future<void> confirmMatch(TagTurnoverMatch match) async {
    await _tagTurnoverRepository.linkToTurnover(
      match.tagTurnoverId,
      match.turnoverId,
    );
  }

  /// Auto-match if perfect match (exact amount + high confidence)
  /// Returns true if auto-matched
  Future<bool> autoMatchPerfect(Turnover syncedTurnover) async {
    final matches = await findMatches(syncedTurnover);

    if (matches.isEmpty) return false;

    // Only auto-match if:
    // 1. Exactly one match found
    // 2. Exact amount match
    // 3. Confidence >= 95%
    if (matches.length == 1 && matches.first.confidence >= 0.95) {
      // Get the TagTurnover to check for exact amount
      final tagTurnover = await _tagTurnoverRepository.getById(
        matches.first.tagTurnoverId,
      );

      if (tagTurnover != null && tagTurnover.amountValue == syncedTurnover.amountValue) {
        await confirmMatch(matches.first);
        return true;
      }
    }

    return false;
  }

  /// Unlink a matched TagTurnover from its Turnover
  /// Returns true if successfully unlinked
  Future<bool> unmatch(UuidValue tagTurnoverId) async {
    final tagTurnover = await _tagTurnoverRepository.getById(tagTurnoverId);

    if (tagTurnover == null || tagTurnover.turnoverId == null) {
      return false;
    }

    await _tagTurnoverRepository.unlinkFromTurnover(tagTurnoverId);
    return true;
  }

  /// Calculate match confidence (0.0 - 1.0)
  double _calculateConfidence(TagTurnover tt, Turnover t) {
    double confidence = 0.0;

    // Amount match (50% weight)
    final amountWeight = 0.5;
    final amountDiff = (tt.amountValue - t.amountValue).abs();
    final amountRatio = amountDiff / t.amountValue.abs();
    confidence += (1.0 - amountRatio.toDouble()).clamp(0.0, 1.0) * amountWeight;

    // Date proximity (50% weight)
    final dateWeight = 0.5;
    final daysDiff = tt.bookingDate.difference(t.bookingDate!).inDays.abs();
    final dateSimilarity =
        (dateMatchingWindow - daysDiff) / dateMatchingWindow.toDouble();
    confidence += dateSimilarity.clamp(0.0, 1.0) * dateWeight;

    return confidence.clamp(0.0, 1.0);
  }
}

/// Represents a potential match between TagTurnover and Turnover
class TagTurnoverMatch {
  final UuidValue tagTurnoverId;
  final UuidValue turnoverId;
  final double confidence; // 0.0 - 1.0

  TagTurnoverMatch({
    required this.tagTurnoverId,
    required this.turnoverId,
    required this.confidence,
  });
}
