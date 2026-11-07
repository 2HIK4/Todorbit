# Private Windows credential isolation — 2026-11-06

## Latest cross-platform checkpoint (2026-11-07)

[Corrected real Windows/Android Standard acceptance, current private artifact paths and limits](CROSS_PLATFORM_STANDARD_SYNC_2026_11_06.md#final-outcome-2026-11-07-utc03)
supersedes the earlier stage below:383 operations/all43 portable tables converge,
corrected Android restore/reconciliation and repeated checks/restart pass. Both
updated credential-isolated candidates preserve prior artifacts and production
baseline. Same approved spare account/workspace, no new sign-in. Historical
failures and archived invalid decisions remain explicit. Windows is closed;
authenticated SSD emulator retained. No release, Private Sync or cloud snapshot
testing. Earlier build/readiness receipts retain only their recorded boundaries.


## Latest checkpoint: authorized REAL Standard exchange completed

Owner subsequently authorized the fresh Standard workspace and synthetic real
Drive tests. [Actual results and precise limits](REAL_STANDARD_SYNC_2026_11_06.md):
upload/readback, independent desktop download, updates/deletions, reviewed
concurrent delete/edit, injected lost-response retry, local restore of downloaded
data with reconciliation and real resync, and repeated exchanges pass. Final43
portable tables/81 immutable facts agree; production18 paths/startup and retained
recovery copies unchanged. Existing build reused; no new app implementation or
commit. Private app remains open; Android/Private Sync are unverified. The
earlier unapproved/empty-cloud state below is historical, now superseded.

## Earlier checkpoint: actual account and read-only cloud preflight (17:09 UTC+03)

Owner completed Google authorization and explicitly confirmed the private app's
account is the approved unused spare, never used for personal Todorbit data.
The private account receipt contains Google's verified permissionId, not email.
There was no independently pre-registered spare identifier: confirmation of its
real-world identity is **owner-supplied**, pinned to that receipt. Production
credentials/accounts were not decrypted or inspected for comparison.

Reused the exact built artifact and tests below. Verified private runtime paths,
actual main/AOT hashes and absence of Standard approval. Before restart, the
private SQLite capture context had no account/workspace binding and capture=0.
Recorded owner confirmation and account fingerprint privately. Closed only the
recorded private PID12564 normally; restarted the same binary/root with the
existing `--private-cloud-preflight` switch (owned PID15404). Stored authorization
survived restart; no new sign-in was needed. The new wrapper
`Run-ReadOnlyPreflight.ps1` is outside Git; application source/build is unchanged.

**REAL Google Drive metadata preflight PASS:** account ID matches the private
receipt/owner confirmation; complete paginated GET listing returned **0 objects**.
Exact scope: `spaces=appDataFolder`, `trashed=false`, application=`todorbit-sync`.
Thus no active workspace proof/head/batch or other Sync object was found in that
namespace. No media download, workspace activation, upload, overwrite, deletion,
reset or Start New Sync occurred. This does **not** claim the whole Google account
is empty: ordinary Drive files, snapshot-backup namespace `todorbit`, trashed and
other-app data were not enumerated. They are unnecessary for this empty Sync
namespace check and remain untouched.

Post-preflight: Runtime paths still isolated; schema27/integrity OK/zero tasks;
binding absent, capture disabled, `STANDARD-SYNC-APPROVED.json` absent. All18
production DB/settings/encrypted-credential paths match the quiescent baseline;
startup values unchanged. App remains responding, ~222.5MiB, connected at the
existing auth-only page. No unrelated tests, rebuild, Android/VM launch, release
or publication. Prior native-probe receipt remains valid; the normal restart's
probe flag is false because that diagnostic was deliberately not rerun.

New private evidence: `evidence/post-auth-local-verification.json`,
`disposable-account-owner-confirmation.json`,
`read-only-cloud-preflight-verification.json`, and `Runtime/cloud-preflight.json`.
These record exact times, account-ID/fingerprint matches and verification scope,
without token values. Relevant commands: local hashes/SQLite read-only PRAGMAs
and capture-context query; scoped normal close/restart; existing native app
preflight; production hash/startup comparisons. All pass at their named scope.
No new simulated test pass is substituted for this actual GET result.

**Ready to authorize the first Windows → Google Drive Standard exchange; not yet
activated.** Next owner instruction should explicitly authorize creation of a
fresh Standard test workspace on this verified spare account and synthetic data
only. Then pin its approval, create/verify synthetic fixtures through the existing
repository, exchange and read back from Drive. Current request stops before that
record or any upload is created. No further Google sign-in is presently required.

## Implementation checkpoint (earlier sign-in instructions superseded)

Owner-approved scope: run a Drive-enabled acceptance candidate under the normal
Windows account, with independent local data/credentials and no production
startup, companion or updater effects. No Sandbox, new user, emulator, Android
build, release/version change, push or publication. **Ready for owner Google
sign-in; real Standard Sync is not yet verified or enabled.**

Source: branch `feature/sync-ux-refinement`, HEAD `4dcda12`, plus the named
uncommitted isolation changes. The three preexisting storage-document changes and
earlier acceptance documentation remain preserved. App version remains
`1.0.19-beta.12+35`, schema27. No production OAuth/consent configuration changed.

## Configuration and boundaries

`tools/build-windows-release.ps1 -PrivateDriveTest -GoogleDriveConfigPath <approved outside-Git config>`
sets `TODORBIT_PRIVATE_DRIVE_TEST=true`; default builds remain unchanged. The
private CMake invocation omits the unchanged native companion instead of building
or packaging it. The scoped build environment is restored afterward.

- Private startup requires an absolute, marked `TODORBIT_PRIVATE_TEST_ROOT`,
  matching APPDATA/LOCALAPPDATA/TEMP/TMP, and a non-linked root. SQLite/settings
  always use `<root>\Profile`; no legacy selection, production profile copy or
  executable-directory-dependent data migration occurs. The root remains stable
  across private rebuilds.
- All `SecureCloudTokenStore` purposes route exclusively to the private Windows
  channel: OAuth tokens, optional client parameters, workspace key and reset
  operation. No shared secure-storage call, Credential Manager, migration,
  enumeration or production fallback is made by that backend.
- Native storage uses current-user DPAPI, with additional entropy binding each
  encrypted file to its canonical profile/key path. Files inherit the restricted
  owner/SYSTEM/Administrators root ACL. Each purpose has an independent `.dpapi`
  file and cross-process byte-range lock. Writes flush encrypted temporary bytes
  and replace atomically; failed commits preserve the prior file and clean only
  their own temporary file. Corrupt/decryption-failed files are retained.
  Explicit disconnect deletes only the selected private token file.
- Native companion availability, launch/command and preview paths are disabled.
  Startup skips its registration/restoration and update checks. The Software
  Updates page and update-helper handoff are disabled. No process-wide environment
  change is made to the parent, existing app, widget or updater.
- OAuth remains the existing PKCE/state/account-selection flow and existing
  Google account-ID validation. Local token encryption does not change Standard
  Sync's readable cloud JSON or Private Sync's encryption/recovery protocol.

The UI opens **Backups & Cloud**, its existing auth-only route. The authorization
readiness file was created only after live path/DPAPI/schema and production-hash
verification. Standard exchange separately requires a local approval record for
the exact verified disposable account; it is **absent**. Manual activation and
automatic exchange are gated. Do not use Start New Sync or an existing workspace.

Private-only diagnostic switches support owned-process automation: a synthetic
unused-store probe; read-only cloud metadata preflight; and an approved normal
Sync invocation. They use existing auth/provider/controller APIs, output scoped
status/metadata only, and never emit credentials. Cloud switches have **not run**.

## Exact candidate and running profile

Persistent private root:
`D:\AI_Projects\TodorbitPrivateBuilds\isolated-drive-20261106`.

- Running executable: `source\build\windows\x64\runner\Release\Todorbit.exe`.
  Its adjacent complete bundle is required. Root launcher: `Start-PrivateDrive.ps1`.
  Direct execution without the required environment fails closed.
- Intended database: `Runtime\Profile\life_manager.sqlite`.
- Settings: `Runtime\Profile\`; credentials: `Runtime\Profile\private-credentials\`.
  APPDATA=`Runtime\Roaming`, LOCALAPPDATA=`Runtime\Local`, TEMP/TMP=`Runtime\Temp`.
- Runtime receipt: `Runtime\runtime-paths.json`; launch receipt records PID12564
  at 16:37:28+03. Observed responding, about 221–232MiB working set. No companion,
  Sandbox guest or emulator was running. Runtime root/children inherit the
  restricted private-root ACL.
- Actual main/AOT hashes match the enabled/private build receipt. DPAPI
  write/read/delete succeeded through the **built app's actual native channel**
  in both a separate smoke root and the intended Runtime root. Both DBs are
  schema27, integrity OK, zero tasks. No personal fixture was imported.

Private portable ZIP:
`packages\Todorbit-1.0.19-beta.12-schema27-isolated-drive-win-x64.zip`
(15,970,455 bytes, unsigned, no companion/user data/credentials).

| Identity | SHA-256 |
| --- | --- |
| ZIP | `866c79f309079fa13368fec3271b3ee02075d5ae2c2a2355723825a6f7d61e9b` |
| Main executable | `f11e0d60641345c849b87f5a6fd047792be449e81099904f2ac912d1bb3d60f7` |
| AOT | `773bd3a09c728fb1b99c3df7091b92d8e62888941fb3425e40e14ca15d17a7c5` |
| Implementation input manifest | `a047e6b553165085f412012c1ce2ab74036eccb5d4ab2522dc970b067bf17b02` |

`packages/artifact.json` and `evidence/implementation-source.json` retain exact
identities. An exact HEAD archive plus only the scoped source changes was built;
dependency lock is unchanged. Original binaries, packages and approved OAuth
configuration remain untouched. Two generated diagnostic/command-cache files
were sanitized after scanning 200 files; no approved OAuth values were emitted.
Generated diagnostic caches are not evidence for another incremental build.

## Changed files

- `lib/data/private_test_environment.dart`: explicit mode/root validation and
  authorization/Standard approval gates; `lib/data/profile_paths.dart`: fixed
  private profile with no legacy fallback.
- `lib/data/cloud/private_windows_token_store.dart`,
  `lib/data/cloud/google_drive_auth.dart`: private-only backend routing for all
  purposes/operations, auth-readiness gate and non-secret account receipt.
- `windows/runner/private_credential_store.h`, `flutter_window.cpp/.h`,
  `windows/runner/CMakeLists.txt`: scoped native DPAPI channel and crypto linkage.
- `lib/main.dart`, `lib/app/private_acceptance_probe.dart`: startup exclusions,
  live path/native probe and private-only bounded acceptance commands.
- `lib/app/sync_controller.dart`, `sync_runtime.dart`: require disposable-account
  approval before private activation/exchange; normal algorithms remain unchanged.
- `lib/features/widget/native_widget_service.dart`: no companion/pipe operations;
  `lib/features/settings/software_updates_page.dart`,
  `lib/data/update_helper_launcher.dart`: disable updates in private mode.
- `lib/features/workspace/workspace.dart`: open existing auth-only settings page.
- `windows/CMakeLists.txt`, `tools/build-windows-release.ps1`: explicit private
  mode and companion omission; normal packaging default preserved.
- `test/private_drive_test.dart`, `test/private_credential_store_native_test.cpp`:
  scoped configuration/auth/backend/OS-process assertions.

## Evidence receipt

Local times are 2026-11-06 UTC+03. Detailed commands/source fingerprints/logs are
under the private root's `evidence/` and `logs/`. No full suite was run. Previous
protocol, installer and unchanged native-companion evidence remains scoped to
its recorded source, not a new cloud or background-worker acceptance pass.

| Invocation / purpose | Result / necessity |
| --- | --- |
| Production DB/JSON/encrypted-file SHA-256 and relevant HKCU startup snapshot before tests | Initial 18-path baseline captured without decrypting credentials. DB/WAL/privacy-session hashes later changed while installed companion remained active; encrypted credential file unchanged. No private app was running at that stage. Owner then confirmed installed app/widgets closed; fresh quiescent baseline taken. Earlier differences are retained, not falsely reported unchanged |
| MSVC `/W4 /WX`, native store fixture attempts 1/2 | Compile passes; fixture fails at concurrent child phase. Earlier DPAPI/atomic denial/corruption checks reach assertions; old headless spawn lacked explicit standard handles. Diagnostic fixtures retained |
| Corrected headless child harness, native fixture attempt3 | PASS: real DPAPI, wrong-scope ciphertext rejected, four simultaneous processes including same-key contention, independent keys, denied commit retains old bytes, private temp cleanup, corruption retained, explicit deletion scoped, invalid paths/keys refused, synthetic production sentinel unchanged. No personal credential used |
| Initial targeted Flutter analysis | One null-aware style info, then three multiline-brace infos in new main probe; no compile errors. Corrected. Later probe helper adds one brace info, also corrected |
| Final targeted analysis/main/probe closure | PASS, No issues found at their recorded changed-source boundaries. No unrelated analyzer/full-suite rerun |
| Private mode Dart fixture | Initial4 pass; expanded5 pass; final5 pass after account-receipt change. Actual auth connect/restart/refresh/disconnect use mocked HTTP and private-channel keys; errors have no shared fallback; gates reject missing/wrong approval; native/update launches blocked. Native encryption/process proof is the separate executable above |
| `flutter test --no-pub --concurrency=1 --reporter=expanded test/cloud/google_drive_test.dart test/profile_isolation_test.dart test/native_widget_service_test.dart test/software_updates_page_test.dart` | PASS22, normal-mode compatibility. Unchanged broader Sync/snapshot cases reused; these are simulated/host tests |
| Isolated archive, existing plugin junction helper, offline pub get | PASS; four existing-cache plugin links; no OS setting/dependency upgrade, lock unchanged |
| Private Windows Release helper with approved config and `-PrivateDriveTest` | PASS, 163.2s. Enabled config/main/AOT and three Microsoft-signed CRT guards pass. One necessary changed Windows candidate; no Android/native-companion/installer build |
| Dart MCP hot_reload / DTD connection | No active debug app; no personal app touched. This Release candidate is validated through actual cold launches, not a claimed hot reload or debug-runtime-error pass |
| Owned live smoke probe, then intended Runtime probe | PASS: actual native channel DPAPI round trip and deletion; real schema27/empty DB/integrity; actual APPDATA/LOCALAPPDATA/DB/store/executable receipts. Closed only owned smoke PID30864, retaining its state; intended app remains running |
| Quiescent production before/after test and live-launch hashes plus startup comparison | PASS18 paths, no differences, including actual encrypted production credential file. Relevant startup values unchanged. No production app/widget launched or stopped by private candidate |
| ZIP CRC, private-state exclusion, source/current-built-input continuity and recovery copy digests | PASS. Recovery folder `standard-acceptance-20261106/Recovery/20261106-152133` remains byte-identical; no production data copied into test profile |

## Minimum owner action / remaining evidence

Use the currently running private **Todorbit → Backups & Cloud → Connect Google
Drive**. Select only the approved fresh spare Google account and finish normal
sign-in/consent. Report completion; do not send passwords, tokens or credential
JSON. Keep this window open. No Windows test-user password is required.

After authorization, inspect the private account receipt and perform read-only
workspace preflight using the approved account. Only then create its Standard
approval and run synthetic exchange/replay/recovery tests. The app currently
cannot start Standard exchange without that gate. No personal workspace or
cloud content was accessed, no real Sync result is claimed, and the original
unfamiliar-task cause remains unproven. Private Sync and Android remain separate,
unverified acceptance. This foreground-only candidate has no widgets/background
companion/updater and is **not a release approval**.

DPAPI storage is tied to this Windows identity and exact persistent profile/key
path; keep the runtime root stable. Existing production authentication is not
migrated. Normal browser account selection remains owner-controlled. Offscreen
or source checks do not claim physical accessibility/launcher/DPI verification.
