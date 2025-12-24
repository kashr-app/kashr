import 'package:kashr/turnover/model/turnover.dart';
import 'package:uuid/uuid.dart';

/// Represents a change to turnovers in the repository.
///
/// This sealed class hierarchy is used to notify listeners of data
/// changes without requiring them to reload all data.
sealed class TurnoverChange {
  const TurnoverChange();
}

/// Indicates that one or more turnovers were inserted.
class TurnoversInserted extends TurnoverChange {
  const TurnoversInserted(this.turnovers);

  final List<Turnover> turnovers;
}

/// Indicates that one or more turnovers were updated.
class TurnoversUpdated extends TurnoverChange {
  const TurnoversUpdated(this.turnovers);

  final List<Turnover> turnovers;
}

/// Indicates that one or more turnovers were deleted.
class TurnoversDeleted extends TurnoverChange {
  const TurnoversDeleted(this.ids);

  final List<UuidValue> ids;
}
