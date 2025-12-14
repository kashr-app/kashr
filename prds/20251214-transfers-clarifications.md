# Transfers Implementation Clarifications

## Final Decisions (2025-12-14)

### O2: Sign Switching on Linked TagTurnovers
**Decision:** When user attempts to change sign of a turnover whose tagTurnovers are in a Transfer:
- Show dialog informing user they must first manually unlink from Transfer
- Do NOT auto-unlink or provide buttons in dialog
- Rationale: User better understands consequences; rarely happens

### O3: Amount Mismatch Handling
**Decision:**
- Add `confirmedAt: DateTime?` field to Transfer entity
- Derived `confirmed` getter: `confirmed = confirmedAt != null`
- Derived `needsReview` logic:
  - `needsReview = NOT confirmed AND (NOT (currency identical and exact amount match) OR (currency not identical))`
- Dashboard calculations: ALWAYS use `from` side amount
- Do NOT persist `needsReview` - it's computed

### O4: Different Booking Dates
**Decision:** Use `from` side's `tagTurnover.bookingDate` for determining which month
- Rationale: Transfer is single operation from user perspective
- User controls month via tagTurnover.bookingDate (flexible for synced accounts)

### R3: Quick Entry Workflow
**Decision:** Modify `quick_transfer_entry_sheet.dart._submit()`:
1. Create first tagTurnover (from side)
2. Create second tagTurnover (to side)
3. Create Transfer entity linking both
4. Wrap all three inserts in transaction

### R4: Tag Semantic Enforcement
**Decision:**
- Both sides SHOULD have transfer semantics
- Both sides SHOULD have the SAME tag (single operation: "I invest 100€")
- None enforced - only hinted in UI
- Invalid Transfers show in "needs review"
- Rationale: Confusing to see different tags; only `from` used in calculations

### Migration Strategy
**Decision:**
- Existing transfer tagTurnovers NOT auto-matched
- Show in dashboard: "X transfers need review →"
- User manually links or creates missing side

### Database Schema (R1 Solution)
**Decision:** Use normalized many-to-many design (Option 3):

```sql
CREATE TABLE transfer (
  id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  confirmed_at TEXT
);

CREATE TABLE transfer_tag_turnover (
  transfer_id TEXT NOT NULL,
  tag_turnover_id TEXT NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('from', 'to')),
  PRIMARY KEY (transfer_id, role),
  UNIQUE (tag_turnover_id),
  FOREIGN KEY (transfer_id) REFERENCES transfer(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_turnover_id) REFERENCES tag_turnover(id) ON DELETE CASCADE
);
```

**R1 Enforcement:** `UNIQUE(tag_turnover_id)` ensures each tagTurnover used at most once

**R2 Enforcement:** Validate in forms (different accountId); DB constraint not added (complex)

### Tag Deletion Handling (C2)
**Decision:**
- Existing app already checks tag usage before deletion
- User must remove all usage first
- Transfer row deleted via CASCADE when tagTurnover deleted
- No special handling needed

### Transfer Entity Design
```dart
@freezed
abstract class Transfer with _$Transfer {
  const Transfer._();

  const factory Transfer({
    @UUIDJsonConverter() required UuidValue id,
    @UUIDNullableJsonConverter() UuidValue? fromTagTurnoverId,
    @UUIDNullableJsonConverter() UuidValue? toTagTurnoverId,
    required DateTime createdAt,
    DateTime? confirmedAt,
  }) = _Transfer;

  bool get confirmed => confirmedAt != null;

  factory Transfer.fromJson(Map<String, dynamic> json) =>
    _$TransferFromJson(json);
}
```

**Note:** `needsReview` computed in repository layer with access to TagTurnover objects