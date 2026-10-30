# First Android beta: owner signing setup and remaining acceptance

Preparation checkpoint: 2026-10-30, implementation `5fcd561` on
`feature/android-mobile`. This is a preparation record, not a publication receipt.
The owner confirmed that no existing production key is available and requested
local creation instructions. No production key or passwords have been created.

## Current state

- Local signing configuration `android/key.properties` is absent and Git-ignored.
  The standard Android key directory contains only the development key.
- GitHub authentication is available. The repository has the `github-pages`
  environment, but no `android-signing` environment or protected signing setup.
- Public releases through `v1.0.18` contain no Android assets. The proposed new
  tag is **`v1.0.19-beta.1`**, with Android version **`1.0.19-beta.1` / code 23**.
  Reserve code 22 for an unpublished same-production-signer baseline. These are
  planned versions only; recheck tags and published metadata before building.
  Do not reuse the existing Windows `v1.0.18` tag or change its assets.
- The existing code-21 APK is debug-signed and is excluded from publication.
  Production fingerprints, release APK/checksum and public links do not exist yet.
- Prior implementation gates are recorded in [the UI report](ANDROID_UI_REDESIGN.md).
  They do not establish production signing, production OAuth, or a same-production-
  signer installer upgrade. Repeat release gates on the final candidate source.
- Preparation verification: 25 updater/UI/backup/portable round-trip tests pass
  (`.buildlog/android-beta-preparation-tests.log`); four release-validator tests
  pass; documentation links and `git diff --check` pass. The portable test emits
  Drift's multiple-database warning while using distinct temporary desktop/mobile
  files and executors. No production build or live installer claim is made.

## Owner steps: create and recover the permanent key

Perform these steps in your own interactive PowerShell, outside this agent's
captured command output. Keep passwords in your password manager, never in chat,
command arguments, transcripts, Git, or screenshots. Use a BitLocker-protected
local volume and encrypted backup media. Stop any PowerShell transcript first.

1. Create a dedicated directory outside the repository. The example location is
   `C:\Users\User\TodorbitSigning`; it is a proposal, not an existing keystore.
   These commands refuse to reuse an existing directory so existing keys cannot
   be overwritten. Restrict access before writing secrets:

   ```powershell
   $signingDir = Join-Path $env:USERPROFILE 'TodorbitSigning'
   if (Test-Path -LiteralPath $signingDir) { throw 'Inspect the existing directory before proceeding.' }
   New-Item -ItemType Directory -Path $signingDir | Out-Null
   $signingOwner = [Security.Principal.WindowsIdentity]::GetCurrent().Name
   icacls $signingDir /inheritance:r /grant:r "${signingOwner}:(OI)(CI)F" 'SYSTEM:(OI)(CI)F'
   if ($LASTEXITCODE -ne 0) { throw 'Directory protection failed; do not create a key.' }
   $keytool = 'C:\Program Files\Android\openjdk\jdk-21.0.8\bin\keytool.exe'
   $signingKey = Join-Path $signingDir 'todorbit-release.jks'
   ```

2. Save a new strong password in your password manager. A randomly generated
   32-character ASCII alphanumeric password avoids Java-properties escaping
   issues. You choose and retain it. Generate an RSA-4096 signing key with
   SHA256withRSA and 10,000 days of certificate validity (about 27 years):

   ```powershell
   & $keytool -genkeypair -v -storetype JKS -keystore $signingKey -alias todorbit -keyalg RSA -keysize 4096 -sigalg SHA256withRSA -validity 10000
   if ($LASTEXITCODE -ne 0) { throw 'Key creation failed; inspect before retrying.' }
   ```

   Enter the password only at keytool's hidden prompts. Enter the publisher's
   public certificate identity deliberately; certificate subject information is
   public. At the private-key password prompt, Enter reuses the store password,
   or choose another strong password and save both. JKS's recommendation to use
   PKCS12 is a format advisory; do not regenerate the signing identity to fix it.

3. Inspect public metadata and export the public certificate:

   ```powershell
   & $keytool -list -v -keystore $signingKey -alias todorbit
   & $keytool -exportcert -rfc -keystore $signingKey -alias todorbit -file (Join-Path $signingDir 'todorbit-release-public.pem')
   ```

   Confirm a PrivateKeyEntry, RSA 4096, intended validity, and a subject other
   than Android Debug. Record the exact **SHA-1** and **SHA-256** certificate
   fingerprints and alias in your password manager. Only the public certificate
   and fingerprints may be shared with the agent. Do not confuse the certificate
   SHA-256 with the keystore file hash or future APK file hash.

4. Make **two additional encrypted offline copies**, for example an encrypted
   USB drive in one secure location and a different encrypted drive kept offsite.
   Copy the keystore and public certificate, record alias/password recovery in
   your password manager, and keep backup decryption recovery independently
   available. Two folders on this computer are not two independent backups.
   Compare `Get-FileHash -Algorithm SHA256 <file>` across all three keystores.
   On a protected working copy restored from a backup, verify store and private
   key recovery (both commands prompt interactively):

   ```powershell
   & $keytool -list -v -keystore '<restored-copy-path>' -alias todorbit
   & $keytool -certreq -keystore '<restored-copy-path>' -alias todorbit -file '<protected-temporary-path>/recovery-check.csr'
   ```

   The CSR is public; no certificate authority or paid certificate is required.
   Verify the restored certificate fingerprints match the original. Confirm that
   both backups and passwords are recoverable before authorizing signing use.
   Losing this key or its passwords can permanently prevent GitHub in-place
   updates. A replacement key cannot update existing installations under the
   current exact-certificate verifier. Play upload-key reset does not recover it.

5. Configure local builds. From the repository, create an empty ignored
   `android/key.properties`, restrict its ACL, then fill it in your local editor:

   ```powershell
   if (Test-Path -LiteralPath android/key.properties) { throw 'Inspect existing configuration; do not overwrite.' }
   New-Item -ItemType File -Path android/key.properties | Out-Null
   icacls android/key.properties /inheritance:r /grant:r "${signingOwner}:F" 'SYSTEM:F'
   if ($LASTEXITCODE -ne 0) { throw 'File protection failed; do not enter passwords.' }
   notepad android/key.properties
   ```

   ```properties
   storeFile=C:/Users/User/TodorbitSigning/todorbit-release.jks
   storePassword=<your actual store password, entered locally>
   keyAlias=todorbit
   keyPassword=<your actual key password, entered locally>
   ```

   Use the actual absolute path with forward slashes. The placeholders are not
   valid credentials. With other password character sets, apply Java Properties
   escaping, including backslashes, leading spaces and Unicode; never print the
   resulting file. This ignored file is a plaintext local secret: protect the
   workstation and never add it to Git or upload it as an artifact. Check
   `git check-ignore android/key.properties` prints the path.

6. Tell the agent only: the keystore path, alias, public SHA-1/SHA-256,
   confirmation that local configuration is ready, that both separate encrypted
   backups passed recovery, and authorization to use this identity for Todorbit
   releases. Do not send passwords or the keystore. Then signing-dependent work
   can resume under the existing publication authorization.

## Google Drive OAuth after key creation

In the existing **todorbit** Google Cloud project, create a separate Android
OAuth client named Todorbit GitHub production. Use package
`io.github.hik4.todorbit` and the **new production SHA-1 from step 3**. Retain
the debug client and its `64:91:E2:9F:4F:0A:0B:AB:3C:9E:48:36:11:93:F8:C5:E2:BD:E1:B7`
fingerprint. Do not copy it into the production client.
Retain only `https://www.googleapis.com/auth/drive.appdata`, the existing consent
configuration, and encryption/recovery format. No client secret or credentials
JSON belongs in the Android app; ordinary users choose a Google account.
[Google's certificate guidance](https://developers.google.com/android/guides/client-auth)
explains the package/certificate registration requirement.

Follow [the existing account and cross-platform acceptance procedure](ANDROID_GOOGLE_DRIVE.md)
using authorized test accounts on disposable data. Production connection,
encrypted upload/download/preview/restore and Windows/Android discovery remain
unverified until actually tested. Missing OAuth setup is not repaired by disabling
Drive. If real acceptance is still incomplete, retain it as a release blocker
under the current candidate notes rather than silently granting an exception.

## GitHub and future Play signing strategy

GitHub APKs must always use this owner-retained **app-signing key**. For future
Play App Signing, deliberately supply this same existing app-signing key through
Google's approved encrypted import process during initial enrollment if matching
installed identities across stores is required. Retain your own recoverable copy;
Google does not offer private-key export afterward. Do not accidentally select a
new Google-generated app-signing identity for the same package.

A separate **Play upload key** authenticates AAB uploads; it is not the signer of
APKs installed from Play. Register that upload certificate with Play, and register
the actual Play **app-signing SHA-1** for Google OAuth. Resetting an upload key
does not rotate the installed app signer. These distinctions follow
[Android's signing documentation](https://developer.android.com/studio/publish/app-signing)
and [Play's enrollment procedure](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en).
Matching signers is necessary, but does not prove cross-store update acceptance;
Play policy, version codes and channel-specific updater behavior still apply.

Currently both local flavors and the candidate validator intentionally expect
the same production signer. A future separate Play upload key will require an
explicit flavor-specific signing configuration and validation change before
Play submission; do not relax the GitHub installed-signer check. No Play upload
or enrollment is authorized by this task.

## Candidate and updater work after owner setup

1. Recheck remote tags/releases and Android metadata floors. Synchronize the
   candidate source version and native version counterparts per [Release](RELEASE.md),
   without modifying existing Windows releases. Run full analysis/Flutter tests,
   backup/restore and updater checks, Windows Release/self-test, Android integration,
   Android Release builds and exact-source Android/Windows CI. Configure the
   protected `android-signing` environment using [the existing secret contract](ANDROID_RELEASE.md).
   Branch protection, required reviewers and trusted-ref access are required;
   repository code with signing access is trusted code.
2. Build an unpublished production baseline code 22 and candidate code 23 using
   the same key. Use a **new disposable emulator**, keeping the archived debug
   emulator untouched. Install the baseline fresh and create tasks, events,
   preferences, managed attachments and verified backups. Record stable IDs and
   counts. Release APKs cannot use `run-as`; use app exports and disposable test
   instrumentation where needed, never add exported test endpoints to production.
3. Exercise native checksum/package/signer/SDK/ABI validation and actual system
   installation permission denial, cancellation, retry and approval through the
   in-app flow. Reopen and compare data/settings/attachments. The existing
   `tools/test-android-update.ps1` creates **debug** fixtures at codes 19/20;
   it does not prove this production path and must not downgrade/uninstall the
   archived code-21 profile. Do not count `adb install -r` as installer acceptance.
4. Run `tools/prepare-android-release.py` with the production APK, signed candidate
   AAB, exact version/code, approved public SHA-256 and tracked notes. Keep its
   signer, non-debuggable, ABI, alignment, bundle and monotonic-code gates intact.
   The AAB is an unpublished validation artifact, not a Play submission. Review
   credentials/exclusions and final manifest, APK hash and GitHub asset digests.
5. Stage a GitHub **draft pre-release** with the exact candidate source/tag, APK,
   versioned Android metadata, checksum file and Markdown notes. Keep the AAB out
   of the public GitHub installation assets. Do not mark this beta latest Stable.
   No public fixture release is needed for installation acceptance: test native
   installation with private staged fixtures, and discovery/download separately.
   A full public discovery/download/install observation can follow publication
   from the retained production baseline once all prepublication gates pass.
6. Publish only after owner custody/recovery, signing, CI and remaining blockers
   are resolved. Verify anonymous download/hash, Pre-release discovery and notes,
   Stable exclusion, actual download/native verification/installation from the
   baseline, and retained data. Record exact commits, fingerprints, APK hash,
   release URL and observations. No public release is claimed by this plan.

## Phone installation and debug migration

Do not install the debug APK as a public beta or attempt a cross-signer update.
After a production beta is actually published:

1. In the existing debug app, export a verified full SQLite backup and portable
   settings, or an encrypted full backup with its recovery passphrase. Copy it
   outside app-private storage to a computer or independently accessible location.
2. Preview and restore that exact backup on a disposable installation first.
   Compare tasks, events, IDs, settings and managed attachments. External linked
   files are not embedded attachments; copy them separately and verify access.
3. Only after successful recovery, deliberately uninstall the debug app yourself.
   No script or agent will uninstall it. Uninstall removes app-private data.
4. Download the APK from the eventual official GitHub beta release, compare its
   SHA-256 with the published checksum, open it and approve Android installation.
   Android 8+ on ARM64 or x86-64 is required. Grant installation-source permission
   only to the source you use, and revoke it afterward if desired.
5. Restore the verified backup/settings, reopen, and compare data and attachments.
   Reauthorize Google Drive and reconfigure device PIN, permissions and widgets.
   Keep the original external backup until verification is complete.
6. For subsequent same-signer updates use **Settings > Software Updates >
   Pre-release > Check for Updates** and review the offered notes before download.
   Android still asks for installation approval; data preservation must be verified.
