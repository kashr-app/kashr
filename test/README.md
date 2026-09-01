# Tests

Some tests in here **fail on purpose**. They are the proof that a known bug
produces user-visible wrong numbers, written before the fix so the fix has
something to turn green. Do not "fix" them by changing the assertions.

## The bug they prove

`booking_date` is stored as a full ISO-8601 timestamp
(`2026-09-30T00:00:00.000`), but every SQL date bound is a date-only
`yyyy-MM-dd` string. SQLite compares TEXT lexicographically, and
`'2026-09-30T00:00:00.000' > '2026-09-30'`, so **the whole boundary day falls
outside every range**. 13 query sites are affected.

`Period` has the same class of bug: `Period.of` builds `endExclusive` as the
last day at 23:59 while `Period.add` builds it as the first of the next month,
so the same month yields different totals depending on how the user navigated
to it.

## Currently failing

| Test | Expected | Actual |
| --- | --- | --- |
| `account_cubit_test.dart` | projected balance `62` | `77` — the last day's turnover and pending expense are both missing |
| `turnover_matching_service_test.dart` — both tests | the ±7-day match window reaches both edges | it reaches −7 but only +6 |

## The harness

`useInMemoryDatabase()` gives each test a real SQLite database, migrated by the
production migration chain, installed where the repositories look for one.
Nothing is faked: this bug lives in SQL, so a test that faked a repository
would pass while the app stayed wrong. `test/db/db_helper_test.dart` is the
canary — if it is red, every other failure in here is meaningless.

## For the fix pass

- Half-open `[startInclusive, endExclusive)` is the default rule, not a
  mandate. Names must state their intent: `endExclusive`, `endInclusive`,
  `startExclusive`.
- `asOf` on `BalanceCalculationService` needs renaming — it does not say
  whether the date itself is included. `AccountCubit` passes end-of-month
  23:59 into it meaning *inclusive*.
- Two disagreements survive the string fix: `sumTurnoversForAccount` (`<=`,
  `endDateInclusive`) vs `TagTurnoverRepository.getUnmatched` (`<`, `endDate`),
  both fed the same value by `BalanceCalculationService`; and the `Period.of`
  vs `Period.add` split above.
- All 13 sites share one root: `DateTimeExt.isoDate` used for both ends of
  every range.
- If pinned month-boundary tests are wanted, inject a `DateTime Function() now`
  into `AccountCubit` and `DashboardCubit` and drop the derived dates from
  `test/helpers/test_app.dart`.
