import 'package:sqflite/sqflite.dart';

/// Migration v11: Create FTS5 virtual table for full-text search
///
/// Creates a turnover_fts table that indexes:
/// - turnover.purpose
/// - turnover.counter_part
/// - All tag names associated with the turnover (via tag_turnover)
/// - All notes from tag_turnovers associated with the turnover
///
/// The FTS table combines all searchable text into a single 'content' column
/// for efficient searching.
Future<void> v11(Database db) async {
  // Create FTS5 virtual table for turnover search
  // Using tokenize='unicode61' with remove_diacritics for accent-insensitive search
  await db.execute('''
    CREATE VIRTUAL TABLE turnover_fts USING fts5(
      turnover_id UNINDEXED,
      content,
      tokenize='unicode61 remove_diacritics 1'
    )
  ''');

  // Populate the FTS table with existing data
  // For each turnover, combine:
  // - purpose
  // - counter_part
  // - all associated tag names
  // - all associated tag_turnover notes
  await db.execute('''
    INSERT INTO turnover_fts(turnover_id, content)
    SELECT
      t.id,
      t.purpose || ' ' ||
      COALESCE(t.counter_part, '') || ' ' ||
      COALESCE(
        (SELECT GROUP_CONCAT(tag.name, ' ')
         FROM tag_turnover tt
         LEFT JOIN tag ON tt.tag_id = tag.id
         WHERE tt.turnover_id = t.id),
        ''
      ) || ' ' ||
      COALESCE(
        (SELECT GROUP_CONCAT(COALESCE(tt.note, ''), ' ')
         FROM tag_turnover tt
         WHERE tt.turnover_id = t.id),
        ''
      ) AS content
    FROM turnover t
  ''');

  // Create triggers to keep FTS table in sync with turnover table

  // Trigger: When a new turnover is inserted
  await db.execute('''
    CREATE TRIGGER turnover_fts_insert AFTER INSERT ON turnover
    BEGIN
      INSERT INTO turnover_fts(turnover_id, content)
      SELECT
        NEW.id,
        NEW.purpose || ' ' ||
        COALESCE(NEW.counter_part, '') || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(tag.name, ' ')
           FROM tag_turnover tt
           LEFT JOIN tag ON tt.tag_id = tag.id
           WHERE tt.turnover_id = NEW.id),
          ''
        ) || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(COALESCE(tt.note, ''), ' ')
           FROM tag_turnover tt
           WHERE tt.turnover_id = NEW.id),
          ''
        );
    END
  ''');

  // Trigger: When a turnover is updated
  await db.execute('''
    CREATE TRIGGER turnover_fts_update AFTER UPDATE ON turnover
    BEGIN
      DELETE FROM turnover_fts WHERE turnover_id = OLD.id;
      INSERT INTO turnover_fts(turnover_id, content)
      SELECT
        NEW.id,
        NEW.purpose || ' ' ||
        COALESCE(NEW.counter_part, '') || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(tag.name, ' ')
           FROM tag_turnover tt
           LEFT JOIN tag ON tt.tag_id = tag.id
           WHERE tt.turnover_id = NEW.id),
          ''
        ) || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(COALESCE(tt.note, ''), ' ')
           FROM tag_turnover tt
           WHERE tt.turnover_id = NEW.id),
          ''
        );
    END
  ''');

  // Trigger: When a turnover is deleted
  await db.execute('''
    CREATE TRIGGER turnover_fts_delete AFTER DELETE ON turnover
    BEGIN
      DELETE FROM turnover_fts WHERE turnover_id = OLD.id;
    END
  ''');

  // Trigger: When a tag_turnover is inserted/updated/deleted, update the FTS entry
  await db.execute('''
    CREATE TRIGGER tag_turnover_fts_insert AFTER INSERT ON tag_turnover
    BEGIN
      DELETE FROM turnover_fts WHERE turnover_id = NEW.turnover_id;
      INSERT INTO turnover_fts(turnover_id, content)
      SELECT
        t.id,
        t.purpose || ' ' ||
        COALESCE(t.counter_part, '') || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(tag.name, ' ')
           FROM tag_turnover tt
           LEFT JOIN tag ON tt.tag_id = tag.id
           WHERE tt.turnover_id = t.id),
          ''
        ) || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(COALESCE(tt.note, ''), ' ')
           FROM tag_turnover tt
           WHERE tt.turnover_id = t.id),
          ''
        )
      FROM turnover t
      WHERE t.id = NEW.turnover_id;
    END
  ''');

  await db.execute('''
    CREATE TRIGGER tag_turnover_fts_update AFTER UPDATE ON tag_turnover
    BEGIN
      DELETE FROM turnover_fts WHERE turnover_id = NEW.turnover_id;
      INSERT INTO turnover_fts(turnover_id, content)
      SELECT
        t.id,
        t.purpose || ' ' ||
        COALESCE(t.counter_part, '') || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(tag.name, ' ')
           FROM tag_turnover tt
           LEFT JOIN tag ON tt.tag_id = tag.id
           WHERE tt.turnover_id = t.id),
          ''
        ) || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(COALESCE(tt.note, ''), ' ')
           FROM tag_turnover tt
           WHERE tt.turnover_id = t.id),
          ''
        )
      FROM turnover t
      WHERE t.id = NEW.turnover_id;
    END
  ''');

  await db.execute('''
    CREATE TRIGGER tag_turnover_fts_delete AFTER DELETE ON tag_turnover
    BEGIN
      DELETE FROM turnover_fts WHERE turnover_id = OLD.turnover_id;
      INSERT INTO turnover_fts(turnover_id, content)
      SELECT
        t.id,
        t.purpose || ' ' ||
        COALESCE(t.counter_part, '') || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(tag.name, ' ')
           FROM tag_turnover tt
           LEFT JOIN tag ON tt.tag_id = tag.id
           WHERE tt.turnover_id = t.id),
          ''
        ) || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(COALESCE(tt.note, ''), ' ')
           FROM tag_turnover tt
           WHERE tt.turnover_id = t.id),
          ''
        )
      FROM turnover t
      WHERE t.id = OLD.turnover_id;
    END
  ''');

  // Trigger: When a tag is updated (name changed), update FTS for all related turnovers
  await db.execute('''
    CREATE TRIGGER tag_fts_update AFTER UPDATE ON tag
    BEGIN
      DELETE FROM turnover_fts
      WHERE turnover_id IN (
        SELECT DISTINCT turnover_id
        FROM tag_turnover
        WHERE tag_id = NEW.id
      );

      INSERT INTO turnover_fts(turnover_id, content)
      SELECT
        t.id,
        t.purpose || ' ' ||
        COALESCE(t.counter_part, '') || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(tag.name, ' ')
           FROM tag_turnover tt
           LEFT JOIN tag ON tt.tag_id = tag.id
           WHERE tt.turnover_id = t.id),
          ''
        ) || ' ' ||
        COALESCE(
          (SELECT GROUP_CONCAT(COALESCE(tt.note, ''), ' ')
           FROM tag_turnover tt
           WHERE tt.turnover_id = t.id),
          ''
        )
      FROM turnover t
      WHERE t.id IN (
        SELECT DISTINCT turnover_id
        FROM tag_turnover
        WHERE tag_id = NEW.id
      );
    END
  ''');

  // Create table for storing recent search queries
  await db.execute('''
    CREATE TABLE recent_search (
      id TEXT PRIMARY KEY,
      query TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL
    )
  ''');
}
