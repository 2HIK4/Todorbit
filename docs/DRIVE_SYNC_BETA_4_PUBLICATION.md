# Encrypted sync beta 4 publication - 2026-11-02

Published at **2026-11-02 01:03:03 Asia/Amman** (2026-11-01 22:03:03 UTC),
as a public GitHub pre-release with Latest disabled. All 11 assets are public.
Released source `67b265d2c546aa5ea5fad6b5214dad1a715869d9`, version
`1.0.19-beta.4+27`, Android code 27, schema 26. Application runtime is unchanged
from `0813913`; final source adds verified Windows C++ runtime deployment.

[Release](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.4) |
[Pairing and manual acceptance guide](GOOGLE_DRIVE_SYNC.md) |
[Implementation and complete invocation ledger](DRIVE_SYNC_RECOVERY_CHECKPOINT.md).

## Evidence

- Windows CI [41353292679](https://github.com/2HIK4/Todorbit/actions/runs/41353292679): **passed** on the exact candidate source, including 568 host tests/one existing opt-in skip, full analysis, C++ deployment negative gates, native writer, hidden-worker checks, packaged native self-test, installer and checksums.
- Prior identical runtime host CI: 568 tests pass, one existing opt-in skip;
  full analysis, native writer, hidden-worker, self-test and package gates pass.
- [Android CI](https://github.com/2HIK4/Todorbit/actions/runs/41347898852) passes on
  identical Android source; production-signing JVM tests: 5 pass, no skips.
- [16 KiB artifact runtime](https://github.com/2HIK4/Todorbit/actions/runs/41353852427)
  passes against the exact released x64 APK hash: real 16 KiB pages, app render,
  synthetic task create/reopen/completion and no observed crash/ANR.
- Final Windows packages pass a fresh Sandbox installation, schema-26/52-table
  cold create/reopen, populated in-place setup byte preservation, uninstall
  retention and reinstall. Portable swap/restart and deliberate-failure rollback
  retain the synthetic task, SQLite integrity and device/widget preferences.
- Production Android beta 1/code 23 upgrades in place to beta 4/code 27 on the
  retained disposable emulator. First-install timestamp and original synthetic
  task/project survive migration and cold restart. Sync setup opens from the icon.
- Android variants have the established production certificate, exact expected
  ABIs, minimum SDK 26 and passing native alignment. Private Play AAB identity,
  permission/provider separation and 16 KiB configuration pass; AAB is not public.
- All 28 Windows Release bundle files equal their portable ZIP contents; CRC,
  private-file exclusions and signed C++ runtime deployment receipt pass.
- Eleven draft asset sizes and GitHub SHA-256 digests match final local files.
  Anonymous release metadata and all small public assets were downloaded and hashed.
  Five binary Range probes returned verified first bytes and consistent sizes;
  complete asset digests match GitHub SHA-256 metadata. The production selectors
  choose Setup versus portable, ARM64/x64 according to ordered device ABIs,
  and exclude this beta from Stable. Public tag points exactly to `67b265d`.

## Scope and limits

Sync uses account-bound AES-256-GCM incremental operations, explicit same-workspace
recovery-code pairing, safe independent-field merge and durable reviewed conflict
resolutions. Restore reconciliation preserves pre-restore queues and original
ciphertext, creates a fresh device identity and retains competing newer edits.
Portable preferences and timer ownership preserve device-only controls and known
work checkpoints. Snapshot backup remains independent and requires restart to
apply a full restore; the staging/history error lifecycle is repaired.

Unlocked foreground apps debounce changes about 750 ms and poll about 25 seconds.
Android background jobs and the existing Windows companion provide bounded
opportunities, subject to OS scheduling, authorization, connectivity and app lock.
No guaranteed immediate background delivery or permanent worker is promised.

Real Drive validation is mocked only by owner instruction. No real pairing or
sync exchange was performed. Physical ARM64/OEM behavior, physical Windows shell
interaction, Windows 10, and actual Android system-installer approval remain
unobserved. Android upgrade used `adb install -r`. Live evidence is Release
emulator rendering and disposable packaged startup, plus widget tests. Existing
Google branding/public OAuth limitations remain. The original phone restore
exception was not captured; the repaired post-staging defect is reproducible,
not a confirmed diagnosis of that specific phone. No personal database was used.
Old tags/assets, Android signer/package, Windows AppId and profile/IPC identities
are unchanged. Windows app/setup remain unsigned as in earlier releases; the
bundled Microsoft runtime DLLs retain their valid Microsoft signatures.

## Public assets

| Asset | Exact bytes | SHA-256 |
| --- | ---: | --- |
| ANDROID-RELEASE-NOTES.md | 2,399 | `94ff0423bc990d0781bcda5702af275d5d2c8cb96340c6fdc9c22dbe27d39715` |
| ANDROID-SHA256SUMS.txt | 528 | `06ad9ff78a04fd287d943c554874931a02997f9f223ec9e2ab270a0cf74f466d` |
| Todorbit-1.0.19-beta.4-android-arm64.apk | 25,927,259 | `6de20ecc70825675d61851d7a9f6b1eacfeebfdfc916ebbae17c834cf86bf37b` |
| Todorbit-1.0.19-beta.4-android-universal.apk | 52,463,895 | `8b19482055ad5a31ae0debf7c1f50f7282bb66c468c382c63c2455a29b433ef2` |
| Todorbit-1.0.19-beta.4-android-update.json | 876 | `e15e1967bd428a7361d38f693126a211bd6ce52bd0c897b44ce0c87884c9ec63` |
| Todorbit-1.0.19-beta.4-android-x64.apk | 27,510,775 | `8d2a5fb6c9c257f31a140ad44077ee68e23d7a1634a4654264bc64c155417d43` |
| Todorbit-1.0.19-beta.4-SHA256SUMS.txt | 219 | `5defecf653b6a447f00db56c7c4322c4faa7fe6fea47fcf2fdd153e58eb5bf7b` |
| Todorbit-1.0.19-beta.4-win-x64-portable.zip | 63,004,761 | `5dba30cb3728b8f4e6dd7dfa02a92ad1b881af64c85176d6412779020adbe860` |
| Todorbit-1.0.19-beta.4-win-x64-portable.zip.sha256 | 111 | `085a16b541c6b38025a1647f1e2877c7f5cea804b294cb99b2f6f9948ac6624b` |
| Todorbit-1.0.19-beta.4-win-x64-setup.exe | 47,625,276 | `0329ed9c6f9c971ceb9cbbf4b62f156c7beb3753e4e03fc1b6464d9b856d87f6` |
| Todorbit-1.0.19-beta.4-win-x64-setup.exe.sha256 | 108 | `8af70aef7d600f258f14c7065a6fca25655b61b63079153f975df7e53e54e3a4` |
