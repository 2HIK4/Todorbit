# UIUX-03 Beta 22 publication verification

Owner authorization on 2026-11-15 explicitly permits push and automatic experimental
publication after all mandatory gates pass. Stable must remain unchanged.
Version: `1.0.19-beta.22+45`; intended tag: `v1.0.19-beta.22`.

Status: **DRAFT / CI GATED**. No public updater installation is claimed.
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

[Publication asset identities](UIUX03_BETA_22_PUBLICATION_ASSETS.json) account for
all ten files. Only `ANDROID-RELEASE-NOTES.md` and its entry in
`ANDROID-SHA256SUMS.txt` differ from the original candidate manifest: the notes
now match [the public release body](UIUX03_BETA_22_PUBLICATION_NOTES.md), replacing
the obsolete local-only status. All executable packages, updater manifest and
their checksum sidecars remain byte-identical to the approved candidate.

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

## CI and publication gates

Initial source `0e12e96`: lightweight CI
[43732459572](https://github.com/2HIK4/Todorbit/actions/runs/43732459572) passes.
Android host/native gates pass in
[43732459495](https://github.com/2HIK4/Todorbit/actions/runs/43732459495), while the
mobile workflow fails at the stale direct-editor expectation. Its narrow fixture
repair must pass on Android before publication. Required Windows CI and final
exact-source checks remain pending. Draft release ID `446173243` contains the ten
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
