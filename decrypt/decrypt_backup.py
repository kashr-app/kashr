#!/usr/bin/env python3
"""
Kashr Backup Decryption Tool

This script decrypts encrypted Kashr backup files (.finbak).
The encrypted backups use AES-256-GCM encryption with PBKDF2 key derivation.

Usage:
    python decrypt_backup.py <backup_file.finbak> [output directory]

Example:
    python decrypt_backup.py backup_2024-12-02_143022.finbak

Requirements:
    pip install cryptography

The script will:
1. Extract the .finbak ZIP file
2. Decrypt the database.db file if encrypted
3. Save the decrypted database as database_decrypted.db
"""

import sys
import os
import zipfile
import json
import hashlib
import getpass

from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.argon2 import Argon2id


# Constants matching the Dart implementation
HEADER = b'FINBAK_ENC_V1\x00\x00\x00'
SALT_LENGTH = 32
IV_LENGTH = 12
ARGON2_ITERATIONS = 3
KEY_LENGTH = 32  # 256 bits


def derive_key(password: str, salt: bytes) -> bytes:
    """Derive encryption key from password using Argon2id"""
    kdf = Argon2id(
        salt=salt,
        length=KEY_LENGTH,
        iterations=ARGON2_ITERATIONS,
        lanes=1,
        memory_cost=64 * 1024,
        ad=None,
        secret=None,
    )
    return kdf.derive(password.encode('utf-8'))


def decrypt_data(encrypted_data: bytes, password: str) -> bytes:
    """Decrypt data using AES-256-GCM"""
    # Verify header
    header = encrypted_data[:len(HEADER)]
    if header != HEADER:
        raise ValueError('Invalid backup file header')

    offset = len(HEADER)

    # Extract salt
    salt = encrypted_data[offset:offset + SALT_LENGTH]
    offset += SALT_LENGTH

    # Extract IV
    iv = encrypted_data[offset:offset + IV_LENGTH]
    offset += IV_LENGTH

    # Extract ciphertext and tag
    ciphertext_and_tag = encrypted_data[offset:]

    # Derive key
    key = derive_key(password, salt)

    # Decrypt
    aesgcm = AESGCM(key)
    try:
        plaintext = aesgcm.decrypt(iv, ciphertext_and_tag, None)
        return plaintext
    except Exception as e:
        raise ValueError(f'Decryption failed. Incorrect password or corrupted data: {e}')


def calculate_checksum(data: bytes) -> str:
    """Calculate SHA-256 checksum"""
    return hashlib.sha256(data).hexdigest()


def extract_and_decrypt_backup(backup_file: str, password: str, output_dir: str = None):
    """Extract and decrypt a Kashr backup"""

    backup_path = Path(backup_file)
    if not backup_path.exists():
        print(f'Error: Backup file not found: {backup_file}')
        sys.exit(1)

    # Set output directory
    if output_dir is None:
        output_dir = backup_path.parent / f'{backup_path.stem}_extracted'
    else:
        output_dir = Path(output_dir)

    output_dir.mkdir(exist_ok=True)

    print(f'Extracting backup: {backup_file}')

    # Extract ZIP file
    try:
        with zipfile.ZipFile(backup_path, 'r') as zip_ref:
            zip_ref.extractall(output_dir)
    except Exception as e:
        print(f'Error extracting ZIP file: {e}')
        sys.exit(1)

    print(f'Extracted to: {output_dir}')

    # Read metadata
    metadata_file = output_dir / 'metadata.json'
    if not metadata_file.exists():
        print('Error: metadata.json not found in backup')
        sys.exit(1)

    with open(metadata_file, 'r') as f:
        metadata = json.load(f)

    print(f'Backup ID: {metadata.get("id")}')
    print(f'Created: {metadata.get("createdAt")}')
    print(f'App Version: {metadata.get("appVersion")}')
    print(f'DB Version: {metadata.get("dbVersion")}')
    print(f'Encrypted: {metadata.get("encrypted")}')

    # Check if database is encrypted
    db_file = output_dir / 'database.db'
    if not db_file.exists():
        print('Error: database.db not found in backup')
        sys.exit(1)

    if not metadata.get('encrypted', False):
        print('Database is not encrypted. No decryption needed.')
        print(f'Database file: {db_file}')
        return

    # Decrypt database
    print('Decrypting database...')

    with open(db_file, 'rb') as f:
        encrypted_data = f.read()

    try:
        decrypted_data = decrypt_data(encrypted_data, password)
    except ValueError as e:
        print(f'Error: {e}')
        sys.exit(1)

    # Verify checksum if available
    if metadata.get('checksum'):
        actual_checksum = calculate_checksum(decrypted_data)
        expected_checksum = metadata['checksum']

        if actual_checksum == expected_checksum:
            print('✓ Checksum verified successfully')
        else:
            print(f'Warning: Checksum mismatch!')
            print(f'  Expected: {expected_checksum}')
            print(f'  Actual:   {actual_checksum}')

    # Save decrypted database
    decrypted_file = output_dir / 'database_decrypted.db'
    with open(decrypted_file, 'wb') as f:
        f.write(decrypted_data)

    print(f'✓ Decryption successful!')
    print(f'Decrypted database saved to: {decrypted_file}')
    print(f'Size: {len(decrypted_data):,} bytes')


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    backup_file = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        password = getpass.getpass(prompt='Enter password: ')  
        if not password:
            print("Error: No password provided.")
            sys.exit(1)
        extract_and_decrypt_backup(backup_file, password, output_dir)
    except KeyboardInterrupt:
        print('\nOperation cancelled by user')
        sys.exit(1)
    except Exception as e:
        print(f'Unexpected error: {e}')
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
