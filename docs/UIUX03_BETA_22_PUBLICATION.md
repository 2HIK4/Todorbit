# UIUX-03 Beta 22 publication verification

Owner authorization on 2026-11-15 explicitly permits push and automatic experimental
publication after all mandatory gates pass. Stable must remain unchanged.
Version: `1.0.19-beta.22+45`; intended tag: `v1.0.19-beta.22`.

Status: **DRAFT / CI GATED**. No public updater installation is claimed.
The initial candidate packages/runtime receipt are **SUPERSEDED**. Replacement
packages below include only the three confirmed CI product repairs; final CI gates
remain mandatory. No unchanged binary was rebuilt after the test-only follow-up.
Public review branch: `codex/beta22-release`; local branch:
`codex/independent-beta-review`. [PR #2](https://github.com/2HIK4/Todorbit/pull/2)
targets the preceding reviewed beta branch, avoiding unrelated history on main.

## Evidence retained and artifact equivalence

[Independent review](UIUX03_CODEX_REVIEW_2026_11_15.md) and
[candidate receipt](UIUX03_BETA_22_CANDIDATE.md) retain the 84 focused passes,
Windows installer/portable/Sandbox retention, production Android signing,
schema-29 compatibility and artifact-specific updater contracts. No local broad
suite or unchanged package rebuild was repeated. Windows remains unsigned under
the accepted policy; Android retains its production signing certificate and code45.

Release source `0e12e96fdcde1fb3c98381e83fd96fa503a62c69` adds only public release
notes after candidate checkpoint `121f85b`. The subsequent Android integration
fixture repair adds the required Details -> Edit -> save -> Details -> Back path,
retaining task identity, editing, persistence, calendar and restore assertions.
It changes no compiled product input, package, migration, alarm or dependency.
Scoped analysis passes; the entire repaired integration fixture also passes in
the host widget runner (not an Android/device claim).

Initial draft staging changed only `ANDROID-RELEASE-NOTES.md` and its checksum
entry to match [the public release body](UIUX03_BETA_22_PUBLICATION_NOTES.md).
The confirmed product repairs then required the replacement package set below;
the original candidate hashes are not the final publication hashes.

## Actual Android 16-KiB runtime: PASS

[Workflow 43733159492](https://github.com/2HIK4/Todorbit/actions/runs/43733159492)
passes on `0e12e96` using the actual production-signed APK SHA-256
`01686c128c63f55b69aa03fe55768fa81f2d5016a200de78649301b7d13986ad`.
Downloaded `Android-16KiB-runtime-evidence/receipt.json` records:

- Actual `getconf PAGE_SIZE`: **16384**.
- Android16 x86_64 `google/sdk_gphone16k_x86_64/emu64xa16k`, build
  `BE2A.250530.026.F3/13894323`.
- Stable 40-second system baseline; production APK installs and Flutter renders.
- Task creation, navigation/completion and database retention after restart pass.
- No observed crash or ANR in the exercised runtime.

This is runtime evidence, separate from the earlier alignment pass. The optional
previous-APK upgrade path was not executed; physical-device updater installation
remains manual. Local raw evidence is under
`.buildlog/uiux03-beta22-publication/runtime`; the cloud artifact retains the
receipt, logs, UI hierarchies and screenshots.

## Replacement candidate acceptance

Compiled product source: `62593e35c9236f1c7ae11d1758baff9071e3fb4b`. Subsequent changes
are the host draft-editor fixture correction and release receipts/asset identities;
the compiled source trees and dependencies must remain identical before publication.
Version remains `1.0.19-beta.22+45`. The original candidate manifest remains historical;
[publication asset identities](UIUX03_BETA_22_PUBLICATION_ASSETS.json) now bind all ten
replacement files. Package changes are explained by the three confirmed fixes below.

- Windows Release: PASS, 140.6s; approved enabled Drive configuration and signed CRT.
- Portable ZIP and installer: PASS; ZIP CRC, exact bundle bytes, licenses/helper,
  private-file exclusion, AOT/configuration receipt and checksum contracts pass.
- Signed Android rebuild: PASS, Gradle324.5s; eight ELF/ZIP native libraries aligned.
  Preparation verifies package, production certificate and code45 above published44.
- Replacement artifact-specific production updater contracts:3/3 PASS. An initial
  test compiler launch failed because its OS temporary `output.dill` disappeared;
  using a dedicated task-local TEMP/TMP resolved that environment failure.
- Replacement APK actual 16-KiB runtime:
  [43741858701](https://github.com/2HIK4/Todorbit/actions/runs/43741858701) PASS on62593e3.
  Receipt binds SHA-256 `df851faed31acb1d683641f9f91a6a7981c65a31a9a5d9e99308cefc89ab485d`,
  actual page size16384, Android16 x64 `google_apis_ps16k`, install/render, task create,
  persisted restart/completion and no observed crash/ANR. This is actual runtime,
  not alignment-only evidence. No previous-production-APK upgrade was exercised.
- Normal Windows Release application: launched on the host with child APPDATA and
  LOCALAPPDATA under `.buildlog/uiux03-beta22-publication/host-profile`; verified
  the resolved database before interaction. Its schema29 initializes and read-only
  integrity check is OK. **User-reported PASS** for create task, Details -> Edit ->
  save and Focus start/pause. Automated desktop interaction is UNVERIFIED: both
  desktop-control interfaces fail to initialize (`failed to write kernel assets`).
  The owner requested normal-app testing; no further Sandbox testing is used.

Primary replacement hashes:

| Asset | SHA-256 |
| --- | --- |
| Android universal APK | `df851faed31acb1d683641f9f91a6a7981c65a31a9a5d9e99308cefc89ab485d` |
| Windows portable ZIP | `6e39f9074d45295448b4ae9ba8d3305978387b87617a94e82fa0f8c2f6fba6f1` |
| Windows installer | `97a6765f6d39a3ddf8e29dc3c5fd16878fe07b7d9937d30d56500ed4b7bd2043` |

## CI and publication gates

Windows run [43732459000](https://github.com/2HIK4/Todorbit/actions/runs/43732459000)
on `0e12e96` completed with **1004 pass / 18 fail / 9 opt-in skip**. Diagnosis and
focused corrections retain the original assertions' data-safety purposes:

- URL normalization accepted spaces in an HTTP hostname after URI percent-encoding.
  Reject decoded host whitespace/control characters; retain spaces in URL paths.
  All seven resource repository checks, including new invalid-host assertions,
  pass. The pre-fix invalid-input UI regression failed; it now passes.
- Archive/Trash title and actions overflowed at 390px/200% text and made deletion
  controls unreachable. Separate the title/close row from wrapping actions and
  wrap bulk controls. The existing long-title cancellation test passes, extended
  to exercise selection and cancel bulk deletion without removing records.
- Category/project visibility popup labels lacked a flex constraint. The updated
  category deletion journey reproduced an 80px overflow; both equivalent menu
  labels now wrap. That journey passes and retains unsaved input/records.
- Update stale Custom View/Resources/Details/Focus UI fixtures, scope sidebar
  scrolling to its ListView (the new search TextField has its own Scrollable),
  and preserve the saved-task modal close/discard/switch journey. Only the alarm
  test's expected database version changes from28 to29; alarm code is untouched.

Focused CI repair run: 15 pass/3 fail, then the three remaining repaired cases and
the extended Trash case pass (4/4). This accounts for all 18 initial failures;
the failed intermediate fixture assumptions remain in local logs. The original
84 checks are reused where their inputs are unaffected. No broad local suite.

Clean-runner packaging diagnosis also reproduced the enabled-Drive gate rejecting
the tracked disabled configuration. Windows CI now reads the existing approved
three-field public Desktop build configuration from encrypted repository secret
`GOOGLE_DRIVE_RELEASE_CONFIG`, validates enabled state, writes only to runner
temporary storage and removes it with an always cleanup step. Reusable manual/
Android release callers forward only that named secret. No key, user token or
configuration file is committed; the enabled-bundle gate is not bypassed. All
five workflow contract tests pass. Final exact-source Windows/Android/lightweight
CI must pass before publication; the replacement signed APK runtime now passes.

Initial source `0e12e96`: lightweight CI
[43732459572](https://github.com/2HIK4/Todorbit/actions/runs/43732459572) passes.
Android host/native gates pass in
[43732459495](https://github.com/2HIK4/Todorbit/actions/runs/43732459495), while the
mobile workflow fails at the stale direct-editor expectation. Its narrow fixture
repair passes in Android CI43734270117 onacf739c. On62593e3, lightweight CI43740736192
and both Android CI43740736200 jobs pass. Windows CI43740731448 reaches1021 pass/
1 fail/9 opt-in skip: my broad fixture replacement accidentally applied the Details
expectation to the separate draft-editor test. Restore its original disclosure
sequence; both composition tests now pass. No product input or package changes for
this correction. Required final exact-source CI remains pending. Draft release ID `446173243` contains the ten
approved assets; a draft is deliberately unavailable to production updaters.

## Data safety and remaining manual acceptance

Schema29 migration/backup/sync/restore and saved visibility/resource relationships
retain the verified focused evidence. Older incompatible clients reject schema29
batches; upgrade every paired device before resuming Sync. No downgrade migration
is provided. Standard Sync and optional Private Sync retain their existing keys,
ownership and recovery requirements.

[Candidate manual checklist](UIUX03_BETA_22_CANDIDATE.md#exact-manual-updater-acceptance)
remains applicable: real installed/portable/Android Beta21->22 updater handoff and
schema approval/cancel, Chrome link/file drops, Focus lifecycle/background/device
behavior, two-device real Drive exchange/restore and destructive-action cancellation.
Automated discovery or download does not establish these installations succeeded.
The three unrelated untracked documents, separate alarms, Stable and historical
release assets/tags must remain untouched.
