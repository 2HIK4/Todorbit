# Final private acceptance (2026-11-06)

Application source: `2262edec8626d5806d518cfd680d7bc42159c787` on
`feature/sync-ux-refinement`, including implementation commits `9fd95b5`,
`6ca103a`, `f26f6b0` and documentation `2262ede`. No application code,
release version, OAuth configuration, production profile or cloud content changed.
The three preexisting storage-document changes are excluded.
Acceptance-only commit `6ba6d81` adds the harness correction and stronger backup
assertions; it does not change the application/package source above.

Scope is acceptance and private packaging, not another redesign. The canonical
UI and Todorbit regression workflows apply. This receipt supplements
[the refinement implementation/evidence](REFINEMENT_2026_11.md); it does not
replace the historical per-invocation results.

## Source and artifact continuity

`.buildlog/private-acceptance-20261106/baseline.json` records current revision,
protected-file hashes, every previous artifact digest and a comparison against
`refinement/source-final.json`: **zero application/dependency/build-config drift**;
all six recorded artifact identities match. All four commits were inspected
(`commits-review.txt`). This justifies reusing analysis, formatting, native
self-tests/IPC, Windows Release, Android Debug/alignment, the 50-case final
batch and the 24 failed full-suite cases' passing follow-ups. No full Flutter
suite or unchanged application build was rerun.

## Local private artifacts

Directory (absolute):
`D:\AI_Projects\life_manager\.buildlog\private-acceptance-20261106\packages`

Version remains `1.0.19-beta.12+35`, Android code 35, schema 27. The setup's numeric
registration/PE version is `1.0.19`, as required by the existing installer.
These candidates differ from the published beta12 despite the retained version;
identify them by this directory, application source and SHA-256, never version alone.
No release folder assets were overwritten.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `Todorbit-1.0.19-beta.12-schema27-github-debug.apk` | 148,684,069 | `01192d13226571fdeac48a21a47e2c27b014b4cc4a7846bb1298ba70deed9051` |
| `Todorbit-1.0.19-beta.12-win-x64-portable.zip` | 63,014,619 | `00a836e99f79d34604351c4cb77c9b326ea24aa802bd1f3232121cdb0b9694d8` |
| `Todorbit-1.0.19-beta.12-win-x64-setup.exe` | 47,645,884 | `d6e5a4fb3f8b9836785a1318cbcf3078498e9647e904f61a46230cf6a9fd96ce` |

Each file has a `.sha256` sidecar; `SHA256SUMS.txt` and `artifacts.json` retain
identities. Actual clean Windows Sandbox installer/process smoke also passes: registered setup,
separate installed/portable schema-27 profiles, integrity, in-place setup and
uninstall/reinstall preserve the synthetic populated database bytes. This is
not a native GUI/input or Google acceptance pass. Windows setup/portable are unsigned. Android is **debug-signed**,
GitHub flavor, arm64-v8a/x86_64, package `io.github.hik4.todorbit`, min SDK 26,
target SDK 36. Its v2 signature verifies. Certificate SHA-1:
`64:91:E2:9F:4F:0A:0B:AB:3C:9E:48:36:11:93:F8:C5:E2:BD:E1:B7`;
SHA-256: `9144c2df0aa461641f8570d62f880ee9e481c272a80673089a6799d111c9bf73`.
Use an empty disposable device/user; do not install this debug APK over a personal
release installation or uninstall personal data to resolve a signature mismatch.
These are local acceptance packages, not a new published beta or an update offer.

The portable archive is CRC-valid and all 29 applicable Release-bundle files are
byte-identical to the verified bundle, including AOT and companion. License
notices and PORTABLE-MODE are present; no database/log/key files are packaged.
Android's compiled Dart kernel contains the actual named-checklist table,
event project column, Customize navigation, Interface animations, filters and
draft-resource UI markers. Matching compile provenance plus prior isolated
Windows schema-27 readback establish build identity; Android marker inspection
is **not** Android runtime/migration proof.

## Platform workflows and evidence

| Workflow | Windows evidence | Android evidence / limit |
| --- | --- | --- |
| Task creation, draft URL resource, save/reopen | Prior isolated **live Debug** Driver journey, actual SQLite ID/resource readback and screenshots; reused unchanged | Host widget tests only; native touch/IME and SAF picker NOT TESTED |
| Managed attachment create/cancel and byte retention | Widget tests with synthetic picker plus new two-profile snapshot byte checks; physical picker/focus NOT TESTED on this candidate | Same shared host tests; provider/native return NOT TESTED |
| Event creation/project assignment/clear, occurrence and series split | Repository/Sync tests and editor widget interactions; current live native flow NOT TESTED | Mobile project-event editor/return-context widget test; native device NOT TESTED |
| Filters and combinations | Prior live filter dialog/Apply plus repository/widget assertions | Shared/mobile host assertions; physical touch and Back NOT TESTED |
| Recurring groups, closed occurrences, subtasks | Stable-ID projection and actual All Tasks widget interactions | Shared grouping host assertions; native list interaction NOT TESTED |
| Sidebar visibility/order/category expansion/custom entries | Widget tests, persistence and restored preferences | Mobile drawer/pinned-navigation widget assertions; touch NOT TESTED |
| Settings/theme/motion | Prior live dark-theme Settings; enabled/disabled/reduced-motion widget assertions | Grouped Settings/support and responsive host cases; system animation/accessibility behavior NOT TESTED |
| Widgets/date controls/quick add | Standalone and packaged native Release self-tests, actual first-launch/reload IPC; physical shell/menu/keyboard/DPI NOT TESTED | Cached projection/source, APK compile/alignment; actual launcher widgets, midnight/reboot/multiple IDs NOT TESTED |
| Conflict disclosure, choice persistence, stale decisions and later resolution | Deterministic dialog/widget/controller tests and offscreen light/dark/large-text renders | Same host rendering/logic, not native account/device acceptance |

Native Computer Use preflight now reports unavailable native pipe, **os error 2**.
No UI target was selected or personal app controlled. ADB `devices -l` is empty;
the previously unhealthy AVD has not changed, so it was not repeatedly booted.
These are environment limitations, not application-defect evidence. Flutter
Driver input, offscreen rendering, physical input and actual Android IME remain
separate evidence classes. The old platform checklist's historical test stop
was superseded for this task by the owner's explicit acceptance request.

## Deterministic Sync and recovery acceptance

All following evidence uses synthetic independent SQLite profiles, fake storage
or the real Drive adapter against a fake HTTP service. **No current real Google
Drive request, sign-in, upload, download or destructive cleanup was performed.**
Relevant case/log lines are indexed in `reused-case-evidence.json`; source hashes
and failure closure remain in the refinement receipt.

| Requested scenario | Deterministic evidence reused / added |
| --- | --- |
| Create, retrieve, edit, delete in each direction | `sync_drive_contract_test.dart`: production adapter CRUD Windows→Android and Android→Windows, restart/integrity checks; integration-1 passes |
| Offline delete versus edit / no silent resurrection | Whole-record causal decision and structural/deletion tests in portable merge/apply; matching offline deletes retain heads; unresolved delete/edit is preserved for explicit review, not silently resolved |
| Repeated sync / no duplicate records | Engine duplicate-click convergence and exact-ciphertext ambiguous-upload retries; apply idempotence and reviewed resolution without echo |
| Recurrence consistency | Apply original recurrence rows without generating another occurrence; concurrent rule/completion protection; final event recurrence/project split tests |
| Event projects / named checklists | Explicit Standard and Private idempotent exchange and schema-26 incoming replay passes in event-edge-corrected-11; no immutable journal rewrite |
| Standard and Private | Real codecs/repositories and workspace proofs exercised with synthetic keys; both relationship exchange paths pass; no real OAuth/key recovery acceptance inferred |
| Backup/restore | Original queued ciphertext retained; restored/latest/cloud-only records reconcile without inferred deletes; Before Restore and startup preservation pass. Added current schema-27 desktop→mobile→desktop snapshot assertions for event projects, group/item IDs, actual managed bytes and a mobile-created return task |
| Interrupted sync/recovery | Failed page/cursor, expired rescan, lost proof response, ambiguous upload, interrupted download/rate limit and restart/retry assertions in engine/Drive-contract tests |

The additional two-profile backup test passed on actual host SQLite. It emits
Drift's existing debug warning about multiple database instances; each profile
has a distinct executor/file, and identity/bytes/FK assertions pass. No warning
was suppressed. These simulated platform labels do not prove Android SQLite or
cross-client Google appDataFolder discovery on an actual device.

The original unfamiliar-task incident remains **UNPROVEN**. The verified fixes
and synthetic regressions do not establish which profile/snapshot/workspace
produced the owner's records. A safe investigation needs an explicitly approved
redacted incident reproduction (stable IDs, operation lineage, restore/reconcile
history and account/workspace identities), not guessed title matching or resets.

## Google authorization boundary

Windows Release receipt/config is Drive **disabled**, Desktop ID/required public
client-secret parameter empty. The distribution hides developer import controls;
it cannot conduct real Sync as packaged. Android Drive code is enabled by default
and uses Play services; the debug package/certificate pair above must be registered
in the **existing intended Cloud project**. Registration and account eligibility
are not verified here; the previous production certificate registration does not
cover this debug certificate automatically. No credentials were copied from old
profiles or historical outside-repository files.

**Exact owner action needed before real testing:** approve a named disposable
Google test account and the existing intended Todorbit Desktop OAuth client/config
via an outside-Git path; do not paste tokens or recovery keys. Confirm Drive API,
`drive.appdata` consent and the Android debug certificate/package registration in
the same intended project. Provide an isolated Android device/emulator with Play
services (or perform the manual Android steps). After an explicitly approved
enabled private Windows build is ready, the owner must choose that account and
complete normal Connect Google Drive consent on both isolated profiles. Stop on
any security or policy block; do not bypass it. Do not use the current personal
signed-in profiles. No real-cloud test begins before this boundary is satisfied.

Once authorized, use a unique run prefix and new workspaces: create/read IDs both
ways; edit/delete; offline delete/edit review; three no-op syncs; recurrence and
event project; separate Standard and Private with recovery material held by owner;
verified snapshot/restore/reconcile and retained Before Restore; interrupted
exchange/restart. Record only non-secret IDs/hashes/statuses. Do not erase cloud
content, reset an existing workspace or use Start New Sync on real data. Keep all
new disposable test objects until their retention/cleanup is explicitly reviewed.

## Focused validation and command ledger

All local timestamps/offsets, full logs and manifests are under
`.buildlog/private-acceptance-20261106/`. A failed initial inventory script used
an invalid Python encoding alias (`utf8-sig`); corrected to `utf-8-sig` before the
baseline was saved. A broad ignored-directory file inventory was stopped by its
verified owned rg PID; subsequent compiler discovery used registry and the known
publication path. Neither diagnostic changed application data or test evidence.

| Invocation / scope | Result and necessity |
| --- | --- |
| Git status/branch/show of the four commits; source/artifact SHA-256 comparison | PASS; no application drift, all original artifacts match, protected-file baseline recorded |
| Native CUA inventory; `adb devices -l` | BLOCKED native pipe; no attached Android device. No repeated unhealthy emulator boot |
| `tools/build-portable.ps1 -OutputDirectory .buildlog/private-acceptance-20261106/packages` | PASS; new package required, existing Release compile/self-test reused; OAuth/CRT/private-file/license guards applied |
| Inno 7.1.0 `ISCC.exe /DAppVersion=1.0.19 /O<private packages> /FTodorbit-1.0.19-win-x64-setup installer/life_manager.iss` | PASS, 70.656s; existing compiler, same installer definition/version/bundle, private output only. No host installation |
| `apksigner verify --verbose --print-certs` and `aapt2 dump badging` on exact APK | PASS signature, certificate/package/version/ABIs inspected; new identity check for installable handoff, unchanged alignment pass reused |
| Python ZIP CRC/full bundle equality/private-file/compiled Android feature audit | PASS, 29 applicable bundle files equal; all six compiled Android feature markers present; artifact-byte proof only |
| `python -m unittest discover -s tools -p test_windows_sandbox_prepare.py` | PASS 5 tests. Found schema-27 table count 53 vs stale 52; explicit reviewed mapping for 26/27, unknown schema fails before WSB emission; no application rebuild needed |
| `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter=expanded test/cross_platform_backup_test.dart` | PASS 1 extended scenario, 6s; previous case did not assert new relationships/managed bytes in both directions. No other Flutter suite rerun |
| `dart format test/cross_platform_backup_test.dart`; targeted `dart analyze test/cross_platform_backup_test.dart` | Formatting applied only to edited assertions; PASS No issues found; product-wide analysis reused unchanged |
| `tools/prepare-windows-sandbox-acceptance.ps1 -PackagesDirectory <private packages>` | PASS; prepared schema 27 / 53-table manifest, only two hash-pinned packages and guarded runner mapped; no profile, repository or credentials mapped |
| Guarded Windows Sandbox launch | PASS actual clean-identity smoke: setup/registration, installed and path-with-spaces portable creation/reopen (schema 27, 53 tables, integrity), packaged widget self-test, populated database preservation across in-place setup/uninstall and reinstall. `sandbox-acceptance.json`/`sandbox-packages.json` bind result to packages. GUI and Google remain UNVERIFIED |
| Final handoff checks | PASS changed documentation links and `git diff --check`; protected-file SHA-256 values unchanged; no app/config/version drift. `acceptance-source.json` and `invocations-index.json` retain acceptance-source and log identities. Closed only the observed task-owned Sandbox session after retaining its bounded result; no personal process touched |

## Manual acceptance handoff

Use only the disposable VM/user/device, synthetic fixtures and exact hashes above.
Retain exported recovery snapshots and logs. Do not run setup on the owner's
normal Windows account. The Android debug APK is for a fresh test device/profile.

1. **Identity/migration:** confirm empty isolated Data profile, schema 27 and
   expected package/source. Import only a copied synthetic schema-26 snapshot;
   approve Before upgrade, reopen and compare stable IDs, groups/projects and bytes.
2. **Editors/resources:** create/edit task and event, optional category/project
   including None, named checklist groups, repeat/occurrence/future scope. Attach
   a synthetic copy and link; cancel once, Save/reopen once; check original bytes,
   dirty-draft protection, pointer/Tab/Escape and file-viewer return.
3. **Lists/navigation:** combine/remove/clear filters; inspect recurring closed/open
   occurrences and filtered children; hide/reorder/restore sidebar/drawer, create
   a named category/project entry, expand categories, restart and verify persistence.
4. **Settings/motion/dialogs:** light/dark, short/narrow window/rotation, enlarged
   system text; animations on/off and OS reduced motion. Android: tap actual IME
   keys, dismiss with Back, then test dirty-editor Back. Verify grouped Settings
   and support destination. Exercise conflict details/later/apply with disposable data.
5. **Widgets:** two independent Tasks/Calendar widgets, previous/next/Today across
   month/year boundaries, quick add on displayed day, completion, midnight/resume,
   restart and no duplicate companion. Windows: shell attachment/Win+D, menus,
   keyboard/Narrator and 100/150/200% DPI. Android: launcher resize, portrait/landscape,
   TalkBack, multiple IDs, cached bounds, reboot and OEM behavior.
6. **Real Sync:** only after the authorization boundary above, execute every row
   of the Sync matrix on both platforms with recorded IDs/statuses and owner-held
   Private recovery material. Keep snapshot backup and incremental Sync distinct.

## Candidate decision

Local acceptance artifacts are prepared. **Not ready to approve a private beta
release claiming completed platform/Sync acceptance.** Current binaries are useful
for isolated local UI testing, with Windows OAuth disabled and Android debug signed.
No new version/code was assigned. Real Drive, physical Windows/Android acceptance,
and exact-candidate release CI/signing gates remain open.
Publication, push, tags and release changes remain
prohibited until the owner's explicit release-stage approval.
