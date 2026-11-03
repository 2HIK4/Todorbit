# Todorbit v1.0.19-beta.10 - Experimental Standard and Private Sync

**Experimental pre-release: back up your data before upgrading. Real Google Drive
synchronization has not yet been manually verified. Use disposable accounts and
test records first; do not test new synchronization behavior on irreplaceable data.**

## New in this release

- Standard Google Drive Sync initializes new workspaces without an additional
  Todorbit encryption password. Standard payloads are readable JSON on Drive;
  Google's normal transport and storage protections apply.
- Automatically recognize Standard and encrypted cloud workspaces. Existing
  encrypted workspaces keep their original recovery-code access and are never
  silently replaced with Standard data.
- Optional Private Encrypted Sync for **new, empty workspaces**, selected in
  Settings > Sync > Encryption options before ordinary connection. Memorable
  passphrases have no uppercase/symbol composition rules; random workspace keys
  are protected with authenticated encryption and Argon2id passphrase wrapping.
- Save a separate recovery code; use the passphrase or code on another updated
  device. Protected local key retention avoids routine repeated credential prompts.
- Improved Sync settings, password visibility, recovery acknowledgment and
  dismissible first-time Standard onboarding, shared by Windows and Android.
- Keep causal merges, conflicts, supported preferences, managed attachments,
  existing backups and offline pending work. Backup and Sync remain separate.

## Known limitations

- **Real Google Drive sign-in/exchange and Windows-to-Android synchronization
  remain unverified for this release.** Successful builds and local tests do not
  prove real cloud behavior. Experimental behavior may be unstable.
- Existing Standard workspaces cannot be converted to Private Encrypted Sync.
- Existing private encrypted workspaces cannot be converted to Standard Sync.
- Changing cloud encryption passphrases is not supported. These controls remain
  explicitly unavailable; no cloud conversion or deletion is performed.
- Losing every applicable decryption credential may make private cloud history
  unrecoverable. Keep the recovery code outside your device and never post it.
- Update both devices before using new protocol-2 workspaces. Older clients stop
  at unfamiliar workspace proofs. Legacy encrypted history remains compatible.
- Google registration/consent/account policies, cross-client appData discovery,
  physical-device/background behavior and Windows installer execution for this
  exact release remain owner acceptance. Broad CI/full suites/emulator tests were
  not repeated under the owner's explicit minimal-check policy for this beta.

## Upgrade and manual acceptance

- Windows x64: Settings > Software Updates > select **Pre-release**, check,
  download and install. The installed edition selects Setup; portable selects
  the complete ZIP. Keep the same Windows account and installation/extraction
  location. Windows packages remain unsigned; compare published SHA-256 first.
  Installer registration/PE numeric file versions retain `1.0.19`; the main app
  reports `1.0.19-beta.10+33`.
- Android 8.0+, ARM64/x64: Settings > Software Updates > **Pre-release**, check,
  download and approve Android installation. One universal production-signed APK
  uses the existing package `io.github.hik4.todorbit` and increased code 33.
  Reopen afterward. Alternatively download the APK directly and update in place.
  Never uninstall or clear data to bypass a signing mismatch; back up and stop.
- Stable excludes this experimental release. Play distribution has its separate
  store flow; no AAB is published here. Publisher OAuth configuration is bundled;
  normal users do not enter client IDs or credential JSON.
- With dedicated disposable accounts, test Standard setup/initial merge and both
  transfer directions, supported settings and onboarding persistence. Use a
  different empty account for new private setup, incorrect/correct passphrases,
  recovery-code unlock and restart. Separately test legacy recovery, offline work,
  conflicts, account mismatch and independent backup restoration. A new local
  profile does not empty or isolate an existing cloud workspace.

Report platform, action, expected/actual result and exact error without passwords,
recovery codes, tokens, personal content or private logs.
