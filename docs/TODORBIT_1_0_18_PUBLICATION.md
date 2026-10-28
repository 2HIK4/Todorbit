# v1.0.18 widget hotfix publication

[Public Windows x64 pre-release](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.18)
published **2026-10-28 13:00:50 UTC / 16:00:50 Amman**. Version **1.0.18+19**,
source/tag **08eab9a2202362514f97ac2683b0905e5b9144a7**. The user explicitly
authorized verified publication. This is a pre-release, excluded from Stable;
v1.0.17/tag `cae2b4b` remains unchanged. Main is fast-forwarded to the source,
with this documentation checkpoint following it.

[Release notes](TODORBIT_1_0_18_RELEASE_NOTES.md).
[Detailed findings and regression boundaries](WIDGET_STARTUP_HOTFIX.md).
[Exact source diff](https://github.com/2HIK4/Todorbit/commit/08eab9a2202362514f97ac2683b0905e5b9144a7).

## Causes and fixes

1. **Calendar preference:** Close Widget used the persistent Hide operation,
   saving `enabled=false`. Updates preserve that profile file, so the false
   value survived. Close Widget now suppresses only the current session; the
   tray Exit widgets operation remains a process shutdown. Explicit Settings
   and tray Show/hide still persist their intended preference. No independent
   installer/portable reset of an explicitly enabled configuration was reproduced.
2. **Reopening:** Release startup synchronized Windows registration but never
   restored enabled widgets unless reminders separately started a companion.
   It now sends restore independently of registration success. Restore uses
   the existing profile mutex/pipe, preserves active editors and existing HWNDs,
   honors both saved enabled flags, and does not apply layout/presets anew.
   Reminder-only startup shows neither widget; the sign-in command restores
   enabled widgets without opening Flutter. Session suppression survives
   appearance reload and Explorer recovery. Missing enabled fields use consistent
   Tasks-on/Calendar-off defaults without overwriting explicit booleans/files.
3. **Navigation text:** a choice against opaque accent was followed by a second
   conditional black/white correction against translucent composition. The new
   range regression fails on the old rule with two foreground changes. Selection
   now makes one maximum-contrast decision against stable theme composition,
   with at most one transition in tested opacity sweeps. Explicit text colors,
   independent text alpha, text protection and the existing preview/history
   cadence remain intact. No wallpaper sampling or extra polling was added.
4. **Calendar square:** this denotes a planned task, independent of today and
   events. Its grid marker is now a 4-logical-pixel circle inset five pixels,
   darkened from the composed cell background with a subtle contrast edge.
   Session geometry and agenda task squares remain unchanged. Event rules remain
   0 none, 1-3 dots, 4+ a line; date outlines/selection remain unchanged.

A false saved by an older Close Widget action cannot be distinguished from an
intentional disable. The hotfix preserves it; enable that widget once in Settings
if needed. No database schema change, data reset, profile rename or cloud change.

## Changed components and regressions

- Startup/persistence: `lib/main.dart`, `lib/features/widget/native_widget_service.dart`,
  `lib/data/widget_configuration_store.dart`, native `NativeDesktopWidgetHost.cs`
  and `WidgetConfiguration.cs`.
- Native drawing: `WidgetSurfaces.cs`, `CalendarWidget.cs`.
- Flutter regressions: `widget_configuration_test.dart`, `native_widget_service_test.dart`,
  and opt-in `native_widget_launch_integration_test.dart`. Both widgets' four
  enabled combinations, production-shaped old settings, read-only migration,
  forwarding, process exit/restart and unchanged personalization are covered.
- Native regressions: `WidgetConfigurationSelfTest.cs`, `WidgetLifecycleSelfTest.cs`,
  `CalendarWidgetSelfTest.cs`: independent flags, close/reopen, host/editor
  preservation, background/sign-in commands, opacity 0-100%, light/dark/custom
  colors, explicit overrides, alpha, event counts, marker bounds and scaled renders.
- `tools/test-portable-update.ps1` now hashes both enabled widget configurations
  across replacement/rollback, checks one companion, and cleans up restarted
  companions. `tools/test-single-instance.ps1` suppresses sign-in registration
  for its fixtures and closes their companions. Version metadata is synchronized
  in `pubspec.yaml`/native project; changelog and release documentation are updated.

## Verification

| Gate | Result |
| --- | --- |
| [Exact-source Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40690309900) | PASS on `08eab9a`: analysis, **357 tests passed / one opt-in skip**, OAuth/package gates, Windows x64 Release, portable, packaged native self-test, installer/checksums. |
| Local Flutter | Focused **26 pass**; full serial **357 pass / one opt-in skip**; opt-in actual companion check separately **1 pass**. Whole/targeted analysis, changed-Dart formatting and diff checks pass. |
| Native | Release build: zero warnings/errors. Source and final packaged self-test and actual-HWND lifecycle pass. Repeated restore keeps the same hosts and active quick editor. |
| Rendering | Final packaged offscreen fixtures inspected in light/dark, including 100% and 200% scaling; generated 100/125/150/200% fixtures, compact/large, transparent, 4/5/6-week layout assertions. These are not physical DPI acceptance. |
| Debug runtime | Verified isolated APPDATA/LOCALAPPDATA and actual Drift profile path; hot reload succeeded, runtime diagnostics clean; test app closed afterward. |
| Main-app lifecycle | Actual Release opens both enabled HWNDs; second launch exits into the existing main/companion with identical HWNDs. Close main -> Exit widgets -> reopen restores both. Configuration and geometry bytes match. Explicit Calendar Off yields Tasks only. |
| Sign-in/reminders | Actual sign-in command starts enabled widgets without main; background context shows neither. Actual OS login/notification receipt remain unverified. |
| Single instance / handoff | Updated isolated single-instance/profile and update-handoff harnesses pass. |
| Portable updater | Real bundled helper public v1.0.17 -> v1.0.18 swap/restart and injected wrong-version rollback/reopen pass at the same path with spaces. All **45 schema-22 tables/values**, task/project/category/session/event data, widget enabled/customization files and profile identity retain matching digests. Updated portable harness also passes success and failure modes. |
| Backups and migration | Full suite includes existing local snapshot/settings transfer/encrypted fake-Drive restore, presets, reminders, schema migration and interrupted initialization coverage. No schema change or real-account OAuth retest. |
| Package audit | Approved public v1.0.17 OAuth configuration verified by its public package hash/receipt; enabled local builds preserve it. Tracked config restored disabled/empty. PE versions, 33-entry ZIP CRC/full-bundle equality, runner/AOT receipt, private-file guards, checksums and sidecars pass. |
| Public verification | Private draft source/classification/notes/all five GitHub SHA-256 digests verified before publishing. Anonymous HTML/lazy asset links/API pass. Both downloaded public binaries equal local bytes; public ZIP CRC passes. Production updater from v1.0.17 discovers/downloads/verifies installer and portable; Stable excludes this pre-release. Packages are not executed by discovery checks. |
| Personal state | Run and installed-registration fingerprints match before/after. Every fixture is isolated; no personal database, token, preference or installed setup is used. |

## Public assets

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Todorbit-1.0.18-win-x64-setup.exe | 47,243,956 | `87d39541ea6d85a719255fb57e0c65a9c88769fd342720e0cbc272616e4b5382` |
| Todorbit-1.0.18-win-x64-portable.zip | 62,421,403 | `f99878ddc8516f5fc042c40e0ac829cc7e2c485c807f3eec91acfc6b9fc1cb20` |

Both `.sha256` sidecars and `Todorbit-1.0.18-SHA256SUMS.txt` are published.
Packages are unsigned. Installer compilation/content guards and updater
metadata/integrity pass; **registered installer replacement/rollback/restart
and uninstall were not executed** on the owner's account.

## Remaining target-system acceptance

Physical mouse/keyboard dragging, multi-monitor/Explorer/Win+D behavior, actual
Windows login, physical Windows display scales at 100/125/150/200%, clean-user/VM
installer upgrade/uninstall and notification receipt remain unverified. The
native lifecycle/scaled render checks do not establish these. Real Google
OAuth/branding policy and clean-machine trust limits remain as documented.
These limits are stated in the published release notes; no manual pass is inferred.

Ignored detailed evidence is under `.buildlog/widget-hotfix/`, including CI,
artifact/draft/public/updater receipts and isolated lifecycle logs. No builds,
credentials, test databases or machine settings are committed.
