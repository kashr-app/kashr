# Security Policy

## Official Release Signing Certificate

All official Kashr releases distributed through GitHub are signed with our release certificate. You should verify the signature of any APK before installing it.

### Certificate Fingerprints

**SHA-256:**
```
A9:E0:42:FB:F2:AB:1C:4A:B0:FD:46:AD:61:C0:35:74:9A:FA:1D:8D:B6:8D:7E:6A:E6:85:1F:1D:DC:54:CF:59
```

**SHA-1:**
```
E5:65:E1:2E:80:6E:C3:B5:E8:74:38:59:2A:BE:72:41:48:01:C8:65
```

### Verifying APK Signatures

To verify that an APK was signed with our official certificate, you can use the Android SDK's `apksigner` tool:

```bash
apksigner verify --print-certs app-release.apk
```

The fingerprints displayed should match those listed above. If they don't match, **do not install the APK** as it may have been tampered with or is not an official release.

Alternatively, you can use `keytool` if you have the Java JDK installed:

```bash
keytool -printcert -jarfile app-release.apk
```

### APK Hash Verification

Each release includes SHA-256 hashes of the APK files in the release notes. After downloading an APK, verify its hash:

**On Linux/macOS:**
```bash
sha256sum app-release.apk
```

**On Windows (PowerShell):**
```powershell
Get-FileHash app-release.apk -Algorithm SHA256
```

Compare the output with the hash published in the release notes.

## Reporting Security Vulnerabilities

If you discover a security vulnerability in Kashr, please report it responsibly:

1. **DO NOT** open a public GitHub issue for security vulnerabilities
2. **DO** create a Report via (Security Advisory)[https://github.com/kashr-app/kashr/security/advisories]
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Any suggested fixes (optional)

## Security Best Practices

When using Kashr:

- Only download releases from the official [GitHub Releases page](https://github.com/kashr-app/kashr/releases)
- Always verify signatures and hashes before installation
- Keep your app updated to the latest version
- Report any suspicious behavior immediately

## Security Update Policy

- Critical security issues will be patched as soon as possible
- Security updates will be clearly marked in release notes
- Users will be notified of critical updates through GitHub releases
