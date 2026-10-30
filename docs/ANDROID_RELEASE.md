# Android signing, candidate workflow and signing transition

## Establish the production identity

No production key is created by this task. Select the owner-controlled durable
GitHub app-signing identity before public release. Keep its keystore outside Git,
with at least two encrypted offline backups in separate locations. Store alias
and passwords in the owner's password manager; test recovery using a copy.
Losing the GitHub signing key can make in-place updates impossible. Do not
replace it with a disposable CI/debug key.

If creating the first long-lived identity, the owner can run:

```powershell
keytool -genkeypair -v -keystore <secure-outside-repository-path>/todorbit-release.jks -alias todorbit -keyalg RSA -keysize 4096 -validity 10000
keytool -list -v -keystore <same-keystore> -alias todorbit
```

Enter passwords interactively; never put them in shell history. Record SHA-1
for [Android OAuth registration](ANDROID_GOOGLE_DRIVE.md) and SHA-256 for the
candidate verification gate. A keystore already selected for Todorbit should be
reused, not regenerated. `android/key.properties` is ignored:

```properties
storeFile=C:/secure/todorbit-release.jks
storePassword=<local secret>
keyAlias=todorbit
keyPassword=<local secret>
```

```powershell
./tools/build-android.ps1 -Mode Release -Distribution github
./tools/build-android.ps1 -Mode Release -Distribution play -Bundle
```

APK: `build/app/outputs/flutter-apk/app-github-release.apk`.
AAB: `build/app/outputs/bundle/playRelease/app-play-release.aab`.
Release tasks fail without credentials; there is no debug-signing fallback.
Verify with SDK `apksigner verify --verbose --print-certs <apk>` and
`jarsigner -verify <aab>`. Native ELF and APK ZIP alignment are checked by the
existing artifact verifier. AAB 16 KiB bundle configuration and runtime execution
on a real 16 KiB-page environment remain release acceptance gates.

## Unpublished GitHub Actions candidate

The **Prepare signed Android candidate (no publication)** workflow is manual,
read-only for repository contents, and gated on Android CI/integration plus the
existing Windows CI. Configure protected environment **android-signing**, with
branch protection and required reviewers, then add:

| Kind | Name | Value |
| --- | --- | --- |
| Secret | `ANDROID_KEYSTORE_BASE64` | Base64 bytes of the durable keystore |
| Secret | `ANDROID_STORE_PASSWORD` | Keystore password |
| Secret | `ANDROID_KEY_PASSWORD` | Key password |
| Secret | `ANDROID_KEY_ALIAS` | Durable alias |
| Environment variable | `ANDROID_SIGNING_CERT_SHA256` | Expected production certificate fingerprint |

Encode locally and paste directly into the protected secret; do not print it in
logs or commit a file. Workflow materializes credentials under runner temp and
ignored `android/key.properties`, then removes both even after failure. Use only
trusted refs for the environment; repository code with signing access is trusted.

Before dispatch, update `pubspec.yaml` and all existing Windows/native version
counterparts according to [Release](RELEASE.md). Android version codes must
increase across **all** stable and pre-release releases. Never use an ABI offset
code for a universal APK. The preparation tool reads official published Android
metadata and fails on non-increasing codes or unavailable validation responses.
No Android metadata on existing Windows releases is expected before first launch.

Tracked Markdown [candidate notes](ANDROID_RELEASE_NOTES.md) are used as the
default, with an optional tracked path input. The preparation script validates
production signer, non-debuggable APK, ID/version, minimum SDK, ABIs, APK/AAB
signature, native alignment and checksums, and emits:

- `Todorbit-<version>-android-universal.apk`
- `Todorbit-<version>-android-play.aab`
- `Todorbit-<version>-android-update.json`
- `ANDROID-SHA256SUMS.txt`, `ANDROID-RELEASE-NOTES.md`

These are unpublished Actions artifacts retained 14 days; artifact access follows
the repository's Actions permissions and is not made private by environment
reviewers. No job creates a GitHub
release/tag, uploads to Play or publishes packages. After separate owner approval,
upload the complete Android APK/metadata/checksum set to the matching stable or
pre-release GitHub tag; verify GitHub reports SHA-256 asset digests and the public
updater sees the correct channel. The AAB belongs to Play's separate approved
release process, not GitHub APK installation.

## Debug-to-production migration

| Existing installation | Candidate | In-place update |
| --- | --- | --- |
| Debug certificate A | Same debug certificate A, higher code | Supported development update |
| Debug certificate A | Production certificate B | Normally rejected by Android |
| Production certificate B | Same production certificate B, higher code | Supported production update |

Never automatically uninstall to fix signing mismatch. Before a deliberate owner
transition, create a verified exported full SQLite snapshot and portable settings
JSON or an encrypted full Drive package; keep them **outside** app-private
storage and retain the recovery passphrase. Preview/restore into a disposable
installation first. Android uninstall removes private databases, local snapshots,
credentials and launcher widget configuration. Only after verified recovery and
explicit user choice should the owner manually replace the old signing identity.
Recreate device-local PIN/permission/widget settings as needed. An app cannot
preserve its private directory across uninstall by promising an updater migration.

## Isolated update acceptance

Use only an explicitly named disposable emulator. Build two GitHub APKs using
the same development certificate, with increasing `--build-number` (for example,
19 and 20); this does not change the committed Windows version. Install the
older APK, create tasks/events and preferences/widgets, then download/verify the
newer fixture and invoke the actual native update flow. Grant/deny installation
permission, cancel once, retry, approve the system installation, reopen and
compare stable record IDs/database contents/preferences/widget IDs. Keep a
Before Restore snapshot test separate from package-update persistence.

Do not create a public fixture release to test installation. Native verification
can be exercised with APKs copied into the disposable app's private update cache;
release discovery/download is tested separately with official-response mocks.
`adb install -r` establishes package-manager preservation only; it does not prove
the in-app FileProvider/permission path. Record these as different observations.
