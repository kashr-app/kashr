# Tests

## The harness

`useInMemoryDatabase()` gives each test a real SQLite database, migrated by the
production migration chain, installed where the repositories look for one.
Nothing is faked: this class of bug lives in SQL, so a test that faked a
repository would pass while the app stayed wrong. `test/db/db_helper_test.dart`
is the canary — if it is red, every other failure in here is meaningless.
