import 'package:finanalyzer/db/sqlite_compat.dart';

/// Migration v12: Add counter_iban, api_turnover_type, and api_raw columns
///
/// Adds to turnover table:
/// - turnover.counter_iban: The IBAN of the counterparty (nullable)
/// - turnover.api_turnover_type: Type of turnover from API (nullable)
/// - turnover.api_raw: Raw unparsed data from the API (nullable)
///
/// Also updates FTS triggers to include counter_iban in searchable content.
/// Note: api_turnover_type and api_raw are NOT included in FTS.
Future<void> v12(SqliteDatabase db) async {
  // Add new columns to turnover table
  db.execute('ALTER TABLE turnover ADD COLUMN counter_iban TEXT');
  db.execute('ALTER TABLE turnover ADD COLUMN api_turnover_type TEXT');
  db.execute('ALTER TABLE turnover ADD COLUMN api_raw TEXT');

  // Drop existing FTS triggers that need to be updated
  db.execute('DROP TRIGGER IF EXISTS turnover_fts_insert');
  db.execute('DROP TRIGGER IF EXISTS turnover_fts_update');
  db.execute('DROP TRIGGER IF EXISTS tag_turnover_fts_insert');
  db.execute('DROP TRIGGER IF EXISTS tag_turnover_fts_update');
  db.execute('DROP TRIGGER IF EXISTS tag_turnover_fts_delete');
  db.execute('DROP TRIGGER IF EXISTS tag_fts_update');

  // Recreate triggers with counter_iban included in search content

  // Trigger: When a new turnover is inserted
  db.execute('''
    CREATE TRIGGER turnover_fts_insert AFTER INSERT ON turnover
    BEGIN
      INSERT INTO turnover_fts(turnover_id, content)
      SELECT
        NEW.id,
        NEW.purpose || ' ' ||
        COALESCE(NEW.counter_part, '') || ' ' ||
        COALESCE(NEW.counter_iban, '') || ' ' ||
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
  db.execute('''
    CREATE TRIGGER turnover_fts_update AFTER UPDATE ON turnover
    BEGIN
      DELETE FROM turnover_fts WHERE turnover_id = OLD.id;
      INSERT INTO turnover_fts(turnover_id, content)
      SELECT
        NEW.id,
        NEW.purpose || ' ' ||
        COALESCE(NEW.counter_part, '') || ' ' ||
        COALESCE(NEW.counter_iban, '') || ' ' ||
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

  // Trigger: When a tag_turnover is inserted
  db.execute('''
    CREATE TRIGGER tag_turnover_fts_insert AFTER INSERT ON tag_turnover
    BEGIN
      DELETE FROM turnover_fts WHERE turnover_id = NEW.turnover_id;
      INSERT INTO turnover_fts(turnover_id, content)
      SELECT
        t.id,
        t.purpose || ' ' ||
        COALESCE(t.counter_part, '') || ' ' ||
        COALESCE(t.counter_iban, '') || ' ' ||
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

  // Trigger: When a tag_turnover is updated
  db.execute('''
    CREATE TRIGGER tag_turnover_fts_update AFTER UPDATE ON tag_turnover
    BEGIN
      DELETE FROM turnover_fts WHERE turnover_id = NEW.turnover_id;
      INSERT INTO turnover_fts(turnover_id, content)
      SELECT
        t.id,
        t.purpose || ' ' ||
        COALESCE(t.counter_part, '') || ' ' ||
        COALESCE(t.counter_iban, '') || ' ' ||
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

  // Trigger: When a tag_turnover is deleted
  db.execute('''
    CREATE TRIGGER tag_turnover_fts_delete AFTER DELETE ON tag_turnover
    BEGIN
      DELETE FROM turnover_fts WHERE turnover_id = OLD.turnover_id;
      INSERT INTO turnover_fts(turnover_id, content)
      SELECT
        t.id,
        t.purpose || ' ' ||
        COALESCE(t.counter_part, '') || ' ' ||
        COALESCE(t.counter_iban, '') || ' ' ||
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

  // Trigger: When a tag is updated (name changed)
  db.execute('''
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
        COALESCE(t.counter_iban, '') || ' ' ||
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

  // Rebuild FTS index to include counter_iban for existing turnovers
  db.execute('DELETE FROM turnover_fts');
  db.execute('''
    INSERT INTO turnover_fts(turnover_id, content)
    SELECT
      t.id,
      t.purpose || ' ' ||
      COALESCE(t.counter_part, '') || ' ' ||
      COALESCE(t.counter_iban, '') || ' ' ||
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
}
