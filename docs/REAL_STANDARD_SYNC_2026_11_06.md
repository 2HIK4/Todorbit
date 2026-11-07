# Real Windows / Google Drive Standard Sync acceptance — 2026-11-06

## Latest cross-platform checkpoint (2026-11-07)

[Corrected real Windows/Android Standard acceptance, current private artifact paths and limits](CROSS_PLATFORM_STANDARD_SYNC_2026_11_06.md#final-outcome-2026-11-07-utc03)
supersedes the earlier stage below:383 operations/all43 portable tables converge,
corrected Android restore/reconciliation and repeated checks/restart pass. Both
updated credential-isolated candidates preserve prior artifacts and production
baseline. Same approved spare account/workspace, no new sign-in. Historical
failures and archived invalid decisions remain explicit. Windows is closed;
authenticated SSD emulator retained. No release, Private Sync or cloud snapshot
testing. Earlier build/readiness receipts retain only their recorded boundaries.


Subsequent [Android environment and auth-only readiness](ANDROID_DRIVE_READINESS_2026_11_06.md)
reuses this workspace and APK. Retained AVD now runs on an isolated stable
emulator component, with documented startup warning; owner Google authorization
and actual Android exchange remain pending. Windows results below are unchanged.

**PASS for the scoped Windows-to-Drive acceptance below.** Real Google requests
were used; this is separate from the prior fake-cloud/deterministic passes.
No confirmed application defect was found in these scenarios. Android,
Private Sync and release acceptance remain open. No release approval is implied.

## Identity, source and isolation

Owner explicitly authorized a fresh Standard workspace on the previously
confirmed unused spare account, with synthetic data only. Before approval,
the unchanged candidate repeated its actual paginated metadata preflight:
zero non-trashed `todorbit-sync` objects in `appDataFolder`. The Google-verified
permissionId matched the private account receipt and owner confirmation.
Real-world spare-account identity is owner-confirmed; no email or independently
pre-registered spare ID was available. Production credentials were never decrypted
or used for comparison. Ordinary Drive files, other applications, trashed data
and snapshot-backup namespace `todorbit` were not enumerated.

Only then created `Runtime/STANDARD-SYNC-APPROVED.json`, pinned to that account,
Standard mode and its deterministic fresh workspace. The acceptance harness
checks the expected workspace in every listed object and checks live Google
identity before each host cloud scenario. No Start New Sync, workspace reset,
mode/account switch or cloud-file deletion occurred. Domain deletion tests
upload soft-deletion facts; they do not erase cloud files.

- Branch `feature/sync-ux-refinement`, HEAD `4dcda12e2182ac5ece33b3b98297056c4daafe53`,
  plus the existing frozen isolation changes. All20 implementation/test/build
  file hashes match `evidence/implementation-source.json`; source manifest SHA-256
  `a047e6b553165085f412012c1ce2ab74036eccb5d4ab2522dc970b067bf17b02`.
  No product implementation changed, candidate rebuilt or commit made this pass.
- Version `1.0.19-beta.12+35`, schema27. Exact candidate retained:
  `D:\AI_Projects\TodorbitPrivateBuilds\isolated-drive-20261106\source\build\windows\x64\runner\Release\Todorbit.exe`.
  Run with the existing verified `Start-PrivateDrive.ps1` launcher, rather than
  invoking the executable without its required isolated environment.
- Main SHA-256 `f11e0d60641345c849b87f5a6fd047792be449e81099904f2ac912d1bb3d60f7`;
  AOT `773bd3a09c728fb1b99c3df7091b92d8e62888941fb3425e40e14ca15d17a7c5`.
- Existing ZIP:
  `D:\AI_Projects\TodorbitPrivateBuilds\isolated-drive-20261106\packages\Todorbit-1.0.19-beta.12-schema27-isolated-drive-win-x64.zip`;
  SHA-256 `866c79f309079fa13368fec3271b3ee02075d5ae2c2a2355723825a6f7d61e9b`.
- Persistent Runtime under that root: database/settings in `Runtime\Profile`,
  encrypted OAuth/workspace storage in `Runtime\Profile\private-credentials`,
  APPDATA/LOCALAPPDATA in `Runtime\Roaming` / `Runtime\Local`; TEMP/TMP isolated.
  Actual native runtime receipts confirm these paths after the final restart.
  Credential-directory ACL still permits only owner, SYSTEM and Administrators.
  Native companion and updater remain disabled; no global startup changes.

The independent desktop repository is under
`evidence\standard-real\mirror`, with a separate SQLite database and device ID.
A small acceptance-only native DLL reuses the unchanged private DPAPI store
header to read **only** the marked Runtime's tokens-purpose file into memory.
It exposes no write/delete or production fallback. No decrypted credentials
are written to files, stdout, logs or Git. Its HTTP adapter uses the actual
GoogleDriveAuth, GoogleDriveProvider, SyncPairingService and SyncEngine. OAuth
refresh/sign-in is deliberately not attempted by that harness; the existing
private application owns its encrypted credentials. The mirror's persisted
Standard binding contains identity metadata only, no OAuth token or encryption
secret. This is an automated second **desktop** repository, not Android UI.

## Results

| Scenario | Result and actual evidence |
| --- | --- |
| Fresh Standard activation / upload | **PASS, REAL Drive.** Candidate creates proof and uploads one initial batch; provider checks metadata, downloads stored bytes and checks SHA-256 before acknowledging. Candidate `upToDate`, pending0. Subsequent actual listing finds2 objects: proof + batch. |
| Synthetic coverage | **PASS, repository setup.** Initially10 tasks: all6 statuses, dates/deadlines, priorities, estimates, Unicode notes, one full child and3 bounded daily occurrences. Category/project,2 events (timed project meeting and weekly all-day), named checklist with2 items and managed attachment. These are synthetic repository fixtures, not newly automated form-entry tests. |
| Independent download / reconstruction | **PASS, REAL Drive.** Empty second desktop database joins same workspace and downloads initial batch. All43 portable tables match the source. Initial reconstruction also matches stored modification revisions. |
| Edits, completion and deletion | **PASS, REAL Drive.** Task title/notes/status/priority/dates/estimate update, another task completion, task soft deletion, event edit and recurring-event soft deletion upload and reach mirror. All user fields match; original immutable operation facts match exactly. |
| Reverse propagation / app restart | **PASS, REAL Drive.** Mirror sends event edit and checklist completion. Restarted original candidate receives both, verified in its actual isolated database. Stored OAuth survives repeated candidate restarts without new sign-in. |
| Concurrent deletion versus unsent edit | **PASS, REAL Drive with controlled local divergence.** Separate repositories mutate the same stable task ID without exchanging first. Mirror then uploads its edit/downloads deletion: exactly1 explicit conflict, both candidate operation IDs retained. Existing lease/fingerprint-reviewed resolution selects deletion; original candidate receives that causal resolution and retains deletion. No silent conflict dismissal. The host network itself was not disabled. |
| Interrupted upload / retry | **PASS, REAL Drive plus injected response loss.** Final real resumable PUT commits; harness consumes then discards its successful reply and raises SocketException. Engine reports offline with durable pending batch. Close/reopen database and recreate engine; retry preserves exact batch ID/SHA-256 and reaches `upToDate`. Drive retains2 copies of that one batch; domain rows/operations remain deduplicated. No remote copies deleted. This is controlled response-loss testing, not an observed OS/network crash. |
| Backup / restore / reconciliation | **PASS, local BackupService using REAL downloaded data, followed by REAL Drive resync.** Snapshot, add unsent sentinel, reviewed restore, Before Restore, quarantine, fresh-device reconciliation with original read-only history. Restored rows match snapshot; pending sentinel survives retained history and reaches original candidate. This does **not** claim a real cloud snapshot-backup upload/restore in namespace `todorbit`. |
| Repeated exchanges | **PASS, REAL Drive.** Four additional no-op exchanges retain identical portable rows and immutable-history count. No duplicate tasks or unexpected overwrites. |
| Final integrity and restart persistence | **PASS.** Both databases agree on43 portable tables and81 immutable operations. Exactly12 expected stable task IDs:10 active,2 soft-deleted;1 active/1 deleted event;3 recurrence slots; managed attachment bytes/hash match. Integrity OK, foreign keys0, pending/unknown operations0, unmaterialized groups0. Rechecked after final cold launch. |
| Production/recovery safety | **PASS.** All18 baseline production database/settings/encrypted-credential paths match before exchanges and after final restart; relevant Windows startup values unchanged. Both recovery profiles retain all15 recorded file hashes. All3 protected unrelated source documents retain their hashes. |

Final table comparisons exclude device-local optimistic `updated_at` revisions
and managed-resource local targets. All other fields, including planned,
deadline, creation, completion and deletion dates, match. The immutable journals
match exactly, including original source values and causal parents. The source
deliberately calls `_nextTaskRevision` when applying to an existing record;
different local revision timestamps are not evidence of lost data.

Final real cloud inventory: **11 objects**:1 proof and10 operation objects
representing9 unique batches (one retained duplicate from the lost-reply case).
All belong to the pinned workspace. No unexpected task ID or resurrection was
observed in these synthetic cases. The original unfamiliar-task report remains
**unreproduced and unexplained**; this pass does not prove its original cause.

The private app was left open normally as owned PID16828 at17:41 UTC+03,
responding, about269.4MiB working set. Host free RAM at that observation was
2335.7MiB of16114.8MiB. No Sandbox, emulator or separate Windows user was used.
Foreground-only background-check unavailability on first activation is expected
for this deliberately companion-disabled build; the actual Sync completed.

## Commands, failures and reuse

Private evidence root:
`D:\AI_Projects\TodorbitPrivateBuilds\isolated-drive-20261106\evidence\standard-real`.
`invocations.json` records commands, log timestamps/hashes, scope, rationale,
results and failures. Operational receipts use explicit UTC or UTC+03 offsets.
`final-integrity-before-restart.json`, `final-integrity.json`,
`final-live-isolation.json`, `source-reuse.json` and `recovery-preserved.json`
pin the final boundaries. Scripts/harnesses remain outside tracked source.

- `Run-AcceptancePhase.ps1 -Phase <unique phase> -Action close|preflight|sync|launch`:
  verifies account/build/runtime/production baseline/startup, closes only its
  observed private PID normally, and starts the existing candidate with the
  existing compiled operational switch. Each phase retains its receipts.
- `TODORBIT_FIXTURE_PHASE=seed|edit|offline-delete` and
  `TODORBIT_CLOUD_PHASE=download|pull-edits|return-edit|offline-edit|conflict|resolve|interrupted|restore|replay`:
  `flutter --suppress-analytics test --no-pub --concurrency=1 --reporter=expanded .buildlog/standard-drive-20261106/real_fixture_test.dart`
  or `real_cloud_test.dart`. These narrow helpers exercise the named new real
  environment boundaries; no full-suite repeat. `python Verify-FinalStandard.py`
  performs read-only final comparisons, with a justified second check after the
  actual app restart.
- First wrapper guard used an incorrect owner-confirmation property name;
  stopped before process/network action, corrected, fresh preflight passed.
  First pull helper failed compilation because `anyOf` has a7-argument limit;
  corrected list assertion before running any cloud operation. Next pull
  assertion wrongly required unchanged local optimistic revisions; diagnosed
  against source, preserved failed log, corrected semantic comparison plus
  exact immutable-fact assertions, then passed. Neither is an application defect.
- Final Python full-dictionary baseline export initially omitted `sha256:null`
  for absent WAL files and raised a false mismatch. Immediate per-field diagnosis
  verified all18 existence/hash matches; corrected null handling passes and saves
  `production-after-real-standard.json`. Earlier PowerShell hash checks were
  already correct. No production change or additional cloud mutation occurred.
- Drift warns about multiple AppDatabase instances in comparison/restore helpers.
  They use explicitly different files/executors; recovery source opens read-only.
  Warning retained. Final integrity, full table and immutable-history comparisons
  pass; no corruption observed.
- A small DLL was compiled for the acceptance harness only; **the candidate was
  not rebuilt**. Previous native credential isolation/concurrency/corruption/
  failed-write,5 private-mode and22 normal compatibility cases, static analysis,
  packaging and deterministic Sync/recovery evidence remain reused for their
  unchanged source. Android, native widgets, installer and full suite not rerun.

## Remaining acceptance and next step

**Ready for the next isolated Standard Windows/Android acceptance phase; not
approved for public release or complete cross-platform beta acceptance.**
No further owner action is required to retain these Windows results.

1. Establish a healthy isolated Google Play AVD before using the retained,
   registered debug APK. Previous system_server/ART failures occurred before
   application installation and remain an environment blocker. Do not run
   Sandbox or touch the owner's phone. Reuse artifacts and preserve emulator
   userdata; run platforms sequentially if RAM is constrained.
2. Owner selects/signs into **the same approved spare Standard account** on that
   emulator; verify live account/workspace IDs before first exchange. Android
   OAuth, bidirectional creation/edit/delete, offline conflicts, recurrence,
   project links, checklists, attachment bytes, process death/recovery and repeated
   Sync remain unverified on the actual Android platform.
3. Physical IME/Back, launcher widgets, notifications/background jobs, TalkBack,
   native Windows input/Narrator and full platform checklists remain separate.
   This pass adds no physical UI/launcher evidence. Managed attachment opening
   through OS handlers was not newly tested, only transferred content integrity.
4. Real Private Sync needs separate explicit authorization and a second disposable
   account, including passphrase/key recovery. No account/mode switch performed.
   Real token expiry/revocation/forced refresh and real cloud snapshot backup
   restore were not newly exercised. Abrupt OS/process failure at arbitrary write
   points remains covered only by prior deterministic tests, not this real run.

Do not reset or clean this disposable cloud workspace during handoff. Keep
fixtures, duplicate immutable batch, snapshots and logs for the Android phase.
No commit, push, tag, version change, publication or production OAuth change.

Related receipts: [credential isolation](PRIVATE_CREDENTIAL_ISOLATION_2026_11_06.md),
[prior environment acceptance](STANDARD_DRIVE_ACCEPTANCE_2026_11_06.md),
[refinement evidence](REFINEMENT_2026_11.md),
[platform checklist](UI_UX_PLATFORM_ACCEPTANCE.md).
