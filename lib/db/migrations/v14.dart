import 'package:kashr/db/sqlite_compat.dart';

/// Migration v14: Add transfer tracking and TagTurnover full text search
///
/// - Creates counter_part field for tag_turnover.
/// - Introduces tag_turnover_fts
/// - Introduces explicit Transfer entity to track transfers between accounts.
///   See prds/20251214-transfers.md for full specification.
Future<void> v14(SqliteDatabase db) async {
  // add counter_part to tag_turnover
  await db.execute('''
    ALTER TABLE tag_turnover ADD COLUMN counter_part TEXT
  ''');
  await db.execute('''
    UPDATE tag_turnover
    SET counter_part = t.counter_part
    FROM turnover t
    WHERE tag_turnover.turnover_id = t.id
  ''');

  await _renameTurnoverFTSTriggers(db);
  await _setupTagTurnoverFTS(db);

  // Transfer table - links two tagTurnovers representing a transfer
  await db.execute('''
    CREATE TABLE transfer(
      id TEXT PRIMARY KEY,
      created_at TEXT NOT NULL,
      confirmed_at TEXT
    )
  ''');

  // Transfer-TagTurnover junction table with role enforcement
  // Enforces R1: each tagTurnover used at most once via UNIQUE constraint
  await db.execute('''
    CREATE TABLE transfer_tag_turnover(
      transfer_id TEXT NOT NULL,
      tag_turnover_id TEXT NOT NULL,
      role TEXT NOT NULL CHECK(role IN ('from', 'to')),
      PRIMARY KEY (transfer_id, role),
      UNIQUE (tag_turnover_id),
      FOREIGN KEY (transfer_id) REFERENCES transfer(id) ON DELETE CASCADE,
      FOREIGN KEY (tag_turnover_id) REFERENCES tag_turnover(id) ON DELETE CASCADE
    )
  ''');

  // Index for efficient queries by tag_turnover_id
  await db.execute('''
    CREATE INDEX idx_transfer_tag_turnover_tag_turnover_id
      ON transfer_tag_turnover(tag_turnover_id)
  ''');
}

/// Some of the FTS triggers to keep turnover_fts in sync have been named based
/// on the table where they are created but this collides if multiple FTS
/// tables exist that also want to set triggers on these tables.
///
/// keeps all turnover_fts triggers on turnover table
/// renames all other triggers by this naming pattern: `[context]_fts_[table]_[operation]`:
/// - tag_turnover_fts_insert => turnover_fts_tag_turnover_insert
/// - tag_turnover_fts_update => turnover_fts_tag_turnover_update
/// - tag_turnover_fts_delete => turnover_fts_tag_turnover_delete
/// - tag_fts_update => turnover_fts_tag_update
Future<void> _renameTurnoverFTSTriggers(SqliteDatabase db) async {
  await db.execute('DROP TRIGGER IF EXISTS tag_turnover_fts_insert');
  await db.execute('DROP TRIGGER IF EXISTS tag_turnover_fts_update');
  await db.execute('DROP TRIGGER IF EXISTS tag_turnover_fts_delete');
  await db.execute('DROP TRIGGER IF EXISTS tag_fts_update');

  String insert(String tableName) =>
      '''
      INSERT INTO turnover_fts(turnover_id, content)
      SELECT
        $tableName.id,
        $tableName.purpose || ' ' ||
        COALESCE($tableName.counter_part, '') || ' ' ||
        COALESCE($tableName.counter_iban, '') || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(tag.name, ' ')
           FROM tag_turnover tt
           LEFT JOIN tag ON tt.tag_id = tag.id
           WHERE tt.turnover_id = $tableName.id),
          ''
        ) || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(COALESCE(tt.note, ''), ' ')
           FROM tag_turnover tt
           WHERE tt.turnover_id = $tableName.id),
          ''
        )
  ''';

  await db.execute('''
    CREATE TRIGGER turnover_fts_tag_turnover_insert AFTER INSERT ON tag_turnover
    BEGIN
      DELETE FROM turnover_fts WHERE turnover_id = NEW.turnover_id;
      ${insert('t')}
      FROM turnover t
      WHERE t.id = NEW.turnover_id;
    END
  ''');

  await db.execute('''
    CREATE TRIGGER turnover_fts_tag_turnover_update AFTER UPDATE ON tag_turnover
    BEGIN
      DELETE FROM turnover_fts WHERE turnover_id = NEW.turnover_id;
      ${insert('t')}
      FROM turnover t
      WHERE t.id = NEW.turnover_id;
    END
  ''');

  await db.execute('''
    CREATE TRIGGER turnover_fts_tag_turnover_delete AFTER DELETE ON tag_turnover
    BEGIN
      DELETE FROM turnover_fts WHERE turnover_id = OLD.turnover_id;
      ${insert('t')}
      FROM turnover t
      WHERE t.id = OLD.turnover_id;
    END
  ''');

  // Trigger: When a tag is updated (name changed), update FTS for all related turnovers
  await db.execute('''
    CREATE TRIGGER turnover_fts_tag_update AFTER UPDATE ON tag
    BEGIN
      DELETE FROM turnover_fts
      WHERE turnover_id IN (
        SELECT DISTINCT turnover_id
        FROM tag_turnover
        WHERE tag_id = NEW.id
      );

      ${insert('t')}
      FROM turnover t
      WHERE t.id IN (
        SELECT DISTINCT turnover_id
        FROM tag_turnover
        WHERE tag_id = NEW.id
      );
    END
  ''');
}

Future<void> _setupTagTurnoverFTS(SqliteDatabase db) async {
  // FTS5 virtual table for full-text search
  await db.execute('''
    CREATE VIRTUAL TABLE tag_turnover_fts USING fts5(
      tag_turnover_id UNINDEXED,
      content,
      tokenize='unicode61 remove_diacritics 1'
    )
  ''');

  // Helper function to generate FTS insert statement
  String insert(String ttName) =>
      '''
      INSERT INTO tag_turnover_fts(tag_turnover_id, content)
      SELECT
        $ttName.id,
        COALESCE($ttName.note, '') || ' ' ||
        COALESCE($ttName.counter_part, '') || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(name, ' ')
           FROM tag
           WHERE id = $ttName.tag_id),
          ''
        )
  ''';

  // Backfill existing tag_turnover records into FTS
  await db.execute('''
    ${insert('tt')}
    FROM tag_turnover tt
  ''');

  // Create FTS triggers to keep tag_turnover_fts in sync

  // Trigger: When a tag_turnover is inserted/updated/deleted, update the FTS entry
  await db.execute('''
    CREATE TRIGGER tag_turnover_fts_insert AFTER INSERT ON tag_turnover
    BEGIN
      ${insert('NEW')};
    END
  ''');

  await db.execute('''
    CREATE TRIGGER tag_turnover_fts_update AFTER UPDATE ON tag_turnover
    BEGIN
      DELETE FROM tag_turnover_fts WHERE tag_turnover_id = OLD.id;
      ${insert('NEW')};
    END
  ''');

  await db.execute('''
    CREATE TRIGGER tag_turnover_fts_delete AFTER DELETE ON tag_turnover
    BEGIN
      DELETE FROM tag_turnover_fts WHERE tag_turnover_id = OLD.id;
    END
  ''');

  // Trigger: When a tag is updated (name changed), update FTS for all related tag_turnovers
  await db.execute('''
    CREATE TRIGGER tag_turnover_fts_tag_update AFTER UPDATE ON tag
    BEGIN
      DELETE FROM tag_turnover_fts
      WHERE tag_turnover_id IN (
        SELECT DISTINCT id
        FROM tag_turnover
        WHERE tag_id = NEW.id
      );

      ${insert('tt')}
      FROM tag_turnover tt
      WHERE tt.id IN (
        SELECT DISTINCT id
        FROM tag_turnover
        WHERE tag_id = NEW.id
      );
    END
  ''');
}
