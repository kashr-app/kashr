# Decrypt Tool

## What this is

This tool allows to decypt backup files of the Kashr app.

## Instructions

### Installation

```bash
docker build -t decrypt-backup .
```

or use the python script directly, which would require:

- Python 3.6 or higher
- cryptography library
- openssl 3.2+

### Usage

```bash
docker run --user $(id -u):$(id -g) --rm -it -v $(pwd):/app decrypt-backup <backup_file.kasbak> <output-dir>
```

or for the script
```bash
python decrypt_backup.py  <backup_file.kasbak> [output-dir]
```

### Example
```bash
docker run --user $(id -u):$(id -g) --rm -it -v $(pwd):/app decrypt-backup backup_2025-12-02_034146.kasbak ./output
```

Or using the python script directly:

```bash
# Decrypt a backup
python decrypt_backup.py backup_2024-12-02_143022.kasbak

# Decrypt to a specific directory
python decrypt_backup.py backup_2024-12-02_143022.kasbak ./my_backups
```

### What the Script Does

1. Extracts the .kasbak ZIP file
2. Reads the metadata.json
3. Checks if the database is encrypted
4. Decrypts the database.db file using your password
5. Verifies the checksum (if available)
6. Saves the decrypted database as `database_decrypted.db`

### Opening the Decrypted Database

Once decrypted, you can open the SQLite database with any SQLite viewer:

- **DB Browser for SQLite**: https://sqlitebrowser.org/
- **DBeaver**: https://dbeaver.io/
- **Command line**: `sqlite3 database_decrypted.db`

## License

This encryption implementation is part of Kashr and follows the same license.
