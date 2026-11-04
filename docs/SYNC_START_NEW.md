# Start New Sync implementation and beta 11 receipt

2026-11-04 (+03:00), baseline `29091e8`, branch
`feature/start-new-sync-beta11`. Owner authorizes the feature, targeted safety
checks and a new experimental Windows/Android publication after safety gates.
The three original storage documentation changes remain outside this task.

## Protocol and recovery decisions

Replacement uses a random workspace identity, authenticated existing v2 proof
and batch formats, and append-only v3 generation heads. Heads carry no planner
content or encryption keys. Their parent graph has one active tip; concurrent
tips stop exchange and cleanup rather than selecting a timestamp winner. They
remain after content cleanup so recreated legacy objects cannot become active.
Legacy clients cannot obey a new barrier: their writes remain isolated under
their old workspace IDs. Update and explicitly reconnect other devices.

An independent integrity-checked manual SQLite backup and its SHA-256 precede
confirmation. A separate profile-keyed secure-store operation retains phase,
credentials, immutable commit bytes, snapshot identity and previous protected
pairings. SQL rebind preserves planner rows, stable IDs and all old journals,
batches and conflicts; the existing portable allowlist seeds fresh operations.
It rejects restores, account changes and live SQL leases. New operations upload
and every seed batch is downloaded, decoded/decrypted and checked against its
retained hash before the head is committed and read back. Only then are selected
retired workspace proof/operation files deleted. Backups use another namespace.
Cleanup is retryable and cannot be called complete until a fresh listing passes.
Old devices may recreate isolated old files; historical revisions/copies are not
promised erased. Unknown ownership/formats and incomplete foreign staging block
replacement. Resume on the original device, retaining its protected storage.

Drive primitives were checked against official
[appDataFolder guidance](https://developers.google.com/workspace/drive/api/guides/appdata)
and [files.delete](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/delete).
The protocol assumes no multi-file transaction or compare-and-swap. Immutable
heads detect forks; namespace isolation prevents cross-generation operations.

Ultimate UI/UX was applied to Settings, inline errors, status entry point,
scrollable confirmation, private credential reuse and actual phase progress.
Project guidance already mandates the skill; it is preserved. Physical Windows,
Android Back/IME, accessibility tools and live Drive acceptance remain unobserved.

## Evidence policy and invocation ledger

Consulted the test index, optional-encryption/manual-build/beta10 receipts,
workflow, relevant architecture, backup, OAuth, platform and release guidance.
Reuse unchanged backup creation/integrity, allowlist/codec crypto, native/profile,
signing, installer and updater implementation evidence only at unchanged
boundaries. Pairing/controller/adapter/UI behavior changes require focused checks.
No full suite, broad analysis, integration/emulator, golden matrix, live Google,
benchmark or duplicate build is authorized. For this beta the explicit owner
instruction overrides default broad CI gates; publication commits use `[skip ci]`
without changing workflows. Package/signature/public-delivery gates still apply.

Detailed logs and source hash manifests are in ignored
`.buildlog/verify/start-new-sync-beta11/`. Each invocation below records its
timestamp, exact command and source manifest there; failures are retained.

| Invocation / source | Scope, reason and result |
| --- | --- |
| Initial Git status/branch/HEAD; focused source, instructions and receipt reads | Baseline above; only three unrelated storage documents dirty. No test execution. |

Publication outcomes are appended below after their gates pass.

| `dart format` changed Dart paths (`format-input.json`, `logs/format.log`) | PASS 16 files parsed, 14 formatted. Necessary first implementation formatting. Later test-only format and second source formatting are separately retained. |
| Connected Dart MCP `analyze_files` on 14 changed production paths | Initial call blocked: no registered root. `roots add file:///D:/AI_Projects/life_manager` followed by the same targeted request: PASS no errors. No broad analysis. |
| Connected Dart MCP `hot_reload` | BLOCKED: DTD connected but no running debug app. No personal app launched; live UI remains unobserved. |
| 2026-11-04T03:52:33.907588+03:00 `--no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter expanded --timeout=2m test/cloud/sync_reset_service_test.dart test/cloud/sync_pairing_service_test.dart test/cloud/sync_standard_mode_test.dart test/smart_sync_controller_test.dart` | PASS 24 tests (6 new safety, 5 legacy pairing, 5 Standard/private format, 8 shared controller). SQL multi-instance debug warnings are expected for separate disposable databases. Two additional reset-only guards were added after the six new safety cases completed, while later compatibility cases were running. Those optional-reset-vault/restore branches do not affect the null-reset-vault compatibility fixtures; their new safety coverage is rerun separately, not relabeled. Source source-check1.json retained. |
| 2026-11-04T03:55:52.566117+03:00 `--no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter expanded --timeout=2m test/cloud/sync_reset_service_test.dart test/sync_conflicts_dialog_test.dart test/cloud/sync_drive_contract_test.dart --name unknown legacy key&#124;ambiguous staged upload&#124;cleanup failure&#124;private replacement&#124;wrong account, checkpoint&#124;error causes&#124;new sync confirmation&#124;specific sync errors&#124;production adapter replacement` | Six reset cases PASS; then INTERRUPTED in the first UI case: async font file read under the widget fake clock stalled. Stopped only the owned test VM/runner. Corrected font read and wrapped image I/O with tester.runAsync. No UI or adapter pass claimed for this invocation. |

| 2026-11-04T03:59:19.895142+03:00 `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter expanded --timeout=2m test/cloud/sync_reset_service_test.dart test/sync_conflicts_dialog_test.dart test/cloud/sync_drive_contract_test.dart --name unknown legacy key&#124;cleanup failure&#124;new sync confirmation&#124;specific sync errors&#124;production adapter replacement` | PASS five selected cases: new review barrier and fork supersession; both-theme 380x780 at 200% scroll/acknowledgment; error action routing/private reconnect; production Drive head query/readback/deletion and HTTP classifications. Dark/light confirmation PNGs inspected. Source `source-safety3.json`. |

| 2026-11-04T04:01:15.334059+03:00 `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter expanded --timeout=2m test/cloud/sync_reset_service_test.dart test/cloud/sync_pairing_service_test.dart --name private replacement&#124;ambiguous staged upload&#124;lost key recovery` | PASS three selected cases: ambiguous upload/corrupt readback; private replacement with an actual 9-second upload wait and observed lease heartbeat; fresh reconnect device identity with subsequent successful exchange; typed legacy key recovery. Source `source-safety4.json`. |

| 2026-11-04T04:03:53.372120+03:00 `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter expanded --timeout=2m test/cloud/sync_reset_service_test.dart test/cloud/sync_drive_contract_test.dart test/android_google_drive_auth_test.dart --name cleanup failure&#124;production adapter replacement&#124;Android sync authorization errors&#124;error causes` | PASS four selected cases: fork exchange with bounded metadata verification; exhaustive safe error presentation; production adapter reset/classification; Android native network/session/cancellation/Play-services classification. Necessary after final engine/Android changes. Source `source-safety5.json`. |

Final changed-path MCP analysis: PASS no errors on 18 production/test paths,
then seven final engine/Android/error paths after their changes. Hot reload was
attempted again: BLOCKED, no running app on connected DTD. Formatter logs and
pre-invocation hash manifests stay local. Counts overlap; do not sum as unique
coverage. Previously passed cases are reused where their relevant code is unchanged.

## Manual acceptance checklist (owner; disposable accounts/data)

1. Back up first. Verify original credentials still unlock a disposable legacy
   workspace. Separately choose Start New Sync without its old password. Inspect
   the selected account/workspace and local snapshot; cancel once: no cloud change.
2. Repeat and explicitly acknowledge cloud-only loss. Choose Standard or fresh
   private credentials with recovery acknowledgment. Check local tasks, events,
   settings, managed attachment bytes, stable IDs and relationships remain.
3. Interrupt upload/network, restart and Resume new sync. It retains the same
   generation. Old cloud content remains until the new readable seed is activated.
   Keep protected storage and the recovery snapshot on the original device.
4. Deny/interupt deletion: new sync stays active with cleanup incomplete. Retry
   cleanup. Full completion means a fresh scan found no selected retired content
   at that time; non-content safety heads remain. Updated old devices reconnect;
   old clients may recreate isolated files, so check cleanup again if needed.
5. Reconnect another updated device with offline edits. Standard needs no extra
   credential; private needs its new credential. Local records seed new operations,
   retained old journals do not replay, and meaningful conflicts stay reviewable.
6. Check offline, canceled authorization, wrong account/password and quota actions.
   Concurrent setups retain both histories; explicitly choose which local state
   seeds a replacement. Unknown ownership/future formats block deletion.

Live Drive, physical Windows/Android input/IME/background timing, installation
and actual upgrade retention are NOT VERIFIED. Schema remains 26; portable
allowlist and crypto formats are unchanged. Mode conversion/passphrase rotation
remain unavailable. Joining an isolated generation requires beta11 or later.

## Publication candidate

Remote inventory at 2026-11-04T04:02:04+03:00 confirms beta11 unused. Original
storage/OAuth/signing hashes match the beta10 preservation receipt. Version
`1.0.19-beta.11+34`; original AppId/profile/package/signing/schema remain.
Source metadata synchronization, scoped docs checks and artifact identities follow.

2026-11-04 final source review: all final safety5 Dart hashes match; version-only
metadata follows, with no application logic edit after passing targeted checks.
`git diff --exit-code ed23095 -- installer/life_manager.iss
lib/data/profile_paths.dart lib/data/app_database.dart android/app/build.gradle.kts
android/app/src/main/AndroidManifest.xml` passes. Reuse prior data-preserving
upgrade evidence only at these unchanged boundaries, not physical beta11 acceptance.
`python tools/dev/check-docs.py` on the seven changed feature/release documents
passes zero errors; `git diff --check` passes. Original storage/signing/OAuth
hashes unchanged. Windows and Android build helpers remain unchanged.


Initial candidate source was `574cd0dae7c6cbf0a6d17584439083c9fe241ab3` (superseded before publication). Release source commit
includes version beta11+34. Documentation finishing will use a separate commit,
without moving the eventual tag. No broad CI run is claimed.

| Build / artifact invocation | Actual result and necessity |
| --- | --- |
| 2026-11-04T04:08:31.9760448+03:00 `.buildlog/verify/start-new-sync-beta11/build-windows.ps1` -> `tools/build-windows-release.ps1`, `installer/build-installer.ps1 -Compiler <existing Inno7>`, `tools/build-portable.ps1 -OutputDirectory <task/core-packages>` | PASS first Windows compile (184.5s), native companion/CRT/OAuth/version gates and both packages. Original config/local numeric installer restored. End 2026-11-04T04:12:47.1174038+03:00; `windows-result.json`, `logs/windows-build-package.log`. |
| 2026-11-04T04:13:49.351326+03:00 `python .buildlog/verify/start-new-sync-beta11/audit-artifacts.py --windows-only` (recorded after execution) | PASS 28 bundle files, exact ZIP membership/content/CRC, licenses, five explicit Windows assets and matching sidecars/manifests. Reuse this audit after Android; no repeated ZIP read. `artifact-audit-windows.json`. |

| 2026-11-04T04:13:10.6601057+03:00 initial Android build/preparer, existing production key/cache, `--apk-only --version 1.0.19-beta.11 --version-code 34` | PASS compile (243.4s), eight native libraries aligned, production package/certificate/code34 metadata. End 2026-11-04T04:17:56.4474438+03:00. Superseded before upload by the privacy-label fix below; no build success is discarded or relabeled. Existing Kotlin future-migration warning did not fail compilation. |

### Reproduced privacy presentation failure and necessary rebuild

Final review found that after Standard activation succeeds but old-cloud deletion
fails, the controller could retain the old Private label and old unlock prompt.
No cloud deletion ordering/data loss occurred, but showing the wrong encryption
mode is unacceptable. The candidate was never tagged/pushed/published. This real
failure requires one replacement build per platform under the owner's exception;
no duplicate builds are run simply to refresh evidence.

| 2026-11-04T04:16:54.242426+03:00 `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter expanded --timeout=2m test/cloud/sync_drive_contract_test.dart --name production adapter replacement` | FAIL reproduced expected Standard=true, actual false after synthetic production Drive deletion was denied. `logs/privacy-regression-before.log` retained. Source manifest `privacy-regression-invocation.json`. |

| 2026-11-04T04:18:12.307025+03:00 `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter expanded --timeout=2m test/cloud/sync_drive_contract_test.dart --name production adapter replacement` | PASS same single grouped production adapter case, now including cleanup failure, active Standard label, cleared old credential prompt, cleanup retry and stale-device fencing. Fix only refreshes actual protected pairing after cleanup/complete and matching SQL binding. `logs/privacy-regression-fixed.log`. Source manifest `privacy-fix-invocation.json`. |

Targeted MCP analysis on the two changed paths: PASS no errors; hot reload remains blocked by no running debug app. All other safety passes are reused at unchanged reset/protocol boundaries.
