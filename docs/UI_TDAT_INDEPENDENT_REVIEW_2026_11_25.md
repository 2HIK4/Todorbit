# Independent Todorbit UI Review & First Real-World TDAT Evaluation (2026-11-25)

- **Reviewed Baseline**: `feature/todorbit-beta27-refinement` at `8fc25a57b305ca35a2f224799864b50b7640215c` (Beta 28 + TDAT permanent adoption).
- **Review Worktree / Branch**: `D:\AI_Projects\life_manager_ui_review` on `review/ui-tdat-eval-2026-11-25` (isolated from existing Codex/main worktrees; zero production source modified).
- **Scope**: Review-only evaluation of Todorbit's post-redesign UI quality (`UI Redesign 2.0` -> `Beta 27` refinement/polish -> `Beta 28` Graphite Neutral Silver default) and first real-world evaluation of TDAT (`tools/dev/`).

---

## 1. Executive Summary & Overall UI Assessment

Todorbit's redesigned UI represents a clear structural and ergonomic step forward from the pre-redesign layout:

- **Desktop task workspace**: Left-aligned `1120 dp` bounded lists (`AppLayout.taskListMaxWidth`), shared `AppPageHeading`, `ItemFilters`, `AppTaskRow`, and `TodayEventRow` establish a cohesive Fluent-inspired hierarchy in both Light (`#006A66` teal) and Dark (`#C8CDD2` Graphite Neutral Silver). Grouping `Upcoming` by planned day and suppressing redundant row `Planned` dates on Windows markedly improved scan density.
- **Calendar & editor foundation**: The unified interactive `CalendarView` canvas, `TodorbitThemeTokens`, `SettingsSection`, `DialogActionBar`, `AppModalShell`, `PointerCancellationScope`, and `AppMotion` provide solid architectural building blocks for accessibility, draft safety, and reduced motion.
- **Mobile parity**: `MobileCalendar` (320 dp / 150% text scale) fits the 6-row Month grid and keeps Day agenda actions reachable above the bottom navigation bar.

**Overall Assessment**: **Good core design language and interaction foundation, with notable cross-screen consistency debt and several concrete mobile/responsive defects.** The redesign pilot introduced high-quality shared primitives (`AppModalShell`, `AppPageHeading`, `TodorbitThemeTokens`, `AppTaskRow`), but adoption across sibling screens (`TaskDetailsView`, `ThemeDialog`, `HabitsView`, `GoalsView`, `ReportsView`, `_subtaskRow`, `mobileSubtaskRow`) remains incomplete, leaving hardcoded legacy styles, platform parity gaps on Android `Upcoming`, and narrow-viewport clipping/overflow risks.

---

## 2. Prioritized UI Findings (Objective Defects vs. Subjective Recommendations)

### A. Objective Defects & Regression Risks

| ID | Severity | Platform / Scope | Evidence & Location | Finding & User Impact |
| --- | --- | --- | --- | --- |
| **UI-DEF-01** | **P1 (Functional / Visual Defect)** | Desktop (`TaskDetailsView`) | Source: `lib/features/workspace/task_details_view.dart:333-340`, `:379-403` | **Hardcoded legacy purple accent (`#8B5CF6`) and raw theme tokens.** `Start Focus Session` hardcodes `backgroundColor: const Color(0xFF8B5CF6)` and `Colors.white`, ignoring `colorScheme.primary`, custom user palettes, and the Beta 28 Graphite Neutral Silver default. Priority badge also uses `scheme.error`/`scheme.primary` + `"Priority ${task.priority}"` instead of `TodorbitThemeTokens.colorForPriority` and human labels. |
| **UI-DEF-02** | **P1 (Behavioral / Parity Defect)** | Android (`MobileWorkspace`, `AppTaskRow._buildMobile`) | Source: `lib/features/shared/app_task_row.dart:344-347`, `:384-391`; `lib/features/mobile/mobile_workspace.dart:764-774`, `:1017-1032`. Render: `.buildlog/refinement/android-runtime/` (`android-runtime-upcoming-320-150.png`) | **Android `Upcoming` parity regression & `showPlannedDate` ignored.** Desktop `Upcoming` groups rows under planned-day headings and sets `showPlannedDate: false` (exposing the planned date in `semanticsLabel`), resolving `UI-01`. On Android, `MobileWorkspace.taskList` omits `groupByPlannedDay`, `mobileTaskRow` omits `showPlannedDate`, and `AppTaskRow._buildMobile` unconditionally prints `'Planned $formatted'` without `semanticsLabel` support. Completed mobile titles also omit `onSurfaceVariant` dimming. |
| **UI-DEF-03** | **P1 (Responsive Overflow Risk)** | Desktop & Android (`ThemeDialog`) | Source: `lib/features/settings/theme_dialog.dart:213-217`, `:159-190` | **Hardcoded `560x560` `AlertDialog` body without `AppModalShell`.** `ThemeDialog` wraps `AlertDialog.content` in `SizedBox(width: 560, height: 560)` without viewport or `viewInsets.bottom` clamping. On `800x600` desktop windows or Android phones (reachable via `MobileSettings` at `mobile_settings.dart:229`), a fixed 560px content height plus title and actions risks vertical overflow/clipping. Additionally, desktop JSON theme import/export prompts for a typed filesystem path instead of a file picker. |
| **UI-DEF-04** | **P1 (Touch Target Violation)** | Android (`MobileWorkspace.mobileSubtaskRow`) | Source: `lib/features/mobile/mobile_workspace.dart:1076-1082`, `:1068-1073` | **Subtask overflow button violates 48 dp minimum target on Android.** `mobileSubtaskRow` uses `IconButton(iconSize: 20, visualDensity: VisualDensity.compact, ...)` which shrinks the touch target below `AppLayout.minTapTarget` (48 dp) mandated by `docs/UI_DESIGN_SYSTEM.md`, and hardcodes `fontSize: 14` instead of `theme.textTheme.bodyMedium` (`15 sp` on Android). |
| **UI-DEF-05** | **P2 (Visual / Token Regression)** | Desktop (`Workspace._subtaskRow`) | Source: `lib/features/workspace/workspace.dart:2772-2777`, `:2714-2765` | **Desktop subtask priority flags broken under Graphite Neutral Silver.** `_subtaskRow` colors priority 3 with `scheme.error` (pinkish `#FF9BB0` in dark) and priority 2 with `scheme.primary` (grey `#C8CDD2` in Graphite Neutral Silver) with `Icons.flag_outlined`, rather than using `TodorbitThemeTokens.colorForPriority` and filled `Icons.flag` like `AppTaskRow`. |
| **UI-DEF-06** | **P2 (Visual Clipping)** | Desktop Narrow (`800 dp / 150%`) | Render: `.buildlog/polish/after-flutter/upcoming-narrow.png`. Source: `lib/features/workspace/workspace.dart:1846-1915`; `lib/features/shared/scroll_edge_fade.dart:189` | **Sidebar nav bottom item clips mid-word above `Windows widget`.** In `upcoming-narrow.png`, `Waiting / On hold` is cut off mid-text directly above `Windows widget` because `ScrollEdgeFade` uses a 16 px gradient with no `Divider(height: 1)` separating the scrollable nav list from the pinned bottom footer (`Windows widget` / `Settings`). |
| **UI-DEF-07** | **P2 (Behavioral / Empty State Bug)** | Android (`MobileWorkspace.taskList`) | Source: `lib/features/mobile/mobile_workspace.dart:986` vs `:967` | **Empty search prompt shown before typing.** In `showTaskSection`, `TaskListEmptyState(filtered: c.activeFilter.isActive || searching)` omits `&& search.text.trim().isNotEmpty`, displaying *"No matching tasks — Change or clear the current filters or search"* in scoped views as soon as the user taps the search icon with an empty query. |
| **UI-DEF-08** | **P2 (Responsive Overflow Risk)** | Desktop & Android (`TaskDetailsView._addManualTime`) | Source: `lib/features/workspace/task_details_view.dart:96-174` | **Unscrollable `AlertDialog` with text field.** `_addManualTime` uses a bare `Column` inside `AlertDialog` (no `SingleChildScrollView` or `AppModalShell`), risking `RenderFlex` overflow when an IME opens on `Notes (optional)` or at 150% text scale. |
| **UI-DEF-09** | **P2 (Layout Alignment & Token Drift)** | Desktop (`Workspace`, `HabitsView`, `GoalsView`, `ReportsView`) | Source: `lib/features/workspace/workspace.dart:2265`, `:2304`, `:2313`; `lib/features/habits/habits_view.dart:159`, `:102`; `lib/features/goals/goals_view.dart:211`, `:156`; `lib/features/reports/reports_view.dart:121`, `:135` | **Cross-screen horizontal & heading inconsistency + missing error accent on destructive action.** (1) In `workspace.dart`, the hidden-tasks banner, events window label, and Today action chips use `left: 28` instead of `AppLayout.pageInsetH` (`20`), breaking the leading inset rule. (2) `HabitsView` and `GoalsView` center content in `800 dp` (`workspaceMaxWidth`), while task views start-align in `1120 dp` (`taskListMaxWidth`). (3) `ReportsView` uses custom `EdgeInsets.fromLTRB(28, 26, 28, 30)` and `headlineMedium` (`28 sp`) instead of `AppPageHeading` / `headlineLarge` (`32 sp`). (4) `HabitsView._clear` (`Clear log`) uses default `FilledButton` instead of `scheme.error` destructive styling. |
| **UI-DEF-10** | **P2 (Information Truncation)** | Desktop (`CalendarWeekView` / `TimelineDayColumn`) | Source: `lib/features/calendar/timeline_grid.dart:412`, `:888-943`. Render: `candidate-calendar-week-dark.png` | **Narrow overlapping Week cards clip time ranges (`"09:00 – 1..."`).** Cards with `itemWidth >= 60` and `height >= 44` (observed ~65–95 px wide in 3–4 lane overlaps) take the non-compact layout, spending horizontal width on the 12 px type icon + warning icon and rendering the full `start – end` string which truncates mid-time. |

### B. Subjective Design & Usability Recommendations

| ID | Area | Observation & Evidence | Recommendation |
| --- | --- | --- | --- |
| **UI-REC-01** | **Android Compact Bottom Navigation** | In `android-320-150-home.png` and `workspace-mobile-320dp-large-text.png`, `NavigationBar` switches to `alwaysHide` labels (`mobile_workspace.dart:714-716`), leaving 3 of 5 destinations as nearly identical calendar-grid icons (`Today`, `Calendar`, `Upcoming`). | Keep short 1-line labels or use more distinct glyphs (`wb_sunny_outlined` / `star_outline` for Today, `date_range` / `view_agenda_outlined` for Upcoming, `calendar_month` for Calendar) so destinations remain recognizable without labels. |
| **UI-REC-02** | **Desktop Top Utility Bar Chrome** | `workspace.dart:1015-1067` places only `Library` and `SyncStatusButton` in a full-width top row, creating a ~40 px empty strip across 1920 px monitors (`desktop-today-dark.png`, `graphite-neutral-silver-upcoming.png`). | Consider folding `Library` + `SyncStatusButton` into the page header row or sidebar header/footer to reclaim vertical space above the fold and keep sync status closer to the user's focal area. |
| **UI-REC-03** | **Today View Calendar Crowd-Out** | In `desktop-today-dark.png` and `android-320-150-home.png`, having 10 events under `On your calendar` pushes `Planned tasks` to the very bottom of a 1080p screen (and completely off-screen at 320 dp). | Make `On your calendar` collapsible or capped with a `"Show N more events"` toggle when >4 events are present, preserving visibility of `Planned tasks` in the first viewport. |
| **UI-REC-04** | **Recurring Group Header Density** | In `candidate-all-tasks-dark.png` and `task_list_group.dart:132-145`, `ExpansionTile` recurring headers (~76–80 px) look noticeably taller and offset from ordinary `AppTaskRow` rows (~53 px). | Align the leading `Icons.repeat` box width with `Checkbox` and tighten `tilePadding` or route through a compact shared row shell. |
| **UI-REC-05** | **Numeric Priority Copy** | `AppTaskRow` (`:182`, `:323`) and `TaskDetailsView` (`:396`) display `"Priority 1/2/3"` instead of `"Low / Medium / High"` (unlike `TaskEditor` which uses `Low`, `Medium`, `High`). | Standardize user-facing priority strings to `Low` / `Medium` / `High` via a shared helper. |

---

## 3. Component Reuse, Architecture & Performance Findings

### Component Reuse Audit (`lib/features/shared/`)
Grep across `lib/features/` at `8fc25a5` confirms partial adoption of the shared UI foundation:
- `AppModalShell` / `showAppModal`: **6 consumer files** (`goal_dialogs.dart`, `habit_editor.dart`, `trash_dialog.dart`, `calendar_view.dart`, `task_details_view.dart`, `workspace.dart`) vs **80 `AlertDialog(` calls** across `lib/features/` (many legacy dialogs lack `AppModalShell` viewport/IME clamping, notably `ThemeDialog` and `TaskDetailsView._addManualTime`).
- `AppPageHeading`: **1 consumer** (`workspace.dart` only); `HabitsView`, `GoalsView`, and `ReportsView` still build custom headers.
- `TodorbitThemeTokens`: **1 feature consumer** (`app_task_row.dart`); `_subtaskRow` and `TaskDetailsView` still compute ad-hoc priority colors.
- `SettingsSection`: **10 feature consumers** (broadly adopted).
- `DialogActionBar`: **10 feature consumers** (well adopted in newer dialogs).

### Separation of UI & Business Logic
- `tools/test_architecture_boundaries.py`: **39/39 passed** (domain remains free of UI imports).
- However, **7 UI files** in `lib/features/` directly import `../../data/app_database.dart` (or hold `LifeRepository` / `BackupService` / `CloudBackupService`): `workspace.dart`, `task_resources_section.dart`, `unified_resources_section.dart`, `backup_dialog.dart`, `backups_cloud_page.dart`, `widget_settings_page.dart`, `native_widget_service.dart`.
- Large monolithic presentation files continue to grow (`workspace.dart`: **2,845 lines** vs 1,868 lines in Oct 2026; `task_editor.dart`: **2,309 lines**; `calendar_view.dart`: **2,173 lines**; `mobile_workspace.dart`: **1,647 lines**; `event_editor.dart`: **1,567 lines**), increasing cognitive load and merge conflict surface.

### Performance Findings
- **TDAT Host Benchmark (`dev benchmark all` on `8fc25a5`)**: Executed `test/performance_benchmark_test.dart` in **26,111 ms** (`36,753 ms` total including toolkit checks; receipt `.buildlog/benchmarks/20261125_211526_all.json`):
  - Cold launch to first frame (widget test harness): `2030.03 ms`; to interactive: `2084.48 ms`.
  - Warm return to foreground: `11.8 ms`; `AppController.initialize()`: `187.34 ms`.
  - Navigation: Today -> All Tasks `608.02 ms`, All Tasks -> Calendar `785.04 ms`, Calendar -> Today `372.53 ms`, Next Month `677.9 ms`, Prev Month `187.84 ms`.
  - Active Timer 3s lifecycle: `326.41 ms` (local ticking intact).
  - Memory RSS: Initial `257.8 MB` -> Idle `409.07 MB` -> After extended navigation `429.98 MB`.
- **Important Caveat**: `dev benchmark` measures Dart/Flutter widget-test harness execution, NOT GPU/raster frame budgets of a compiled `Todorbit.exe` Profile binary. Per `docs/BETA_27_REFINEMENT.md` and `docs/BETA_27_POLISH_IMPLEMENTATION.md`, dense Calendar scrolling in Windows Profile mode still exhibits raster frame-budget misses (`120 Hz` budget) that require native Profile tracing to diagnose and resolve.

---

## 4. TDAT Usability & Efficiency Evaluation (Real-World Usage)

### Empirical Measurements Recorded During This Review

| Operation / Command | Observed Wall-Clock Time | Outcome / Notes |
| --- | --- | --- |
| `dev doctor` | `4,627 ms` | PASS (WARN: Developer Mode disabled, Free RAM 1,392 MB) |
| `dev status` | `1,737 ms` | PASS (worktree, branch, free RAM/disk, session ID) |
| `dev repomap` | `990 ms` | PASS (layer map, 234 `lib/` files, 227 suites) |
| `dev help` | `785 ms` | PASS |
| `dev context <feature>` (15 UI features) | `783–959 ms` each (avg `875 ms`) | Instant deterministic packs without blind repo grep |
| `dev registry --validate` | `1,067 ms` | PASS (`227` suites) |
| `dev impact` (clean `8fc25a5` worktree) | `5,065 ms` | Computed 100-file diff against `feature/todorbit-ui-redesign-2` merge-base |
| `flutter.bat pub get --enforce-lockfile` *(manual)* | `8,791 ms` | Required manually before `screenshot` / `verify` in fresh worktree |
| `dev screenshot all` (first run, pre-`pub get`) | `3,260 ms` | **FAIL** (`--no-pub` failed without `.dart_tool/package_config.json`) |
| `dev screenshot all` (post-`pub get`) | `69,641 ms` (`68,510 ms` Flutter) | PASS (11 PNGs), **but rendered Ahem tofu blocks** |
| `dev benchmark all` | `36,753 ms` (`26,111 ms` Flutter) | PASS (20+ app metrics + 4 toolkit metrics) |
| `dev fixture typical` | `1,554 ms` | PASS (`50` tasks, `25` events, SQLite schema 29) |
| `dev verify feature settings-ui` *(documented syntax)* | `469 ms` | **FAIL** (`PositionalParameterNotFound` for `settings-ui`) |
| `dev verify feature -Feature settings-ui` | `83,715 ms` | PASS (format `1.53s` + analyze `27.57s` + 66 tests `53s`) |
| `dev self-test` | `114,446 ms` | PASS (`16/16` checks) |
| `dev cleanup --dry-run` | `821 ms` | PASS (`0` items) |
| `dev runtime windows` | `40,179 ms` | PASS (`FlutterTestHarness_SQLitePersistence`) |
| `dev runtime android` | `1,230 ms` | Honest `BLOCKED` (no emulator/candidate APK) |
| `dev verify changed -BaselineRef b600ea7` (Run 1) | `257,112 ms` | PASS (`9` Py + `8` Dart suites: `5` cached, `3` cache-skipped `IneligibleForReuse`) |
| `dev verify changed -BaselineRef b600ea7` (Run 2) | `188,272 ms` | PASS (`5` Dart `[REUSED]`, `3` Dart fresh `25.63s`, `9` Py fresh, `analyze` `16.48s`) |
| `dev package` | `1,052 ms` | Printed `PASS` despite `Binaries Audited: 0` |
| `python tools/dev/check-docs.py` | `170 ms` | PASS (`0` errors) |
| `python -m unittest discover -s tools -p test_architecture_boundaries.py` | `784 ms` | PASS (`39/39`) |

*Note on token consumption*: Exact host API token counters are not exposed to the agent runtime; no synthetic token-savings percentage is claimed without a controlled non-TDAT baseline. Empirically, `dev repomap` (`0.99s`) and `dev context <feature>` (`~0.88s` each) eliminated multi-turn `find_by_name`/directory-tree discovery for the 23 feature boundaries.

### Strengths Observed
1. **Fast orientation**: `dev repomap` and `dev context` return structured layer/boundary/invariant summaries in under 1 second.
2. **Conservative impact & honest runtime boundaries**: `dev impact` traces reverse Dart imports reliably; `dev runtime windows` clearly distinguishes test-harness persistence from `-LiveApp`, and `dev runtime android` fails closed as `BLOCKED` rather than faking device verification.
3. **Working Dart evidence cache**: `dev verify changed` Run 2 accurately reused `5/8` Dart suites (`[REUSED]`), reducing the Flutter test execution step from `85.08s` to `25.63s` (`59.45s` / `69.9%` reduction in the `flutter test` phase), while enforcing `IneligibleForReuse` on runtime/lab tests.

### Defects, Misleading Outputs & Remaining Friction Found in TDAT
1. **Broken documented CLI syntax (`dev verify feature <name>`)**: `dev help`, `docs/DEVELOPER_AUTOMATION_TOOLKIT.md`, and `dev context <feature>` all tell agents to run `.\dev verify feature <name>`. Because `tools/dev/dev.ps1` only declares positional parameters at `Position=0` and `Position=1` (`$Command`, `$Subcommand`), passing a third positional argument throws `PositionalParameterNotFound`; callers must manually discover `-Feature <name>`.
2. **`dev screenshot` renders unreadable Ahem font blocks**: `test/lab_render_test.dart` omits `await loadReviewFonts()` (present in `test/refinement_visual_test.dart:32`), so all 11 screenshots captured by `dev screenshot all` render text as solid rectangles (`████`) and Material icons as empty boxes (`□`), defeating visual inspection of typography, truncation, and icons.
3. **Missing `.dart_tool/package_config.json` check in `dev doctor`**: In a fresh `git worktree`, `dev doctor` reports `Flutter: OK` even though `.dart_tool/package_config.json` does not exist. Because `Lab.psm1`, `Benchmarks.psm1`, and `verify.ps1` pass `--no-pub`, the first `screenshot` or `verify` command crashes until the user manually runs `flutter.bat pub get --enforce-lockfile`.
4. **Drift between `features.json` and `feature_contexts.json` (11 of 23 features)**: `dev context` prints a hardcoded `tests` array from `feature_contexts.json` instead of reading `features.json`. Automated comparison found stale/missing test lists in `calendar`, `calendar-ui`, `sync`, `task-lists`, `database`, `task-timers`, `windows-updates`, `android-updates`, `mobile`, `drive`, and `settings-ui`. Additionally, `feature_contexts.json` cites non-existent `AppSpacing.rowGap` and outdated `44x44` mobile target guidance (actual token is `AppLayout.minTapTarget = 48`).
5. **`verify changed` cache overhead remains high (`188.3s` on Run 2)**: Even with 5/8 Dart suites `[REUSED]`, Run 2 took `188.3s` because: (a) Python checks (`~100s+`) are never cached; (b) `dart format` and `flutter analyze` still run over all changed Dart files (`17.8s`) regardless of `[REUSED]` status; and (c) `Saved 14.0s` printed per reused suite is an averaged batch estimate (`85.08s / 6`? Actually `dev.ps1:340` divides total Dart duration equally) rather than true per-suite timing. Also, `startup_recovery_journeys_test.dart` runs inside `verify changed` without isolated profile env vars, hitting skips that `dev runtime windows` avoids.
6. **`dev package` reports `PASS` with 0 binaries audited**: On a fresh worktree with no compiled Windows EXE or Android APK, `dev package` prints `Overall Status: PASS` alongside `Binaries Audited: 0`, which can mislead agents into assuming binary verification occurred.
7. **`dev impact` baseline behavior on clean branches**: On a clean worktree (`Dirty: False`), `dev impact` still diffs against `feature/todorbit-ui-redesign-2` (100 files) unless `-BaselineRef HEAD` is specified, and `docs/DEVELOPER_AUTOMATION_TOOLKIT.md` cites a non-existent `dev screenshot workspace-desktop-1080p`? (Actually `workspace-desktop-1080p` exists in `lab_render_test.dart`, though `Lab.psm1` passes `--plain-name` without listing valid scenarios in `dev screenshot` help).

---

## 5. Recommended Next Steps (Ordered by Importance & Cost)

### Priority 1 — High Impact, Low Cost (Quick Wins)
1. **Fix `TaskDetailsView` hardcoded purple (`#8B5CF6`) and priority tokens** (`lib/features/workspace/task_details_view.dart`) — *Cost: < 1 hour*. Replace with `Theme.of(context).colorScheme.primary` / `onPrimary` and `TodorbitThemeTokens.colorForPriority`.
2. **Fix `Workspace._subtaskRow` priority flag colors & `MobileWorkspace.mobileSubtaskRow` 48 dp target** (`workspace.dart`, `mobile_workspace.dart`) — *Cost: 1–2 hours*. Use `TodorbitThemeTokens`, filled high-priority flag, `bodyMedium`, and remove `VisualDensity.compact` on Android `mobileSubtaskRow` action buttons.
3. **Add `loadReviewFonts()` to `test/lab_render_test.dart`** — *Cost: 15 minutes*. Unblocks readable PNGs from `dev screenshot` immediately.
4. **Fix `dev.ps1` positional 3rd argument (`$SubArg`) & `Doctor.psm1` `.dart_tool/package_config.json` check** — *Cost: 30 minutes*. Makes `.\dev verify feature <name>` work as documented and catches unbootstrapped worktrees in `dev doctor`.

### Priority 2 — High Impact, Medium Cost
5. **Restore Android `Upcoming` parity & `showPlannedDate` handling in `AppTaskRow._buildMobile`** (`app_task_row.dart`, `mobile_workspace.dart`) — *Cost: 2–3 hours*. Group Android `Upcoming` by planned day in `TaskSort.schedule`, honor `showPlannedDate` + `semanticsLabel`, and dim completed mobile titles.
6. **Migrate `ThemeDialog` and `TaskDetailsView._addManualTime` to `AppModalShell` / scrollable forms** (`theme_dialog.dart`, `task_details_view.dart`) — *Cost: 2–3 hours*. Eliminates fixed `560x560` and IME overflow risks on `800x600` desktop and mobile viewports.
7. **Sync `feature_contexts.json` tests from `features.json` dynamically in `Harness.psm1` & enforce in `test_registry_sync.py`** — *Cost: 1–2 hours*. Eliminates 11/23 context pack test-list drifts and fixes `AppSpacing.rowGap` / `48 dp` inaccuracies.
8. **Fix `Workspace` sidebar scroll-footer divider, `20 dp` inset alignment, and `MobileWorkspace` empty-search condition** (`workspace.dart:1848`, `:2265`, `:2304`, `:2313`; `mobile_workspace.dart:986`) — *Cost: 1 hour*.

### Priority 3 — Medium Impact, Higher Cost / Architectural
9. **Audit remaining raw `AlertDialog` callers and `HabitsView`/`GoalsView`/`ReportsView` alignment** — *Cost: 0.5–1 day*. Adopt `AppPageHeading`, `1120 dp` vs `800 dp` unified max-width policy, error-styled destructive confirmations (`HabitsView._clear`), and distinct bottom-nav icons/labels on compact Android.
10. **Refine `CalendarWeekView` narrow overlapping card typography (`UI-04`) and Profile-mode dense-scroll raster performance** — *Cost: 1–2 days*. Show start-only time and drop redundant type icons at `itemWidth < 95` when time ranges would truncate; profile raster layer caching on real Windows Profile builds.
11. **Cache Python TDAT self-checks cleanly in `verify changed` and warn in `dev package` when `Binaries Audited == 0`** — *Cost: 2–3 hours*.
12. **Incrementally decompose `workspace.dart` (2,845 lines) and `task_editor.dart` (2,309 lines)** — *Cost: multi-day*. Extract sidebar, task list view, and subtask row components into dedicated files under `lib/features/workspace/`.

---

## 6. Verification Limitations

- **Offscreen vs. Live Native Runtime**: `dev screenshot all` rendered 11 offscreen widget-test PNGs with 0 `RenderFlex` overflows, but with Ahem placeholder fonts; visual typography/icon inspection relied on historical `59fdfc3` renders in `.buildlog/polish/` and `C:\Users\User\Documents\Codex\Todorbit-beta27-refinement-renders\` (valid for unchanged UI files since `59fdfc3`, noting `lib/domain/appearance.dart` updated dark default to Silver in Beta 28).
- **Host Blockers**:
  - `dev runtime windows -LiveApp -BuildLiveApp` is **BLOCKED** locally because Windows Developer Mode is disabled.
  - `dev runtime android` is **BLOCKED** locally (no API 36 16 KiB emulator or candidate APK).
  - Full Windows Profile GPU/raster tracing, physical DPI/accessibility checks (Narrator/TalkBack), and live two-client Google Drive OAuth sync were **NOT TESTED** in this review pass.
