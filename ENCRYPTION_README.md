# Finanalyzer Backup Encryption

This document explains how the backup encryption feature works and how to decrypt backups outside the app.

## Overview

Finanalyzer backups can be encrypted using AES-256-GCM encryption with PBKDF2 key derivation. This provides strong protection for your financial data when stored locally or in the cloud.

## Encryption Details

- **Algorithm**: AES-256-GCM (Galois/Counter Mode)
- **Key Derivation**: Argon2id
- **Iterations**: 3
- **Salt**: 32 bytes (randomly generated per backup)
- **IV**: 12 bytes (randomly generated per backup)
- **Authentication Tag**: 16 bytes

## Encrypted File Format

When a database is encrypted, the file structure inside the ZIP archive is:

```
database.db (encrypted):
  [Header: "FINBAK_ENC_V1" + null padding (16 bytes)]
  [Salt (32 bytes)]
  [IV (12 bytes)]
  [Encrypted Data + Authentication Tag (variable + 16 bytes)]
```

## How to Use Encryption

### Enabling Encryption

1. Open the app
2. Go to Settings → Backup & Restore
3. Tap the Settings icon (⚙️) in the top right
4. Enable "Enable Encryption"
5. Tap "Save"

### Creating an Encrypted Backup

1. Go to Backup & Restore
2. Tap "Create Backup"
3. Enter your encryption password
4. Confirm the password
5. Wait for the backup to complete

**Important**: Keep your password safe! It cannot be recovered if lost.

### Restoring an Encrypted Backup

1. Go to Backup & Restore
2. Find the encrypted backup (marked with 🔒 icon)
3. Tap the menu (⋮) and select "Restore"
4. Confirm the restoration
5. Enter your encryption password
6. Wait for the restore to complete
7. Restart the app

## Decrypting Backups on Desktop

You can decrypt your backups on a desktop computer using the provided tool in [decrypt](decrypt).

Please see [decrypt/README.md](decrypt/README.md) for more information.

## Security Considerations

### Password Strength

Use a strong password for encryption:
- At least 12 characters
- Mix of uppercase and lowercase letters
- Include numbers and special characters
- Avoid common words or patterns

The app shows a password strength indicator when creating encrypted backups.

### Password Storage

**The app NEVER stores your encryption password**. You must enter it every time you:
- Create an encrypted backup
- Restore an encrypted backup

This is a security feature, not a bug!

### Lost Password

If you lose your encryption password:
- **You cannot decrypt your backups**
- There is no password recovery mechanism
- This is by design for security

Make sure to store your password in a secure password manager.

### Checksum Verification

Each encrypted backup includes a SHA-256 checksum of the unencrypted data. This helps verify:
- The password is correct
- The data wasn't corrupted during encryption/decryption
- The backup integrity is maintained

## Troubleshooting

### "Invalid password or corrupted data"

This error occurs when:
- The password is incorrect
- The backup file is corrupted
- The file was modified

Try:
1. Double-check your password
2. Download the backup again (if from cloud)
3. Try a different backup

### "Checksum verification failed"

This means the decryption succeeded but the data doesn't match the expected checksum:
- The password might be wrong (but accidentally passed authentication)
- The encrypted data might be corrupted
- The metadata might be from a different backup

## License

This encryption implementation is part of Finanalyzer and follows the same license.
