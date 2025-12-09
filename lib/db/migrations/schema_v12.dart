import 'package:finanalyzer/backup/model/backup_config.dart';
import 'package:finanalyzer/db/sqlite_compat.dart';

/// Creates the full database schema at version 12.
///
/// This is used for new installations to avoid running all incremental
/// migrations. The schema here should match the result of applying all
/// migrations from v1 to v12.
Future<void> createSchemaV12(SqliteDatabase db) async {
  // Account table
  db.execute('''
    CREATE TABLE account(
      id TEXT PRIMARY KEY,
      created_at TEXT NOT NULL,
      name TEXT NOT NULL,
      identifier TEXT,
      api_id TEXT,
      account_type TEXT NOT NULL,
      sync_source TEXT,
      currency TEXT NOT NULL,
      opening_balance INTEGER NOT NULL,
      opening_balance_date TEXT NOT NULL,
      is_hidden INTEGER NOT NULL
    )
  ''');

  // Turnover table
  db.execute('''
    CREATE TABLE turnover(
      id TEXT PRIMARY KEY,
      created_at TEXT NOT NULL,
      account_id TEXT NOT NULL,
      booking_date TEXT,
      amount_value INTEGER NOT NULL,
      amount_unit TEXT NOT NULL,
      counter_part TEXT,
      counter_iban TEXT,
      purpose TEXT NOT NULL,
      api_id TEXT,
      api_turnover_type TEXT,
      api_raw TEXT,
      FOREIGN KEY(account_id) REFERENCES account(id)
    )
  ''');

  // Tag table
  db.execute('''
    CREATE TABLE tag (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      color TEXT,
      semantic TEXT
    )
  ''');

  // Tag turnover table
  db.execute('''
    CREATE TABLE tag_turnover(
      id TEXT PRIMARY KEY,
      turnover_id TEXT,
      tag_id TEXT NOT NULL,
      amount_value INTEGER NOT NULL,
      amount_unit TEXT NOT NULL,
      note TEXT,
      created_at TEXT NOT NULL,
      booking_date TEXT NOT NULL,
      account_id TEXT NOT NULL,
      recurring_rule_id TEXT,
      FOREIGN KEY(turnover_id) REFERENCES turnover(id),
      FOREIGN KEY(tag_id) REFERENCES tag(id)
    )
  ''');

  // Savings table
  db.execute('''
    CREATE TABLE savings (
      id TEXT PRIMARY KEY,
      tag_id TEXT NOT NULL UNIQUE,
      goal_value INTEGER,
      goal_unit TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY(tag_id) REFERENCES tag(id) ON DELETE CASCADE
    )
  ''');

  // Savings virtual booking table
  db.execute('''
    CREATE TABLE savings_virtual_booking (
      id TEXT PRIMARY KEY,
      savings_id TEXT NOT NULL,
      account_id TEXT NOT NULL,
      amount_value INTEGER NOT NULL,
      amount_unit TEXT NOT NULL,
      note TEXT,
      booking_date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY(savings_id) REFERENCES savings(id) ON DELETE CASCADE,
      FOREIGN KEY(account_id) REFERENCES account(id) ON DELETE CASCADE
    )
  ''');

  // Backup config table
  db.execute('''
    CREATE TABLE backup_config (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      auto_backup_enabled INTEGER NOT NULL,
      frequency TEXT NOT NULL,
      last_auto_backup TEXT,
      encryption_enabled INTEGER NOT NULL,
      max_local_backups INTEGER NOT NULL,
      auto_backup_to_cloud INTEGER NOT NULL
    )
  ''');

  // Insert default backup config
  db.insert('backup_config', BackupConfig.defaultConfig().toJson());

  // FTS5 virtual table for full-text search
  db.execute('''
    CREATE VIRTUAL TABLE turnover_fts USING fts5(
      turnover_id UNINDEXED,
      content,
      tokenize='unicode61 remove_diacritics 1'
    )
  ''');

  // Recent search table
  db.execute('''
    CREATE TABLE recent_search (
      id TEXT PRIMARY KEY,
      query TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL
    )
  ''');

  // Create indices
  db.execute(
    'CREATE INDEX idx_tag_turnover_account ON tag_turnover(account_id)',
  );
  db.execute(
    'CREATE INDEX idx_tag_turnover_booking_date ON tag_turnover(booking_date)',
  );
  db.execute('''
    CREATE INDEX idx_tag_turnover_unmatched
      ON tag_turnover(turnover_id)
      WHERE turnover_id IS NULL
  ''');
  db.execute(
    'CREATE INDEX idx_savings_virtual_booking_account_id ON savings_virtual_booking(account_id)',
  );
  db.execute(
    'CREATE INDEX idx_savings_virtual_booking_savings_id ON savings_virtual_booking(savings_id)',
  );

  // Create FTS triggers to keep turnover_fts in sync

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

  // Trigger: When a turnover is deleted
  db.execute('''
    CREATE TRIGGER turnover_fts_delete AFTER DELETE ON turnover
    BEGIN
      DELETE FROM turnover_fts WHERE turnover_id = OLD.id;
    END
  ''');

  // Trigger: When a tag_turnover is inserted/updated/deleted, update the FTS entry
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

  // Trigger: When a tag is updated (name changed), update FTS for all related turnovers
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
}
