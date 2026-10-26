# Security

Please report security concerns privately to hussamalkhatib24@gmail.com. Include the affected version, reproduction steps using disposable data, and likely impact. Do not post private databases, credentials, or exploit details in public issues.

Todorbit stores its SQLite database locally and does not encrypt it. The optional PIN is an interface privacy feature, not file encryption. Windows desktop widget hosting depends on Explorer behavior and needs manual testing after Windows updates.

Optional Google Drive snapshots use authenticated passphrase encryption before
upload; local/restored databases and recovery copies remain unencrypted.
Recovery passphrases and user access/refresh tokens are never packaged. Desktop
OAuth client ID/client-secret parameters are public application configuration,
not user credentials or a security boundary; PKCE and the user's grant protect
the login. The public release gate and [privacy disclosure](docs/PRIVACY.md)
separate production approval from test-account acceptance.
