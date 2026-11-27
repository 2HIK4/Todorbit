# Todorbit v1.0.19-beta.30 — Candidate Release Notes (DRAFT — NOT PUBLISHED)

> **Status**: Candidate preparation on `feature/todorbit-beta27-refinement` (`1.0.19-beta.29+52` line, SQLite schema `29`). **No new GitHub release or website deployment has been published.**

---

## Summary of Candidate Improvements

### Windows Native Desktop Widgets (`TodorbitWidget.exe`)
- **Readable Translucent Light & Dark Rendering**: Replaces the 4-way white backdrop halo with a directional `(0, 1) + (1, 1)` contrast lift (`WidgetText.cs`), aligns `"taskRow"` underlay contrast composition with `"content"` / `palette.Row`, fixes synthetic surface mutation and opaque hover blends in `WidgetSurfaces.cs`, and keeps Light theme ink clearly legible over light, dark, and mixed wallpapers without blurry halos.
- **Smooth Continuous Pixel Scrolling (`WidgetScrollAxis`)**: Implements 16 ms eased pixel scrolling across both Tasks and Calendar widgets via a shared `WidgetScrollAxis` helper, resets Tasks scroll on `DateToday` and midnight rollover, honoring OS `MouseWheelScrollLines` and `SPI_GETCLIENTAREAANIMATION` reduced-motion settings, synchronizing thumb drag geometry and UIA accessibility scrolling, and guaranteeing zero repaints once idle (`idle_paints_250ms = 0` measured in `--scroll-benchmark`).
- **Agenda Scroll & Cleanup Hardening**: Fixes the Calendar agenda scroll viewport bottom bound so final rows never clip and ensures `WmDestroy` disposes timers and child popups cleanly.

### Embedded Settings & Input UX
- **Embedded Settings > Hotkeys (`HotkeysEditorView`)**: Moves the full Hotkeys editor (search, live shortcut capture, conflict warnings, named preset Save / Duplicate / Rename / Delete, `Reset all`, and Calendar shortcuts legend) inline into Settings while retaining standalone `HotkeysDialog` compatibility.
- **Keyboard & Focus Fidelity**: Preserves `Tab` traversal during shortcut capture, cancels cleanly on `Escape` restoring button focus, ignores bare modifier keypresses without spurious errors, and keeps Settings usable down to narrow `720×680 @ 1.5x` text scale.

### Data Safety, Search & Contributor Readiness (Reconciled from PR #3)
- **Rollback Backup Retention**: Preserves fresh automatic snapshots after device clock rollbacks in `BackupService`.
- **Updater Partial Restart**: Restarts damaged full-length partial downloads without sending invalid EOF `Range` requests (`ResumableUpdateDownload`).
- **Desktop Event Search & Mobile Touch Targets**: Includes non-cancelled fixed events in desktop sidebar search (`Workspace`) and ensures 48 dp interactive targets and adaptive app-bar spacing on mobile search (`MobileWorkspace`).
- **TDAT & Open-Source Tooling**: Fixes worktree/detached-HEAD guards (`Doctor.psm1`), adds automatic Windows plugin NTFS junction preparation (`Runtime.psm1`), expands architecture export/adaptor boundary tests, updates public documentation (`README.md`, `docs/FEATURES.md`, `docs/OPEN_SOURCE_EVIDENCE.md`, `website/`), and unblocks isolated live `Todorbit.exe` verification (`.\dev runtime windows -LiveApp`).

---

## Android 16 KiB Pre-Publication Verification Plan

- Beta 29's passing `16 KiB` run ([`45784257387`](https://github.com/2HIK4/Todorbit/actions/runs/45784257387)) verifies Beta 29 (`bd9d337`) only and is **not** evidence for Beta 30.
- Before publishing Beta 30 Android artifacts, dispatch `.github/workflows/android-release.yml` (`Prepare signed Android candidate (no publication)`) against the exact Beta 30 source tag/commit (with bumped Beta 30 version/code in `pubspec.yaml`), attach the signed universal/ARM64/x64 APKs to an **unpublished draft** GitHub release (or approved temporary release asset), and dispatch `.github/workflows/android-16k-runtime.yml` with the exact Beta 30 `app-x86_64-github-release.apk` `asset_id` + `sha256` and Beta 29's `previous_asset_id` / `previous_sha256` (`788858244` line -> Beta 29 x64 asset -> Beta 30) to confirm `16 KiB` in-place upgrade retention before flipping the release public.

---

## Remaining Manual Release Gates Before Publication

- Physical Explorer wallpaper (`Light`, `Dark`, mixed photo), extreme `0%`/`100%` transparency, `Win+D`, live display-DPI scaling, and multi-monitor visual sign-off on Windows 11 using the isolated launcher `.buildlog/windows-acceptance/launch-isolated.ps1`.
- Completion of `windows-ci.yml` / `android-ci.yml` plus the Beta 30 exact-APK `android-16k-runtime.yml` draft-asset upgrade run above.
- Explicit maintainer approval before tagging/publishing `v1.0.19-beta.30` (`Stable` remains untouched).
