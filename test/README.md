# Tests

## The harness

`useInMemoryDatabase()` gives each test a real SQLite database, migrated by the
production migration chain, installed where the repositories look for one.
Nothing is faked: this class of bug lives in SQL, so a test that faked a
repository would pass while the app stayed wrong. `test/db/db_helper_test.dart`
is the canary — if it is red, every other failure in here is meaningless.

## Half-open date ranges

`booking_date` is stored as a full ISO-8601 timestamp (`2026-09-30T00:00:00.000`)
in a TEXT column, while every SQL bound is a date-only `yyyy-MM-dd` string.
SQLite compares TEXT lexicographically, so `'2026-09-30T00:00:00.000'` sorts
*after* `'2026-09-30'`: an inclusive upper bound written that way silently drops
the entire boundary day.

Date ranges are therefore half-open — `>= startInclusive AND < endExclusive` —
and parameter names say which end they are. `endInclusive` stays legal where it
genuinely reads better, such as the last day in a week label, but it is the
exception and must be named as one.

The tests under `account/`, `dashboard/` and `turnover/services/` were written
red against the old behaviour and are the proof it stays fixed. They assert
user-visible numbers — a projected balance, a month's totals, both edges of the
match window — rather than query internals, so they should survive refactoring.
