# v1.0.17 final audit and pre-release publication

[Public pre-release](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.17)
published **2026-10-28 10:38:07 UTC / 13:38:07 Amman**. Version **1.0.17+18**,
tag/source **cae2b4be4f9c93a2dcde4de2fb0b5ecc4d69ce5e**. The owner explicitly
authorized audit, fixes, promotion and publication. It is Pre-release, not latest
Stable. Existing tags/releases were not overwritten.

[Release notes](TODORBIT_1_0_17_RELEASE_NOTES.md).
[Implementation and manual checklist](WIDGET_SETTINGS_UPGRADE.md).

## Audit and fixes

Reviewed implementation **d8f2bc8** and documentation **72b584e**, then prepared
**cae2b4b**. Confirmed and fixed three issues, with regressions:

- An unchanged past/custom or elapsed-session reminder could block an ordinary
  task edit, including when the companion was unavailable. Timing/availability
  validation now applies to explicitly changed notification configuration.
- Navigation checked editor/modal state before asynchronous refresh but did not
  recheck it afterward. A draft opened in that interval could be superseded.
  Delivery now defers again after awaited work, preserving a newer queued request.
- Compact Calendar task/session markers shared the event-dot baseline and could
  overlap. Auxiliary shapes now occupy upper corners; event counts stay centered
  below the date. Native geometry assertions cover the separation.

| Area | Available verification |
| --- | --- |
| Navigation order | Pointer drag, Up/Down, hidden destinations, Undo/Redo, Apply/persistence, native top/bottom/side layout fixtures; live applied All Tasks-first order. |
| Presets | Built-ins and independent custom libraries; create/rename/duplicate/delete, draft/Apply/Cancel, restart serialization, actual local/cloud restore application. |
| Settings history | Slider coalescing, bounded Undo/Redo, branch invalidation, focused text preservation and editing contexts; narrow/enlarged-text settings tests. |
| Appearance | Independent row/selection/shell alpha and text colors in both native palettes; Flutter surface controls inspected, native offscreen fixtures and existing layout tests. |
| Calendar | Four-/five-/six-week minima, divider ratio constraints, independent agenda scrolling, 0–6 event counts, deduplication/cancellations and moved occurrences. |
| Task reminders | Explicit-Off defaults, persistence/migration, timing edits, disabled/completed cases, session rescheduling and transactionally unique claims; existing reminder data retained. |
| Direct navigation | Typed stable IDs/nominal dates, task/event editor routing, existing single-instance/IPC coverage, async draft protection and missing-item feedback. No Scheduled item popup in the normal path. |

No quiet-hours policy existed to migrate; existing due/event/privacy preferences
retain their meanings. Relative task notifications use upcoming work-session
times, never an invented time for a planned date/deadline.

## Release gates

- [Exact-source Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40671604747)
  **PASS**: clean analysis, **356 tests passed / one opt-in integration skip**,
  OAuth/configuration/package gates, Windows x64 Release, packaged native
  self-test, portable ZIP, installer, checksums and retained candidate artifact.
- Local audit focus **9 passed**; all 31 changed Dart files pass formatting,
  local whole analysis and diff checks pass. Packaged native `--self-test` and
  `--lifecycle-self-test` pass, including simultaneous HWNDs, independent
  visibility/reload/restart. These do not prove physical input or DPI acceptance.
- Enabled local packages use the same Desktop build parameters bound to the
  SHA-256-verified public v1.0.16 ZIP/receipt. Source config is restored to its
  disabled/empty default. Runner/AOT/config consistency receipt, full 33-entry
  portable bundle equality, ZIP CRC and private-file guards pass. No credential
  values, user data or machine settings were added to source or packages.
- A complete private five-asset draft passed exact UTF-8 notes/source,
  classification, sizes and GitHub SHA-256 checks before publication. Anonymous
  release HTML/API, all public hashes/sidecars/manifest and byte-for-byte binary
  download equality pass. Public portable ZIP CRC passes.
- The unchanged production `SoftwareUpdateService`, with installed version
  **1.0.16**, discovers, downloads and verifies **v1.0.17** in installer and
  portable modes. Transfer progress and size/SHA-256 verification pass; Stable
  excludes it. Discovery checks do not execute the packages.

## Data, updater and migration acceptance

The real bundled helper exercised readiness/parent exit, an injected wrong-version
rollback to public v1.0.16, complete replacement at the same isolated portable
path with spaces, version verification and restart. All **44 legacy tables and
their values** retain matching digests. Tasks, categories, projects, sessions,
existing event reminders, theme/calendar settings and custom widget presets survive.

The v1.0.16 fixture is a disposable schema-21 database constructed from synthetic
data. The new Release starts at the existing upgrade gate. With native Computer
Use unavailable, an explicitly guarded test worker exercises the same core
approved-upgrade path: verified schema-21 Before upgrade backup, then schema-22
migration. Restarting the actual new Release succeeds. New task reminder fields
are Off and the new delivery ledger is empty. Physical clicking of the approval
button is **unverified**, not claimed by this worker test. Binary rollback does
not reverse a migrated database.

Local snapshot and encrypted cloud tests verify restored widget files/preset
libraries are applied, not merely serialized. Cloud tests use the fake Drive
provider with real encryption/staging; real-account OAuth was not repeated.
Personal Run/installed-registration fingerprints remain unchanged; no registered
installer was executed. All test profiles and apps are disposable.

## Published assets

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Todorbit-1.0.17-win-x64-setup.exe | 47,246,819 | `173b9fa48d697d516b19058e8b615392aff958d2ab3856a4b33f0d8f9eae9296` |
| Todorbit-1.0.17-win-x64-portable.zip | 62,418,487 | `ff523d6eda071bbd4d7bbd27e472abd4d3aad3341cebf458b2b84b475fb8efbb` |

The release also includes both `.sha256` sidecars and
`Todorbit-1.0.17-SHA256SUMS.txt`. GitHub-generated source archives are separate.
Packages remain unsigned; checksums are not publisher signatures.

## Remaining acceptance and upgrade

Windows 10, physical mouse/keyboard/DPI/monitor transitions, Explorer restart,
Win+D, screen readers, actual OS notification receipt and registered installer
upgrade/uninstall remain unverified. The Computer Use native pipe failed after
retry/reset; no security settings or authentication were automated. Live Flutter
driver inspection/hot reload worked. A stale disposable debug companion initially
blocked debug installation; closing its isolated IPC instance resolved the lock.
No owner-installed process was stopped. Earlier evidence is not promoted to a
physical acceptance pass. Google branding/public OAuth policy limits remain.

Create a verified backup, choose **Pre-release** in Software Updates, check for
v1.0.17 and use the reviewed update flow. Inspect the schema-upgrade backup before
approval. Keep portable paths stable and retain rollback/Before upgrade backups
until the updated data and settings have been checked. Follow the detailed manual
feature checklist in the implementation guide before stronger compatibility claims.

Ignored evidence: `.buildlog/release-1.0.17-20261028/`, including CI logs,
artifact/draft/public integrity receipts, native logs and updater/migration checks.
Later documentation receipts do not move the release tag.
