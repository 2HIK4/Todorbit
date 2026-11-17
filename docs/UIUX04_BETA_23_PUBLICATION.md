# UIUX-04 / SYNC-01 Beta 23 publication verification

Owner authorization on 2026-11-17 explicitly permits push and automatic experimental
publication after all mandatory gates pass. Stable must remain unchanged.
Version: `1.0.19-beta.23+46`; intended tag: `v1.0.19-beta.23`.

Status: **PUBLISHED** at `2026-11-17T08:27:03Z`.
[Public experimental release](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.23),
tag/source `ec94f68be357eecfc0aa27c5bf7e0344b5a2bf2a`, Release ID `448327347`.
Prerelease: true, draft: false, make_latest: false. All 10 public download/hash contracts pass.

## Summary of Changes

- **SYNC-01 (Phantom sync conflict elimination & automatic reconciliation)**:
  - Unified status conflict counting with `_readSyncResolution(binding)` inside `db.readSyncSnapshot` to eliminate phantom conflict badges and divergence from `reviewSyncConflicts()`.
  - Added `SyncResolutionRepository.reconcileSyncConflicts` to atomically materialize complete mutation groups where descendant edits superseded earlier conflicts without discarding history or requiring manual user input.
  - Added `on StateError` protection in `sync_status_repository.dart` setting `reviewIssue = 'historyLimitExceeded'` to safely contain excessively large or malformed mutation histories.
  - Added `_showReviewUnavailable` dialog presentation in `sync_conflicts_dialog.dart` when `controller.problem == SyncProblem.reviewUnavailable`.
  - Added singular conflict grammar in `SyncStatusButton` tooltip and accessibility labels (`${conflicts == 1 ? 'conflict needs' : 'conflicts need'}`).
- **UIUX-04 (FocusWorkspace timer rebuild optimization)**:
  - Guarded the 250ms periodic timer in `_FocusWorkspaceState` so `setState(() {})` is only called when `_session.running` is true or `activeTimer` is running for this task (eliminates 240 unnecessary rebuilds/minute when paused or idle).
- **TaskDetailsView Riverpod lifecycle safety**:
  - Switched `TaskDetailsView.task` getter to `ref.read(appControllerProvider)` outside `build()`, while preserving reactive `ref.watch(appControllerProvider)` in `build()`.

## Data Safety and Compatibility

- Database schema remains at **29** (no migration required from Beta 22). Existing databases, tasks, resources, and settings are fully preserved.
- Retains zero data loss, Schema 29 forward migrations, CAS tokens, and offline-first safety.
- Android retains production package `io.github.hik4.todorbit`, versionCode 46.
- Windows packages remain unsigned under established policy. Stable releases unchanged (`prerelease: true`, `make_latest: false`).

## Verification & Build Gates

- **Unit and Widget Tests**: 91/91 passed across `test/cloud/sync_engine_test.dart`, `test/sync_apply_repository_test.dart`, `test/sync_conflicts_dialog_test.dart`, `test/uiux03_focus_widget_test.dart`, and `test/task_composition_widget_test.dart`.
- **Software Update Discovery Tests**: 18/18 passed across `test/software_update_service_test.dart` and `test/android_update_service_test.dart`.
- **Static Analysis**: `flutter analyze --no-pub lib/ test/` ran cleanly with 0 issues.
- **Git Diff**: Clean, zero whitespace issues (`git diff --check`).
- **Independent Code Review**: Completed by research subagent; verdict: **PASS** across all data safety, concurrency, UI, and performance checks.
- **Windows Release Build**: Compiled via `tools/build-windows-release.ps1` with Desktop Drive config verified (`Assert-GoogleDriveReleaseBundle`) and Microsoft-signed desktop x64 C++ runtime DLLs staged.
- **Windows Portable**: Built via `tools/build-portable.ps1`.
- **Windows Installer**: Built via `installer/build-installer.ps1` with Inno Setup 7.1.0 (`D:\vs code\Inno Setup 7\ISCC.exe`).
- **Android Release Build**: Universal APK compiled via `tools/build-android.ps1` with JDK 21 (`C:\Program Files\Android\openjdk\jdk-21.0.8`) and API 36; production signed; all 8 native libraries passed 16-KiB page and ZIP alignment checks (`tools/verify-android-artifact.py`).

## Publication Assets (10 Assets)

| File Name | Size (Bytes) | SHA-256 |
|---|---|---|
| `ANDROID-RELEASE-NOTES.md` | 1,995 | `84d555fae14d235d6592d4674dd7d2b4af8f975fb161c56062c72f4144f0b66b` |
| `ANDROID-SHA256SUMS.txt` | 318 | `7845d8985dbc98418961d7ae5c0e885ac9e3e9b8a695437b1e1ddebb6305a62e` |
| `Todorbit-1.0.19-beta.23-android-universal.apk` | 54,170,139 | `7d65326e14f26de92c951d8a612cbd929eed553efb506e6a0c2971237285b107` |
| `Todorbit-1.0.19-beta.23-android-universal.apk.sha256` | 113 | `b9395f4cd7b729f67f6282421ead35b6e6019c9cf6f925adb981b6e9ad976ff7` |
| `Todorbit-1.0.19-beta.23-android-update.json` | 407 | `faf0f84900fa9a5e594c93fdc260688b376e134246451563c0be30ab3f6d335b` |
| `Todorbit-1.0.19-beta.23-SHA256SUMS.txt` | 221 | `14fe92f59caa7a00bcfb0e06161f5b19ea01c6089176c0b808947efe21b236c2` |
| `Todorbit-1.0.19-beta.23-win-x64-portable.zip` | 63,460,712 | `c723cee166c190cb4ff83cd518e7dd18c189bd5af02597b68873856023db8e94` |
| `Todorbit-1.0.19-beta.23-win-x64-portable.zip.sha256` | 112 | `60ce5b930bc45c2234e444c25a19633431f1c300da17cff5835ab1117c2800b8` |
| `Todorbit-1.0.19-beta.23-win-x64-setup.exe` | 47,948,553 | `ce98c37ee1890e2cfa193bb9f65eab1cc2133b09ee661fae54cbf8ba66157810` |
| `Todorbit-1.0.19-beta.23-win-x64-setup.exe.sha256` | 109 | `e6ea257c23a4d0ad4b8ec90c6ab9ca3fa85464b971389f031b59151b89729412` |
