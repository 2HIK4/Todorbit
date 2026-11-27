# Security

Report security concerns privately to the maintainer at
[hussamalkhatib24@gmail.com](mailto:hussamalkhatib24@gmail.com). Include the
Todorbit version, platform, behavior, and likely impact. Use disposable data
for any reproduction. Keep private databases, credentials, recovery keys, and
reproduction details out of public issues.

## Data protection

- The local SQLite database and local recovery copies are readable by the
  operating-system account that owns them. Todorbit's optional PIN locks the
  interface using PBKDF2-HMAC-SHA256 verification and wrong-attempt backoff;
  it is not file encryption. Use OS-level disk or account protections for
  storage encryption.
- [Drive snapshots](docs/GOOGLE_DRIVE_BACKUP.md) are encrypted locally with
  AES-256-GCM before upload. Restored data and local review copies are stored
  as unencrypted local files.
- [Standard Sync](docs/GOOGLE_DRIVE_SYNC.md) uses Google Drive's transport and
  storage protections and uploads planner operations without client-side
  encryption. Private Encrypted Sync encrypts those operations on the device
  with an Argon2id-protected workspace key and requires the workspace
  passphrase or recovery code to unlock another device.
- User OAuth tokens and recovery secrets are excluded from packages and
  settings exports. Desktop OAuth client ID and shared client configuration
  identify the installed application; PKCE and the user's grant protect
  authorization.
- Windows Explorer-hosted desktop widgets (`TodorbitWidget.exe`) attach as
  layered child windows; desktop attachment and transparency behavior depend on
  Explorer and Windows theme state.

See [PRIVACY.md](docs/PRIVACY.md) and [PLATFORM_SUPPORT.md](docs/PLATFORM_SUPPORT.md)
for current distribution and experimental service limits.
