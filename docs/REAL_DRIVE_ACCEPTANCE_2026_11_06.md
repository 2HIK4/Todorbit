# Real Drive acceptance and OAuth audit — 2026-11-06

Later owner-authorized continuation: Cloud configuration inspection is reported
complete and the existing approved Desktop JSON has been validated locally.
A separate Drive-enabled private Windows candidate is now prepared; see
[the enabled-build receipt](PRIVATE_DRIVE_ENABLED_BUILD_2026_11_06.md).
No account/Drive action was authorized or performed. The historical disabled
artifacts below remain intact; A–L real-cloud outcomes remain BLOCKED.

**Real-cloud acceptance: BLOCKED before authorization. No real Drive request,
Google account connection or Cloud Console change was performed.** All scenarios
A–L below remain blocked; deterministic passes are a separate evidence class.

Branch `feature/sync-ux-refinement`, starting commit `8ef2d98`. Application source
is unchanged from `2262ede` / implementation `f26f6b0`, schema 27, version
`1.0.19-beta.12+35`. The three preexisting storage-document changes are preserved.
This audit follows AGENTS, Codex workflow, Testing, the canonical UI/local-first
and regression skills, [refinement](REFINEMENT_2026_11.md) and
[private acceptance](PRIVATE_ACCEPTANCE_2026_11_06.md). No release authorization
is inferred from earlier publications or historical account tests.

## Verified local facts versus owner/Console verification

| Item | Verified from current source/artifacts | Still requires owner/Console or real execution |
| --- | --- | --- |
| Intended project | Existing project is documented as Todorbit, project ID `todorbit`, in Android setup and prior private acceptance. No project ID is invented from a client ID | Confirm this existing project and its Desktop/Android clients in Console; previous owner-reported settings are historical, not current observations |
| Windows private Release | Config and build receipt are Drive-disabled, ID and Desktop client-secret parameter empty; `canConnect` is false | Approve the existing Desktop client/config outside Git, then prepare a distinct enabled build and authorize only a disposable account |
| Android private APK | Package `io.github.hik4.todorbit`, beta12/code35, debug certificate SHA-1 `64:91:E2:9F:4F:0A:0B:AB:3C:9E:48:36:11:93:F8:C5:E2:BD:E1:B7`; SHA-256 `9144c2df0aa461641f8570d62f880ee9e481c272a80673089a6799d111c9bf73` | Matching Android client in the intended project, eligible test account, healthy Google Play services environment and actual authorization |
| Android identity evidence | Exact APK SHA-256 still matches the verified APK; reused `apksigner`/`aapt2` evidence is tied to those bytes, not a guessed keystore. Drive code defaults enabled | Production signer registration does not establish this debug package/certificate registration |
| Permissions | Both adapters request only `https://www.googleapis.com/auth/drive.appdata`; identity is verified with Drive `about.user` | Drive API, consent configuration, audience/eligibility, granted permission and Windows/Android appDataFolder discovery |
| Desktop flow | External browser, loopback IPv4 callback on an ephemeral port, CSRF state, PKCE S256, offline authorization-code exchange; fixed Google endpoints | Real cancellation, consent, token exchange/refresh, revoked/expired grants and policy errors |
| Desktop token storage | Profile/purpose-hashed `SecureCloudTokenStore`; tokens and optional debug client config use platform-secure storage, excluded from settings/backups. Refresh is coalesced; refresh/account/scope failures preserve local work | Secure-store/OS behavior in a fresh Windows user; APPDATA alone does not create a separate Credential Manager identity |
| Android flow | GIS `AuthorizationClient`, account selection for interactive calls, silent reacquisition for workers, account pinning and generation fencing. Access tokens are memory-only; only verified account identity is stored securely; no Desktop refresh token or backend secret | Native Play services/account resolution, device lifecycle and reconnect behavior |
| Expiration/disconnect | Windows refreshes within 60 seconds of expiry; Android reacquires after its conservative 50-minute cache. Local disconnect works offline, removes local credentials/identity and retains cloud content/grants; Android also clears its cached token | Actual expiry/revocation. Revoking a Google grant is an owner action in Google Account connections, not an implicit disconnect side effect |
| User-facing setup | Release hides developer credentials import. Standard setup needs ordinary Google authorization; Private setup explicitly requests its recovery credential. Errors distinguish unavailable build, auth/permission/services/offline/conflict/recovery states | Native account screens, expired authorization and actual cloud feedback. Prior widget/Driver evidence is reused, not relabeled as live OAuth acceptance |

Primary implementation boundaries: `google_drive_auth.dart`,
`android_google_drive_auth.dart`, `MainActivity.kt`, `BackgroundDriveAuthorization.kt`,
`sync_runtime.dart`, `sync_pairing_service.dart`, `sync_workspace_format.dart`,
`sync_batch_codec.dart`, `sync_controller.dart` and Sync/Backups settings.
No token vault, personal installation, prior outside-repository credentials file
or existing personal workspace was read.

### Retained private artifacts

Absolute directory:
`D:\AI_Projects\life_manager\.buildlog\private-acceptance-20261106\packages`.
Each filename below has a SHA-256 sidecar; these bytes match the prior acceptance
manifest. No replacement artifact was built solely to refresh evidence.

| File | SHA-256 | Current use |
| --- | --- | --- |
| `Todorbit-1.0.19-beta.12-win-x64-setup.exe` | `d6e5a4fb3f8b9836785a1318cbcf3078498e9647e904f61a46230cf6a9fd96ce` | Clean Sandbox installer/schema smoke passed; Drive disabled |
| `Todorbit-1.0.19-beta.12-win-x64-portable.zip` | `00a836e99f79d34604351c4cb77c9b326ea24aa802bd1f3232121cdb0b9694d8` | Verified complete Release bundle; Drive disabled |
| `Todorbit-1.0.19-beta.12-schema27-github-debug.apk` | `01192d13226571fdeac48a21a47e2c27b014b4cc4a7846bb1298ba70deed9051` | Debug signed, arm64/x64, Drive code enabled; account/device acceptance blocked |

Windows is unsigned; Android debug signing is for disposable acceptance, not a
production upgrade. Existing application schema/version remain 27/beta12+35.

## Encryption and account topology

**Standard Sync is readable JSON on Drive, not Todorbit payload encryption.**
Google authorization and transport/storage protections apply. Private Sync uses
a random 256-bit workspace key, AES-256-GCM and authenticated binding; new Private
setup wraps the key using Argon2id and an owner-held passphrase, with an independent
recovery code. The plaintext passphrase is not retained. Encrypted snapshot backup
has its own format and recovery requirements; Standard Sync does not make a local
SQLite export encrypted. These are existing product semantics, not a new change.

The pairing service discovers one active workspace per account; a new Standard
workspace uses the account namespace unless a replacement generation exists.
Standard/Private conversion and passphrase changes are unavailable. A unique
task prefix does not isolate cloud namespaces. Start New Sync retires workspace
content and is outside this task's no-reset authorization.

Consequently, testing both modes without replacing/deleting an existing workspace
requires **two approved, fresh disposable accounts**, one per mode. Within each
mode use the same account on Windows and Android. With only one approved account,
test its initial chosen mode and leave the other mode blocked. Do not convert,
reset, reuse personal content or silently broaden this authorization.

## Exact Cloud Console checks for the owner

Open the existing project in [Google Cloud Console](https://console.cloud.google.com/).
Use the project picker to verify ID `todorbit`; if the intended project differs,
report that discrepancy before proceeding. Inspect existing resources first.
Do not recreate correctly configured clients, rotate a secret or change a
production audience just to clear a test error.

| Console navigation/resource | Field/check and expected result | Already correct when / information needed afterward |
| --- | --- | --- |
| APIs & Services → Enabled APIs & services | Google Drive API (`drive.googleapis.com`) enabled | It appears enabled; report yes/no. If absent, owner enables it through Library after reviewing the change |
| Google Auth platform → Branding | Existing Todorbit identity, support contact, homepage/privacy and applicable terms accurate | Existing values match the intended app; report status/blocking notice without private contacts/screenshots or credential contents |
| Google Auth platform → Audience | Inspect user type and Publishing status. A consumer test account needs an eligible External app; Internal is limited to the owning organization | Report Internal/External and Testing/In production. Do not change a valid setting solely for this test |
| Audience → Test users, if Testing | Add only the explicitly approved disposable account(s) if absent | Account is listed; report confirmation. If In production, do not invent a test-user-list requirement |
| Google Auth platform → Data Access | Required requested scope is `https://www.googleapis.com/auth/drive.appdata` | Scope is present. Report unexpected additional scopes; do not widen to full Drive or remove scopes used by other deployed clients blindly |
| Google Auth platform → Clients → existing Windows client | Type Desktop app; belongs to intended project; existing downloaded configuration identifies that same project/client | Report public client name/ID or locally approved file path. If correct, reuse it; do not make a duplicate. Keep the Desktop parameter/downloaded JSON local |
| Clients → existing Android client | Type Android; exact package and debug SHA-1 shown above | Exact pair exists in intended project. If missing, owner creates only the missing debug Android registration after checking for an existing match; production registration stays intact |
| Audience/policy notice and Workspace admin controls if relevant | Account is eligible, not blocked by organization policy; inspect any requested branding/verification action | Report exact non-secret error/status. Non-sensitive scope is not proof of branding approval or universal account eligibility; do not bypass a warning/block |

These current navigation names and scope distinctions were checked against
[Google's consent guide](https://developers.google.com/workspace/guides/configure-oauth-consent)
and [Android authorization setup](https://developer.android.com/identity/authorization).
The app uses on-device Android authorization, not a server authorization-code
flow, so do not create a Web client/backend or add Firebase for this implementation.

`drive.appdata` is classified as non-sensitive; a restricted-scope security audit
is not required solely because this scope is used. The app-specific hidden folder
is not visible in the Drive file browser, so no visible folder picker proves
cross-client discovery. See [Google's app-data guide](https://developers.google.com/workspace/drive/api/guides/appdata).

For External/Testing, Google documents up to 100 test users and seven-day
authorization/refresh-token expiry for non-identity-only scopes such as this one.
An expected test-grant expiry is not automatically an application defect. In
production, grants can still expire or be revoked; do not promise perpetual access.
See [Google's Audience guidance](https://support.google.com/cloud/answer/15549945?hl=en).

## Secure private build provisioning — no account action performed

Minimum current Release fields are exactly `GOOGLE_DRIVE_ENABLED` (Boolean true),
`GOOGLE_DRIVE_CLIENT_ID` (the approved Desktop client ID ending
`.apps.googleusercontent.com`) and `GOOGLE_DRIVE_CLIENT_SECRET` (the corresponding
Desktop public-client parameter required by this build validator). No access or
refresh tokens, account credentials, private keys or recovery material belong here.

Google treats installed Desktop apps as public clients that cannot keep an
embedded client secret confidential; its token parameter is optional at the
protocol level, while Todorbit's existing Release validator requires it for the
tested client behavior. The current builder compiles that Desktop parameter into
the app: outside-Git storage avoids repository exposure, not extraction from a
distributed binary. **Do not supply a confidential Web/server secret or assume
the Desktop parameter is a user-token security boundary.** No actual value was
read, bundled or emitted in this task. See [Google's Desktop OAuth specification](https://developers.google.com/identity/protocols/oauth2/native-app).

After approving the existing client, keep its downloaded **Desktop** JSON in a
user-only directory outside the checkout, for example `C:\Users\User\TodorbitPrivate`.
Tell Codex only the approved path and project confirmation, never its contents.
If an already owned valid file exists, use it; a missing download is not permission
to replace or rotate a production client. Do not paste credentials into chat.

The following is an owner-executed local provisioning example, **not executed**.
Replace paths with the approved files. It copies only the three build fields,
checks the documented project and uses the existing strict validator. It prints
no values and overwrites neither source config nor a prior output file:

```powershell
$desktopPath = 'C:\Users\User\TodorbitPrivate\desktop-client.json'
$privateConfig = 'C:\Users\User\TodorbitPrivate\drive-private-build.json'
if (Test-Path -LiteralPath $privateConfig) { throw 'Choose a fresh output path.' }
try {
  $desktop = (Get-Content -Raw -LiteralPath $desktopPath -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop).installed
} catch { throw 'Check the approved local Desktop JSON; do not share its contents.' }
if (-not $desktop -or $desktop.project_id -cne 'todorbit') { throw 'Review the intended Desktop project.' }
$fields = @{
  GOOGLE_DRIVE_ENABLED = $true
  GOOGLE_DRIVE_CLIENT_ID = $desktop.client_id
  GOOGLE_DRIVE_CLIENT_SECRET = $desktop.client_secret
}
$fields | ConvertTo-Json | Set-Content -LiteralPath $privateConfig -Encoding UTF8
. ./tools/google-drive-release-config.ps1
$null = Read-GoogleDriveReleaseConfig $privateConfig
Remove-Variable desktop,fields
```

Do not execute this example against an unapproved historical file. After local
validation, only a config digest/status and approved path are needed. Error text
must not include raw JSON. Never log variables, token responses, verbose build
defines, authorization callback URLs or Private recovery material.

The builder and both package guards now accept optional `-GoogleDriveConfigPath`.
Default builds still use the unchanged disabled tracked config; enabled private
packages must pass the same outside config to verify config/main/AOT hashes.
The receipt omits the Desktop parameter; downloaded JSON is never copied into the
bundle. These commands are **pending owner configuration/authorization**, not passes:

```powershell
./tools/build-windows-release.ps1 -GoogleDriveConfigPath $privateConfig
./tools/build-portable.ps1 -GoogleDriveConfigPath $privateConfig `
  -OutputDirectory '.buildlog/real-drive-acceptance-20261106/enabled-packages'
```

The existing installer wrapper also accepts this config parameter, but its normal
output is `release/`. To retain private output isolation, use the already verified
Inno `/O<private directory>` procedure from private acceptance after the matching
config/CRT guards, rather than overwriting prior release files. Retain a fresh
SHA-256 manifest and packaged self-test for any newly enabled artifact. Old
Drive-disabled package tests do not prove the new enabled configuration works.
No enabled build was attempted without the required client values.

## Device/profile and cloud boundaries

Current ADB inventory is empty. The only listed AVD is the previously unhealthy
`TodorbitBatch6`; it was not booted again. Use a spare physical arm64 test device
or a separate Android user supported by the device, with current Google Play
services and only the approved account. Do not install the debug APK over a
personal release profile or uninstall personal data to resolve a signature mismatch.

For a new emulator, in Android Studio open Tools → Device Manager → Create
Virtual Device; choose a phone with the Google Play logo and a matching **Google
Play** system image (x86_64 on this Windows x64 host, supported API 26+). Create a
new named AVD, not a reset of the old one. Confirm stable boot, package/input
services, launcher and Play services before installing the exact APK. Downloads,
license/account consent and the repaired environment need owner participation;
none was installed or changed here. See [official AVD guidance](https://developer.android.com/studio/run/managing-avds).

Reserved run label: `TDREAL-20261106-855e8781`. Empty Windows Roaming/Local,
fixtures and snapshot directories exist under
`.buildlog/real-drive-acceptance-20261106/`. They are preparation only: no app was
launched, profile database created, credential stored or cloud workspace bound.
Use a fresh Windows user/VM for actual OAuth, and verify child APPDATA,
LOCALAPPDATA and resolved DB before interactions. Android profile isolation must
be established on the actual device. Windows directory names do not establish it.

After account approval, inspect account identity and the supported read-only
workspace listing before permitting a first pairing/upload. If existing/unknown
content is found, stop; a label prefix does not make it disposable. Never use Start
New Sync or cloud cleanup as a shortcut. Preserve independent snapshots and
immutable history; retain all new test objects unless cleanup is separately approved.

## Actual A–L result matrix and execution criteria

No current scenario is FAIL: no real exchange reached an application assertion.
All are **BLOCKED**, principally by unapproved accounts/client config and absent
Android environment. The following are bounded acceptance criteria for resumption.

| ID / scenario | Real result | Required evidence after authorization |
| --- | --- | --- |
| A Windows→Android initial setup | BLOCKED | Same approved account/project; actual supported pairing; stable IDs and category/project, event, checklist group/item, subtask parent and recurrence relationships on both devices |
| B Android→Windows | BLOCKED | Android-created task/event IDs and relationships arrive unchanged on Windows, no duplicate entities |
| C edits | BLOCKED | Title/notes/date/assignment/event and series edits converge; independent values retained, meaningful divergent edits reviewed |
| D deletion | BLOCKED | Deleted IDs leave active lists both directions and remain absent after repeated sync/restart; tombstones/causal heads retained |
| E offline delete/edit conflict | BLOCKED | Separate synthetic fixtures for explicit deletion and retention choices; unresolved edit preserved, no silent resurrection; later resolution converges |
| F three no-op syncs | BLOCKED | Stable entity IDs/counts and no unexpected user operations/conflict prompts; distinguish legitimate transport metadata from duplicate domain mutations |
| G recurrence/hierarchy | BLOCKED | Stable series/family and occurrence IDs, completion/skip/edit, parent and checklist group membership; no new materialization duplicates |
| H resources | BLOCKED | Managed byte digests and supported HTTP(S) links travel; device-local files/folders stay local and are not opened remotely |
| I Standard | BLOCKED | Real upload/readback/download; readable JSON matches the declared Standard design, not an encryption claim; account/workspace checks retained |
| J Private | BLOCKED | Separate fresh approved account/mode; owner enters passphrase/recovery, verifies correct and incorrect recovery, AES-GCM content and retained key; no secret logs |
| K backup/restore | BLOCKED | Verified snapshot/managed bytes/settings allowlist, preview/cancel/wrong credential, Before Restore, reviewed restart and reconciliation; no deletes inferred from absence |
| L interruption | BLOCKED | Cancel/interrupt only controlled test exchange, preserve exact retry operations and local history, restart/retry without duplicates or corruption; never manually tamper with live cloud objects |

Deterministic CRUD/codec/merge/idempotence/recurrence/recovery and fake-HTTP adapter
passes are reused from the linked receipts. The latest extended two-profile
backup pass covers event projects, named groups and bytes, but is host SQLite,
not actual Android or real Drive. No full Flutter suite, unchanged app build or
long simulation was repeated to substitute for the missing real-cloud evidence.

## Unexpected-task incident: NOT REPRODUCED

No personal record was inspected. Synthetic tests show retained delete/edit
decisions, safe repeated operations, recurrence identity and restored/cloud-only
record handling; they do not establish the original incident's cause. Remaining
hypotheses include a restored older snapshot, legitimate cloud-only records,
an offline unresolved edit, expected recurrence materialization, the wrong local
profile/account/workspace or historical conflict entries being mistaken for
active rows. These are hypotheses, not findings. Titles are never identity keys.

The supported Sync **Safe diagnostic details** panel exposes status, phase and
pending count without record contents/credentials. It cannot establish lineage.
If the owner explicitly approves deeper read-only investigation, use an approved
snapshot/copy, record its hash/schema and stable incident IDs, and open it with
SQLite `mode=ro` plus `PRAGMA query_only=ON`; do not instantiate `AppDatabase`
against it (that can migrate). Compare active `deleted_at`, recurrence slots,
`sync_journal`, `sync_entity_heads`, operation parents/workspace binding and restore
receipts only after approval. Keep titles/notes/blobs, token/key stores and full
payload dumps private. No such copy/access was authorized or performed here.

## Validation ledger and changes

Ignored receipt root: `.buildlog/real-drive-acceptance-20261106/`.
`baseline.json` records protected hashes, run label and exact artifact continuity;
`environment.json` records current device inventory. `source.json` fingerprints
changed tooling; log timestamps/digests are in the invocation index.

| Command/action | Result, scope and reason |
| --- | --- |
| Git status/branch and relevant source/document audit | PASS local audit; original three storage changes only at entry, app/config/version unchanged |
| Prior private artifact SHA-256 checks and exact-APK certificate/package log comparison | PASS hashes unchanged; debug SHA-1/package verified against prior signed bytes. Signature/alignment tests reused, not rerun |
| Official Google/Android documentation browsing | Current external navigation, scope, public-client, Testing expiry and Android setup verified; no signed-in Console/account state read |
| `adb devices -l`; `emulator -list-avds` | No devices; one known unhealthy AVD. No boot, reset, install or account action |
| `tools/test-google-drive-release-config.ps1` | PASS 15 checks. New outside-config path, stale config/secret change rejection, unchanged disabled default and receipt privacy. Compiler fixture verifies path/receipt wiring; **no real Flutter compile or OAuth call** |
| Same guard harness with new malformed-config privacy probe | FAIL, as intended for the diagnostic: the existing JSON parser error can echo field contents. The probe uses a synthetic sentinel and reports only the privacy assertion, never an actual credential |
| Same guard harness after generic parse/read error correction | PASS 16 checks (`external-config-guards-final.log`). Invalid JSON/file reads now give a generic local-file error; the sentinel is absent from the exception. Outside-config and original stale/private-file guards still pass; no network or build |
| Current retained Release `Assert-GoogleDriveReleaseBundle`; parse five changed PowerShell scripts | PASS default bundle hash/config guard and script syntax. A new enabled bundle is not claimed; unchanged app/CRT/native/host passes reused |

Changed code is limited to the Windows builder, portable/installer config
forwarding, shared release-config guard and its focused tests. No application,
protocol, encryption, schema, key ownership or OAuth runtime behavior changed.
Tooling commit: `cdc7229`. Documentation is a separate checkpoint afterward.
The added path removes a private-build dependency on editing tracked config;
defaults and strict validation remain. One confirmed **tooling** privacy defect
was fixed: malformed JSON could echo configuration fields in a parser exception.
The guard now replaces parse/read errors with a generic message. No real secret
was used or exposed. Missing real authorization is not treated
as an application bug. No confirmed real-cloud defect was reproduced or fixed.

## Stop boundary and readiness

Needed from the owner: confirm the intended project and existing clients, approve
the disposable account(s), provision/approve only an outside-Git Desktop config
path and make an isolated Play-services Android environment available. For both
modes without resets, approve two accounts, each shared across the two platforms;
otherwise choose the initial mode for one fresh account. Then the owner completes
normal Google account selection/consent on both test profiles. Do not send tokens,
Desktop parameters, passwords, recovery codes or private keys in chat.

Existing local UI test artifacts remain usable; Windows real Sync is not enabled
in them. Android code is ready to attempt authorization once its registration,
account and environment are verified. Real cross-client discovery and all A–L
outcomes remain unverified. Local UI acceptance may continue separately, but the
real-Sync gate is **not complete** and the project is **not ready for a release
claiming verified cross-platform Sync**. No release, tag, push or version change.
