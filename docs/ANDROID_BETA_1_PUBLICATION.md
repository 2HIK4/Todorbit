# Android beta 1 publication receipt - 2026-10-31

Published **1.0.19-beta.1 (23)** as a public GitHub **pre-release** at
2026-10-31 11:19:47 UTC (14:19:47 Asia/Amman). This is not a Stable or Play release.

- [Release](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.1)
- [Production APK](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.1/Todorbit-1.0.19-beta.1-android-universal.apk)
- [Checksums](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.1/ANDROID-SHA256SUMS.txt)
- [Android update metadata](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.1/Todorbit-1.0.19-beta.1-android-update.json)
- [Phone installation and Windows backup test procedure](ANDROID_PHONE_BETA_TESTING.md)

## Published identity and artifacts

Release ID `429762923`; tag `v1.0.19-beta.1` resolves to
`b48d7a749d4a6983707928f108165bb3399c30db`. It was published only after both
exact-source CI workflows and the mandatory acceptance checks passed. The APK/AAB
were built from `afe5241`; runtime source is identical through the publication
commit, which changes documentation and freezes test dates only. No release tag
was moved. Implementation commits are `57d7c4d` and `afe5241`.

APK: `Todorbit-1.0.19-beta.1-android-universal.apk`, **51,529,687 bytes**.

```text
eeb140b1ee574689c890bd52e2e078f547a3fc5533a5197c4d066eb8828c5d6b
```

Package `io.github.hik4.todorbit`, version `1.0.19-beta.1`, code 23, non-debuggable,
minimum API 26, target API 36, `arm64-v8a` and `x86_64`. Eight native libraries pass
ELF/applicable APK ZIP alignment. Publicly downloaded APK verifies with APK v2,
one RSA-4096 signer and the approved certificate:

- SHA-1: `D0:AE:60:28:E4:CD:0C:1C:83:67:11:42:F6:0F:14:2D:A8:1D:AD:96`.
- SHA-256: `00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.

The four public assets are the APK, update JSON, Markdown notes and checksum file.
All remote asset sizes/digests match local staged files and anonymous downloads;
all three checksum entries verify. Metadata digest is
`4650aabc402ca66129663f13eb473c0c4fae3a139ca94139326fbebd30381ebf`.
The Play AAB remains private validation material: 48,106,140 bytes, SHA-256
`3afb9ee90842d3bd5f4b382fe2dcc8756003477e4603f4b1743ef85b5e8cddd7`.
Its signature/identity, permission/provider separation and 16 KiB bundle config
pass. No signing key, passwords, configuration secrets, test fixture or user
profile was published. Final credential audit checked 728 tracked/archive entries.

## Root cause and correction

The original guard reused wall-clock `updated_at` values as revision tokens.
Two edits at one clock value could leave a stale snapshot valid. The CI log did
not record the two values; an injected frozen clock reproduces its exact failure
before the fix. A moving-clock stress pass was insufficient evidence.

Task revisions now strictly advance beyond the stored predecessor, even on equal
or backward clocks. Exact raw token text is retained for legacy native formatting.
Expected-token validation and completion/recurrence mutation run atomically;
Windows widget commands now carry their displayed revision too. Direct stale
repository calls reject. Duplicate widget deliveries never repeat a write or
recurrence advance, and never retry a stale edit with a refreshed token. Actual
completion/history times remain separate from the logical revision.
Database schema remains **22** and encrypted backup format remains **1**;
no migration or data reset was introduced.
See [implementation and deterministic tests](TASK_REVISION_SAFETY.md).

## Verification

| Gate | Observed result |
| --- | --- |
| [Windows CI 41195345642](https://github.com/2HIK4/Todorbit/actions/runs/41195345642) | Passed on publication commit: full analysis, 434 host tests, Windows Release, packaged native self-test, installer/config gates |
| [Android CI 41195345616](https://github.com/2HIK4/Todorbit/actions/runs/41195345616) | Passed on publication commit: 69 host tests, artifact checks and two real-emulator integration tests |
| Deterministic regressions | Frozen/equal/backward clocks, ABA/rapid edits, an intervening edit across SQLite connections, competing writes, duplicate widgets, recurring completion, delayed delivery, reopen, deletion and legacy token formatting |
| Local checks | Full analysis; formatting of 244 Dart files; 434 host tests; 18 focused tests; seven release-validator and eight developer-helper tests; native Release/self-test |
| Production package update | Real in-app 22-to-23 native verification/permission/system installation passed before publication and again from the public GitHub release |
| Preservation | All 45 SQLite tables identical after each package update; stable IDs, 41-byte managed attachment, existing backup bytes, preferences and widget IDs 2/3/config preserved |
| Actual delayed widget action | Edited a synthetic task through the UI, then delivered an older issued capability; updated title/open state retained and all 45 tables unchanged |
| 16 KiB runtime | Identical released APK on API-35 x86-64, `PAGE_SIZE=16384`: render, SQLite completion retained through cold reopen, widget completion/reopen; no app crash/ANR recorded |
| Public distribution | Anonymous API/download, final tag/source, all asset checksums, package and production certificate passed |
| Android updater | Normal production baseline code 22, verified by its APK hash: Stable excludes beta; Pre-release finds 23 and renders real notes; official download/native verification/system update installs the identical public APK |
| Windows preservation | Existing release identities and all asset IDs, sizes, digests and update timestamps match the pre-session snapshot; no Windows release/assets changed |

The host suite's one deliberate skip is the opt-in real companion launch test,
which requires a specifically isolated profile. Independent local and packaged
native self-tests passed. Physical Windows GUI/input/DPI behavior is not claimed
by these automated checks; Windows Sandbox was not reopened.

## Google Drive and remaining beta limits

Drive is enabled in the released APK; its Connect control is available. Real
production authorization, encrypted upload/read-back, wrong-passphrase rejection,
preview/restore and account-wide revocation/fresh consent/reauthorization passed
earlier with the owner-authorized disposable account. OAuth, backup/codec and
schema implementations are unchanged through the published source; those results
are retained without repeating destructive tests. Production package/certificate
identity remains the registered identity. No general Google branding approval,
public policy approval or eligibility for every account is claimed.

**Windows/Android cloud discovery and restoration remain unverified.** The owner
explicitly deferred that test for this first beta and will test an existing Windows
backup on Android after publication. Start with disposable data and externally
back up existing data before replacement. This is snapshot recovery, not two-way
synchronization. Linked Windows file contents require separate copying/relinking.

Other limits: physical ARM64 16 KiB devices, OEM launcher resizing/reboot and
TalkBack breadth remain unobserved/limited; offline Google authorization may show
a generic canceled/denied message. Existing Windows Pre-release checks may report
that the newer Android tag has no verified Windows x64 package; Windows never
selects the APK. See [published release notes](ANDROID_RELEASE_NOTES.md).

All test emulators and the loopback fixture server were stopped with test data
retained. Development installation, personal profiles and existing cloud backups
were preserved. Private evidence remains ignored under
`.buildlog/android-production-beta/revision-fix/`; profiles and capabilities are
not release assets. This receipt is documentation after publication and does not
change the immutable publication tag or packaged source.
