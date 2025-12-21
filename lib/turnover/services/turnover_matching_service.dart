import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

// up to this count of days tag turnovers are considered candidates for a match.
const dateMatchingWindow = 7;

class TurnoverMatchingService {
  final TagTurnoverRepository _tagTurnoverRepository;
  final TurnoverRepository _turnoverRepository;

  final log = Logger();

  TurnoverMatchingService(
    this._tagTurnoverRepository,
    this._turnoverRepository,
  );

  (DateTime startDate, DateTime endDate) _calcMatchingWindow(
    DateTime bookingDate,
  ) {
    // Get unmatched TagTurnovers in time window
    final startDate = bookingDate.subtract(
      const Duration(days: dateMatchingWindow),
    );
    final endDate = bookingDate.add(const Duration(days: dateMatchingWindow));
    return (startDate, endDate);
  }

  /// Find potential matches for a turnover
  /// Returns list sorted by confidence (highest first)
  Future<List<TagTurnoverMatch>> findMatchesForTurnover(
    Turnover turnover,
  ) async {
    final bookingDate =
        turnover.bookingDate ??
        DateTime.now() /* we expect a turnover without a booking date to be booked very soon,
                          so now() is a good fallback for the algorithm. */;

    final (startDate, endDate) = _calcMatchingWindow(bookingDate);

    final candidates = await _tagTurnoverRepository.getUnmatched(
      accountId: turnover.accountId,
      startDate: startDate,
      endDate: endDate,
    );

    return _calcMatches([turnover], candidates);
  }

  /// Find potential matches for a tag turnover
  /// Returns list sorted by confidence (highest first)
  /// Only considers turnovers with no existing tag_turnover allocations
  /// (1:1 matching semantics). Turnovers cannot be partially matched
  /// becuse that could easily confuse users. Instead we assume that if
  /// a turnover has already some allocation it was manually handeled by
  /// the user and hence they should continue manually.
  Future<List<TagTurnoverMatch>> findMatchesForTagTurnover(
    TagTurnover tagTurnover,
  ) async {
    final bookingDate = tagTurnover.bookingDate;

    final (startDate, endDate) = _calcMatchingWindow(bookingDate);

    final candidates = await _turnoverRepository
        .getUnmatchedTurnoversForAccount(
          accountId: tagTurnover.accountId,
          startDateInclusive: startDate,
          endDateInclusive: endDate,
        );

    return _calcMatches(candidates, [tagTurnover]);
  }

  List<TagTurnoverMatch> _calcMatches(
    List<Turnover> turnovers,
    List<TagTurnover> tts,
  ) {
    final matches = <TagTurnoverMatch>[];

    for (final turnover in turnovers) {
      for (final tagTurnover in tts) {
        final confidence = _calculateConfidence(tagTurnover, turnover);

        if (confidence >= 0.6) {
          matches.add(
            TagTurnoverMatch(
              tagTurnover: tagTurnover,
              turnover: turnover,
              confidence: confidence,
            ),
          );
        }
      }
    }

    // Sort by confidence (highest first)
    matches.sort((a, b) => b.confidence.compareTo(a.confidence));
    return matches;
  }

  /// Confirm a match: link TagTurnover to Turnover
  Future<void> confirmMatch(TagTurnoverMatch match) async {
    await _tagTurnoverRepository.allocateToTurnover(
      match.tagTurnover.id,
      match.turnover.id,
    );
  }

  /// Auto-match if perfect match (exact amount + high confidence)
  /// Returns the match if auto-matched or null
  Future<TagTurnoverMatch?> autoMatchPerfectTurnover(
    TagTurnover tagTurnover,
  ) async {
    if (tagTurnover.isMatched) {
      log.e('Trying to match a TagTurnover that is already matched');
      return null;
    }
    final matches = await findMatchesForTagTurnover(tagTurnover);
    return _autoConfirmPerfectMatch(matches);
  }

  /// Auto-match if perfect match (exact amount + high confidence)
  ///
  /// By default it prevents matching turnovers that are not unmatched
  /// (i.e. at least one TagTurnover exists that references it) by
  /// running another db call. If you can guarantee that the [turnover]
  /// is unmatched, set [isGuaranteedToBeUnmatched] to true to skip the db call.
  ///
  /// Returns the match if auto-matched or null
  Future<TagTurnoverMatch?> autoMatchPerfectTagTurnover(
    Turnover turnover, {
    isGuaranteedToBeUnmatched = false,
  }) async {
    if (!isGuaranteedToBeUnmatched) {
      final ids = await _turnoverRepository.filterUnmatched(
        turnoverIds: [turnover.id],
      );
      if (ids.isEmpty) {
        log.e(
          'Trying to match a Turnover that is not matched (i.e. at least one TagTurnover exists that references it.)',
        );
        return null;
      }
    }
    final matches = await findMatchesForTurnover(turnover);
    return _autoConfirmPerfectMatch(matches);
  }

  // Only auto-match if:
  // 1. Exactly one match found
  // 3. Confidence >= 95%
  // 2. Exact amount match
  Future<TagTurnoverMatch?> _autoConfirmPerfectMatch(
    List<TagTurnoverMatch> matches,
  ) async {
    if (matches.length != 1) return null;
    final match = matches.first;

    if (match.confidence < 0.95) return null;

    if (match.tagTurnover.amountValue != match.turnover.amountValue) {
      return null;
    }
    await confirmMatch(matches.first);
    return (match);
  }

  /// Unlink a matched TagTurnover from its Turnover
  /// Returns true if successfully unlinked
  Future<bool> unmatch(UuidValue tagTurnoverId) async {
    final tagTurnover = await _tagTurnoverRepository.getById(tagTurnoverId);

    if (tagTurnover == null || tagTurnover.turnoverId == null) {
      return false;
    }

    await _tagTurnoverRepository.unallocateFromTurnover(tagTurnoverId);
    return true;
  }

  /// Calculate match confidence between a TagTurnover and Turnover (0.0 - 1.0)
  ///
  /// IMPORTANT: This method assumes 1:1 matching semantics:
  /// - The TagTurnover must be unmatched (turnoverId == null)
  /// - The Turnover must be unmatched (no associated tag_turnover entries)
  ///
  /// The confidence calculation directly compares tt.amountValue with
  /// t.amountValue. This is only semantically correct when both entities are
  /// completely unallocated. Partially allocated turnovers should NOT be
  /// included in matching, as this would make auto-matching unpredictable
  /// and confusing for users.
  ///
  /// The confidence is calculated using:
  /// - Amount match (50% weight): How closely the amounts match
  /// - Date proximity (50% weight): How close the booking dates are
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
  final TagTurnover tagTurnover;
  final Turnover turnover;
  final double confidence; // 0.0 - 1.0

  TagTurnoverMatch({
    required this.tagTurnover,
    required this.turnover,
    required this.confidence,
  });
}
