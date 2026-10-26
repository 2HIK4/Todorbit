# Google Drive public release gate

Candidate: **1.0.13+14**, prepared on `feature/google-drive-production-readiness`.
Latest published pre-release checked on 2026-10-26: **v1.0.12**. Candidate
version/tag was unused when selected. This document does not authorize
advertising public Google access before the gates below pass.

## Current gate

**BLOCKED — public OAuth release held.** The implementation can compile the public
Desktop client ID and its required client-secret parameter into both Windows
packages. No developer JSON import is exposed in Release builds. The reviewed
configuration is currently disabled and empty. The owner reports the **Todorbit**
project is **Testing**, with app name/logo/contact emails set, missing
homepage/privacy/terms URLs, and no scopes listed under Data Access. External
audience status is not independently confirmed. A valid installed Desktop JSON
was located outside the repository; its source path is not used at runtime and
its fields were not copied into public configuration while this gate is open.
The owner-approved website is now published; see its verified URLs below.
No Cloud Console changes or Google approval is claimed.
The prior `198da07` owner-configured debug acceptance remains historical
evidence for encryption/Drive/recovery, not public packaged login acceptance.

## Owner actions in the current Google Cloud interface

1. Select the intended **production project** in
   [Google Cloud Console](https://console.cloud.google.com/). Keep it and its
   OAuth clients stable across releases: a different project's hidden backups
   are not assumed visible. Do not replace the existing test project blindly.
2. **APIs & Services > Enabled APIs & services**: check Google Drive API is
   enabled. Otherwise **Library > Google Drive API > Enable**.
3. **Google Auth Platform > Data Access > Add or remove scopes**: retain only
   `https://www.googleapis.com/auth/drive.appdata`. It is currently
   [non-sensitive](https://developers.google.com/workspace/drive/api/guides/api-specific-auth);
   this does not establish branding approval or waive privacy disclosure.
4. **Branding**: use Todorbit as the app name, a monitored user support email,
   and current developer contact information. Host an accurate homepage and
   the reviewed [privacy disclosure](PRIVACY.md) on an owned domain. Set the
   application homepage, privacy policy and applicable terms URLs. Add its
   authorized domain and complete the required DNS-level Domain verification in Google
   Search Console. The free Pages hostname is not verified for OAuth. Do not claim ownership of `github.com` or use a repository README
   as proof of a verified application domain.
5. **Audience**: select **External** for general Google accounts. If the status
   is **Testing**, use **Publish app** to request **In production** when ready.
   Testing permits only listed test users (up to 100) and Drive/offline grants
   expire after seven days. Publishing status and verified branding are
   separate; Workspace/admin and account-security restrictions can still apply.
6. **Branding > Verify Branding** if shown: resolve **View issues** findings.
   When the state is **Ready to publish**, use **Publish branding** within
   Google's stated window. **Verification Center** separately tracks branding
   and data-access status. Complete any review Google actually requests; do
   not infer approval from successful test-account login.
7. **Clients > Create client > Desktop app** (or use the reviewed production
   Desktop client). Retain its downloaded JSON outside Git. Provide its file
   path for the maintainer to extract only `installed.client_id` and
   `installed.client_secret` into `config/google-drive.json`, then enable
   `GOOGLE_DRIVE_ENABLED` for private packaged acceptance. Never copy the
   complete JSON, tokens, endpoints, private keys or developer session into
   release configuration. These two Desktop fields are public application
   parameters, not user secrets or an authentication security boundary.
8. Record the project ID, enabled API, exact scope, External/In production
   state, published branding and verification results, URLs, Desktop client ID,
   and an authorized account **outside the test-user list** for acceptance.
   The account owner must perform any required consent. Do not use another
   person's account without permission.

These steps follow Google's current
[Audience](https://support.google.com/cloud/answer/15549945?hl=en),
[Branding](https://support.google.com/cloud/answer/15549049?hl=en),
[native OAuth](https://developers.google.com/identity/protocols/oauth2/native-app),
[production policy](https://developers.google.com/identity/protocols/oauth2/production-readiness/policy-compliance),
and [user-data policy](https://developers.google.com/terms/api-services-user-data-policy)
documentation reviewed 2026-10-26. Actual project state remains unobserved.

## Security review (2026-10-26)

| Boundary | Result | Evidence and limits |
| --- | --- | --- |
| Browser authorization | PASS (source/focused tests) | External system browser, ephemeral IPv4 loopback, fresh 256-bit state/verifier, PKCE S256, exact callback path/GET/state validation, bounded waits and listener cleanup. |
| Tokens and reconnection | PASS (source/mocks; historical real test) | Windows secure-storage plugin encrypts token files with an AES-GCM key held in Windows Credential Manager. Profile-path hash isolates records. Bundled public parameters work in mock exchange, restart, refresh and reconnect without imported configuration. Fresh real packaged acceptance remains open. |
| Diagnostics/exports | PASS (source) | No cloud logging of token/code/passphrase fields; provider error diagnostics use fixed messages. Exported settings use the existing category allowlist; session/client configuration stays outside snapshots. Package gates reject known credential/session/database/backup filenames. This is not a guarantee against arbitrary disguised private data. |
| Account safety | PASS (existing mocked tests) | Identity is checked on connect/refresh; account changes require disconnect; stale remote-object operations fail. Real account switching remains UNVERIFIED. |
| Encryption | PASS (source/automated round trips) | Existing random 16-byte salt, PBKDF2-HMAC-SHA256/600,000, AES-256-GCM, random 12-byte nonce/16-byte tag and fixed authenticated header retained. Wrong key/tamper/format/checksum rejection already covered. No concrete crypto defect identified; this is not an independent cryptographic audit. |
| Storage/transfer | PASS (source/existing mocks) | Only appDataFolder with drive.appdata; encrypted upload, bounded download, unique objects, chunk progress, remote MD5/size and SHA-256 readback before verified success. No automatic deletion. Real quota/interruption remain UNVERIFIED. |
| Recovery | PASS (historical real + automated) | Existing Before Restore, managed snapshot/digest/schema checks, SQLite backup transaction, migration/open receipt and selective settings recovery are unchanged. Prior real restoration matched all 44 tables. New packaged production-client recovery remains UNVERIFIED. |
| Public production authorization | BLOCKED | Owner confirms Testing, incomplete branding URLs and empty configured Data Access. External status/production approval and outside-test-list account acceptance remain unverified. Desktop JSON exists outside Git; public config remains disabled. |

## Build and package

`config/google-drive.json` is a strict three-field public build configuration.
Disabled builds must have empty client fields; enabled builds require both.
Never set the flag simply because the client ID is available. Maintainers
review production evidence before enabling it; ordinary users never do this.

```powershell
flutter pub get
./tools/test-google-drive-release-config.ps1
./tools/build-windows-release.ps1
./installer/build-installer.ps1
./tools/build-portable.ps1
./tools/write-release-checksums.ps1
```

The wrapper passes `--dart-define-from-file` to Flutter. Its public build receipt
binds the configuration hash, enabled flag, client ID, native runner and Dart
AOT binary. Both packaging scripts reject a missing/stale receipt. The receipt
is a consistency check, not a signature or proof of Google approval. Both
packages copy the same reviewed Release bundle. CI repeats config tests,
analysis/tests, Windows Release, portable packaging, native self-test, installer
compile and checksums, then retains an unpublished candidate artifact.

## Required packaged acceptance — UNVERIFIED

The disabled candidate has passed Windows Release, installer compile, portable
CRC/byte equality and isolated installer-layout/portable startup and restart.
Both databases had integrity OK, 44 tables and no task/event records. The
extracted widget self-test passed and the Windows Run registry was unchanged.
This is package startup evidence only. It does not replace the enabled-client
clean Windows-user sign-in/backup/recovery procedure below. Full automated
verification passed 264/264 Flutter tests and clean analysis; see ACCEPTANCE.md.
The final [Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40296394097)
at `63b8bc6` also passed complete tests/builds/installer/portable checks and
retained an unpublished candidate. Downloaded CI package checksums, portable
CRC and config/runner/AOT hashes were verified. This does not unblock public
OAuth or authorize publishing.

Use a disposable Windows user/VM with no Todorbit installation or saved Google
tokens. APPDATA redirection isolates SQLite but does not create a new Windows
Credential Manager identity; use a new Windows user for the strict clean test.
Do not run setup against the personal account. Do not copy a developer JSON,
source directory, test profile, token file or passphrase into the VM.

1. Copy only setup/ZIP and checksums. Verify hashes; install setup in the VM.
   Open Settings > Backups & Cloud. It must show Connect Google Drive and no
   developer configuration import. Record the active data profile.
2. An authorized account outside the test-user list clicks Connect, completes
   official browser sign-in and returns. Confirm the displayed account.
   Quit/reopen and list history; force/allow token refresh and confirm success.
3. Seed disposable tasks/events, recurrence, categories, relationships and
   settings. Create full and settings-only backups; observe actual upload and
   remote readback completion. List both and record snapshot/profile IDs.
4. In a fresh second profile with sentinel task/event/settings, connect the
   same account. Reject a wrong passphrase without data changes; unlock the
   full snapshot, preview, cancel once, then confirm. Close app/widget and
   reopen. Compare every SQLite table and personalization with the source;
   verify Before Restore matches the previous target and the startup opened
   receipt is finalized. Inspect source/target IDs to avoid the wrong profile.
5. Separately restore selected settings with hotkey-preset merge. Verify every
   task/event row and unrelated setting remains unchanged. Cancel/delete only
   test-created snapshots. Disconnect/reconnect and confirm retained history.
6. Repeat with a freshly extracted portable ZIP at a path with spaces in a
   clean Windows user/VM. Verify its location-keyed profile and steps 1–5.
7. Inspect light/dark, normal/narrow windows and larger text, keyboard controls,
   progress, errors, confirmations and recovery. Simulate interruption/offline
   only against disposable objects. Real quota, revoked access, switching
   accounts and physical DPI checks must be labeled separately from mocks.

## Publication

Keep the candidate on the feature branch while production access and packaged
acceptance remain open. A disabled candidate does not meet the requested
public Google Drive release goal; it must not be described as generally
available Google backup. There is no release or updater entry for this
candidate until published. After all gates pass, recheck version availability,
review the final diff, run required CI on the final SHA, merge without force,
tag and publish the Windows x64 pre-release with installer/ZIP and SHA-256
sidecars. Download every public asset and verify its digest, then exercise the
actual updater service on the Pre-release channel. Do not alter the personal
installation to do so.

## Website publication and Google domain gate (2026-10-26)

The owner explicitly approved publication to the existing repository. The complete
static site is live on GitHub Pages with homepage, product/download/support,
Privacy Policy and Terms of Service. It reuses the actual public v1.0.12
screenshot, links only published v1.0.12 assets, and labels Google Drive as not
generally available. These exact URLs passed anonymous HTTPS checks:

- Homepage: `https://2hik4.github.io/Todorbit/`
- Privacy Policy: `https://2hik4.github.io/Todorbit/privacy.html`
- Terms of Service: `https://2hik4.github.io/Todorbit/terms.html`

Website-only source `5d77f37` was fast-forwarded to `main` from `7965205`.
[Deployment 40317545954](https://github.com/2HIK4/Todorbit/actions/runs/40317545954)
passed validation and deployment. Pages is public, uses Actions and enforces
HTTPS. Anonymous GET verified the canonical homepage and all eight dist files;
public content matches source after Git text line-ending normalization. All nine
external links returned HTTP 200 on HEAD, including both downloads. Release API
metadata confirmed v1.0.12 as the latest actual public release and both download
URLs as its assets. Static navigation/anchor, contrast and responsive/accessibility
checks pass. No connected browser is available; rendered desktop/mobile layout,
zoom and screen-reader interaction remain UNVERIFIED.

Only the website and its documentation/workflow were put on `main`. App source,
version, native code, installer/packaging and existing Windows workflow were
preserved. No new app release/tag, Google Cloud setting, OAuth grant, domain/DNS
or account-root website changed. Pages deployment remains manual on `main` with
`publish_approved=true`; push/PR checks only validate. See `website/README.md`
and `website/verify_live.py` for the repeatable deployment/check procedure.

**Domain conclusion: public OAuth remains BLOCKED.** Search Console can verify
this exact project-site URL-prefix property using a real HTML verification tag
or file, without purchasing a domain. An authorized account must obtain the
actual tag/file, publish it at Google's requested location and click Verify.
No such token was supplied and no property was created or verified.

However, Google's more specific current [OAuth Domain Verification guide](https://support.google.com/cloud/answer/13804266?hl=en)
requires a **DNS-level Domain property**, rather than a URL-prefix property,
when resolving unverified authorized domains. This supersedes the earlier
preparation's tentative HTML-verification route as a sufficient OAuth plan.
We cannot set DNS TXT records for GitHub's `2hik4.github.io` hostname. Therefore
successful project-site HTML verification alone would not satisfy that
documented OAuth requirement; no default Pages OAuth eligibility is claimed.

The conditional Authorized Domain hostname is **`2hik4.github.io`**, only if
Google explicitly accepts this arrangement. There is **no verified/accepted
Authorized Domain to enter yet**. Do not enter `github.io`, `github.com`, a full
URL or `/Todorbit/`. The live URLs above are content inputs for future Google
Branding, subject to resolving domain eligibility; this publication did not
enter them in Cloud Console or obtain Google's approval.

The supported ownership route is an owned domain with DNS verification, using
free GitHub Pages hosting. A suitable already-owned domain would avoid a new
registration purchase; otherwise registration may cost money. The owner chooses
and approves any domain/DNS change separately. Google Search Console verification
and GitHub's separate domain-verification TXT process are distinct. No domain
purchase or DNS mutation is part of this task. Any account-root website change
would involve a different repository and remains outside this deployment.

References: [Google Branding](https://support.google.com/cloud/answer/15549049?hl=en),
[Google domain verification](https://support.google.com/cloud/answer/13804266?hl=en),
[Google verification requirements](https://support.google.com/cloud/answer/13464321?hl=en),
[Search Console methods](https://support.google.com/webmasters/answer/9008080?hl=en),
[GitHub Pages setup](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site).
