# Security

Report security concerns privately to the maintainer at
[hussamalkhatib24@gmail.com](mailto:hussamalkhatib24@gmail.com). Include the
Todorbit version, platform, behavior and likely impact. Use disposable data
for any reproduction. Keep private databases, credentials, recovery keys and
reproduction details out of public issues.

## Data protection

- The local SQLite database and local recovery copies are readable by the
  operating-system account that owns them. Todorbit's optional PIN locks the
  interface. Use OS-level disk or account protections if you need local file
  encryption.
- [Drive snapshots](docs/GOOGLE_DRIVE_BACKUP.md) are passphrase-encrypted before
  upload. Restored data and local review copies are stored locally.
- [Standard Sync](docs/GOOGLE_DRIVE_SYNC.md) uses Google Drive's transport and
  storage protections and uploads planner operations without Todorbit
  client-side encryption. Private Encrypted Sync encrypts those operations
  on the device and requires the appropriate passphrase or recovery code to
  unlock on another device.
- User tokens and recovery secrets are excluded from packages and settings
  exports. Desktop OAuth client ID and shared client configuration identify
  the installed application. PKCE and the user's grant protect authorization.

See the [privacy disclosure](docs/PRIVACY.md) and
[platform support](docs/PLATFORM_SUPPORT.md) for current distribution and
experimental service limits.
