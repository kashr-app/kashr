import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:uuid/uuid.dart';

/// Represents a change to tag turnovers in the repository.
///
/// This sealed class hierarchy is used to notify listeners of data
/// changes without requiring them to reload all data.
sealed class TagTurnoverChange {
  const TagTurnoverChange();
}

/// Indicates that one or more tag turnovers were inserted.
class TagTurnoversInserted extends TagTurnoverChange {
  const TagTurnoversInserted(this.tagTurnovers);

  final List<TagTurnover> tagTurnovers;
}

/// Indicates that one or more tag turnovers were updated.
class TagTurnoversUpdated extends TagTurnoverChange {
  const TagTurnoversUpdated(this.tagTurnovers);

  final List<TagTurnover> tagTurnovers;
}

/// Indicates that one or more tag turnovers were deleted.
class TagTurnoversDeleted extends TagTurnoverChange {
  const TagTurnoversDeleted(this.ids);

  final List<UuidValue> ids;
}
