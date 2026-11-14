# Beta 19 publication receipt — 2026-11-14

Published [v1.0.19-beta.19](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.19)
at 2026-11-13 23:42:50 UTC (2026-11-14 02:42:50 UTC+03), release ID 444843364.
Experimental pre-release, `latest=false`, version `1.0.19-beta.19+42`, Android
code 42, SQLite schema 28. Tag and all runtime builds use source
`375729e064ba9a2c7af298fa4c40e60d51d14821` on
`codex/independent-beta-review`. Subsequent receipt edits are documentation only.

Review baseline: Beta 18 `a1ac5a5`; actual changes reviewed from Beta 14 `3e0efe7`
through Beta 18, with emphasis on Beta 16–18. Confirmed findings, root causes,
regression reproductions and all local invocations are in the
[independent review](INDEPENDENT_REVIEW_2026_11_14.md). Changes are calendar/history,
date refresh, error feedback, a lease-test fixture and release evidence/helpers.
No schema, Sync protocol, key, account or profile-location migration occurred.

## Public artifacts

All ten assets were verified in a private draft before publication. Anonymous
release metadata and every direct download returned HTTP 200 with matching
sizes and GitHub SHA-256 digests. Small sidecars/manifests/notes were downloaded
and hashed; large binaries were not redundantly downloaded after upload.
Machine-readable evidence: `.buildlog/independent-review/final-artifacts.json`
and `public-verification.json`. Local logs are ignored work products, not shipped
application data.

The actual production update services also passed live-network discovery from
Beta 18: Windows setup and portable, Android arm64-v8a and x86_64, expected
code/digest, and Stable excluding Beta 19. The temporary harness first had a
compile error (null HttpOverrides); corrected without application changes, then
passed one combined test. See runs 044–045 in the review receipt.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| [Windows setup](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.19/Todorbit-1.0.19-beta.19-win-x64-setup.exe) | 47,734,329 | `e6e901d1957c4ce4f3ef289e096fede162052f97561d04d18f1c3cbc016aa336` |
| [Windows portable](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.19/Todorbit-1.0.19-beta.19-win-x64-portable.zip) | 65,045,347 | `09b5f63edb9962fe6c5223f371fa84cd67d0b73920ad221679d730b0f876da83` |
| [Android universal APK](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.19/Todorbit-1.0.19-beta.19-android-universal.apk) | 53,776,379 | `dc014710dec8ca27bf9f8c975754732351de179dec15d9856748ff26e2467620` |

Other assets: setup/portable/APK `.sha256` files, versioned Windows
`SHA256SUMS.txt`, `ANDROID-SHA256SUMS.txt`, `ANDROID-RELEASE-NOTES.md` and
`android-update.json`. The APK is universal arm64-v8a/x86_64, minSdk 26,
package `io.github.hik4.todorbit`; eight ELF libraries passed 16 KiB alignment.
Both Windows executables retain product `1.0.19-beta.19+42`, numeric PE
`1.0.19.42`; Inno 7.1.0 keeps the beta display identity. CRT signatures and
portable archive integrity/configuration/private-file exclusion passed.

Signing continuity was checked against the actual published Beta 18 APK, SHA
`fc7702961ff74935c8cde741d79dda283e0d63e4e8a5d7f63a3667bb9d06e72a`.
Both production signer SHA-256 fingerprints are
`00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.
Signing keys/private configuration were neither changed nor committed.

## Verification and acceptance

- [Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/43516558494),
  exact source: analysis clean; 893 Flutter tests passed, 9 opt-in skips;
  developer-route/configuration checks, Release build, CRT, portable packaging,
  native writer/barriers/self-test, installer and checksums passed.
- [Android CI](https://github.com/2HIK4/Todorbit/actions/runs/43516561285),
  exact source: host analysis/tests/APK gates and on-device update integration
  passed. The earlier DDS startup failure executed zero tests; retained in the
  review, superseded by this fresh final-source runner.
- [Exact signed APK runtime](https://github.com/2HIK4/Todorbit/actions/runs/43527857993):
  16,384-byte pages, stable no-app baseline, Flutter rendered, task created,
  retained after restart and completed, no crash/ANR observed. Actual production
  Beta 18 code 41 upgraded in place to code 42 and retained its task.
- Local final calendar suite: 50 passes; unchanged controller/mobile/draft/CAS
  boundaries reused from the 58-pass focused run. Six Sandbox-preparation tests
  passed. Separate isolated startup/restore/resource journeys passed 15 cases,
  including malformed preferences, corrupt/future schemas, legacy upgrade and
  actual restore/restart. Full CI's opt-in skips are not substituted for these.
- Native Release self-test passed under task-owned APPDATA/LOCALAPPDATA.
  Final native executable SHA-256
  `a4f4c816ec581ffa485190721cc7a7bfa64590c2d74cec254fd7f632c41fa04a`
  matches the tested binary, so that pass was reused.
- Fresh Windows Sandbox acceptance passed: package digests; fresh per-user
  installer registration; separate installed/portable path-with-spaces profiles,
  schema 28/54 tables/reopen/integrity; native self-test; populated database
  byte preservation through same-candidate setup; uninstall preserving data and
  successful reinstall. This is not a Beta 18-to-19 Windows installer test.
  Receipt: `.buildlog/sandbox-acceptance-cba96d59d6454ed08f14578423eb8a73/results/acceptance.json`.
- Portable update run 039 timed out at the harness's 15-second main-window
  closure. Publication was held during diagnosis. Run 040 retained the same
  positive assertions and added process/window/CloseMainWindow logging; swap,
  automatic restart and database/widget-settings preservation passed. Original
  harness run 041 `-ExpectFailure` passed rollback/recovery restart and
  preservation. The first timeout's cause remains unverified; no speculative
  application fix or test-assertion relaxation was made.
- Final Windows Release GUI ran only in an isolated profile. Observed dark
  Today view, empty task editor and Day/Week/Month pointer controls. Its database
  passed integrity and foreign-key checks. Text/key injection through the helper
  was inconclusive; no physical-keyboard pass or keyboard defect is claimed.

All costly local builds ran sequentially. Personal profiles were not used.
Superseded artifacts were retained locally and never uploaded. Old published
binaries/tags, Stable, data identities, encryption and recovery rules remain
unchanged. Windows Drive remains intentionally disabled; Android authentication
retains its existing configuration and acceptance limits. Windows packages remain
unsigned.

## Remaining manual verification

1. Upgrade a backed-up Beta 18 Windows installation using the published setup;
   verify tasks/events/preferences/widgets and restart.
2. Move overnight/multi-day continuations both directions and across days;
   resize at midnight; Undo/Redo after changing notes/status/session outcome.
3. Check Ctrl+Z/Ctrl+Shift+Z/Ctrl+Y in calendar, text fields and modal dialogs;
   repeated notices, four-second dismissal and persistent actionable errors.
4. Check Android drafts/Back/restart, midnight/resume, physical ARM64/OEM alarms,
   Windows 10/DPI, Narrator/TalkBack and real Google account recovery journeys.

These limits remain explicit in public release notes. Automated acceptance does
not establish comprehensive physical-platform or real-account behavior.
