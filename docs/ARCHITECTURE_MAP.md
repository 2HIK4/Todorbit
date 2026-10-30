# Feature entry points

Read this index first, then only the relevant source and tests. [Architecture](ARCHITECTURE.md)
owns lifecycle and boundary details; [Testing](TESTING.md) owns acceptance gates.
Paths are repository relative. `tools/dev/features.json` owns runnable host-test groups.

| Feature | Presentation / entry | Logic and persistence | Start with these tests / group |
| --- | --- | --- | --- |
| Task editing | `lib/features/workspace/task_editor.dart` | `lib/app/app_controller.dart`, `lib/data/life_repository.dart`, `lib/domain/models.dart` | `test/repository_test.dart`, `test/task_editor_schedule_layout_test.dart`; `tasks` |
| Calendar | `lib/features/calendar/calendar_view.dart`, `event_editor.dart`, `session_editor.dart` in that directory | `lib/data/event_repository.dart`, `lib/domain/recurrence.dart`; scheduling in `lib/domain/scheduling_engine.dart` | `test/calendar_improvements_test.dart`, `test/event_recurrence_test.dart`; `calendar` |
| Android shell | `lib/features/mobile/mobile_workspace.dart`, `mobile_settings.dart` in that directory | Shared controller/repository; `lib/platform/android/android_platform.dart` | `test/mobile_workspace_test.dart`, `test/mobile_editors_test.dart`; `mobile` |
| Android reminders | `lib/platform/android/android_surfaces.dart` | `lib/data/notification_repository.dart`; `AndroidSurfaces.kt`, `ReminderRefreshJob.kt` under `android/app/src/main/kotlin/io/github/hik4/todorbit/` | `test/android_platform_test.dart`, `test/notification_repository_test.dart`; `notifications` |
| Drive snapshots / transfer | `lib/features/settings/backups_cloud_page.dart` | `lib/data/cloud/cloud_backup_service.dart`, `cloud_transfer_history.dart`, `google_drive_provider.dart`, `google_drive_auth.dart` in that directory; `lib/data/backup_service.dart` | `test/cloud/`, `test/cross_platform_backup_test.dart`; `drive` |
| Android OAuth | `lib/platform/android/android_google_drive_auth.dart` | `MainActivity.kt` in the native directory above; identity in OS secure storage, access tokens in memory | `test/android_google_drive_auth_test.dart`; `drive`; real account acceptance separate |
| Android updates | `lib/features/settings/android_software_updates_page.dart` | `lib/platform/android/android_update_service.dart`; `AndroidUpdater.kt` in `android/app/src/github/kotlin/io/github/hik4/todorbit/` and `android/app/src/play/kotlin/io/github/hik4/todorbit/` | `test/android_update_service_test.dart`, `test/android_software_updates_page_test.dart`; `android-updates` |
| Windows updates | `lib/features/settings/software_updates_page.dart` | `lib/data/software_update_service.dart`, `lib/data/update_helper_launcher.dart`, `tools/update-helper.ps1` | `test/software_update_service_test.dart`, `test/update_helper_launcher_test.dart`; `windows-updates` |
| Android launcher widgets | `lib/features/mobile/mobile_settings.dart`, `lib/platform/android/android_surfaces.dart` | `AndroidSurfaces.kt` in the native main directory above; bounded read-only projections and device preferences | `test/android_platform_test.dart`; on-device placement/reboot/update acceptance |
| Windows widgets | `lib/features/widget/native_widget_service.dart`, `lib/features/settings/widget_settings_page.dart` | `lib/data/widget_configuration_store.dart`; `experiments/widget-shell-probe/Program.cs`, `LifeManagerWidget.cs`, `CalendarWidget.cs` | `test/native_widget_service_test.dart`; `widgets`; packaged native self-test/manual checklist |
| Preferences / portable settings | `lib/features/settings/settings_hub_dialog.dart`, `settings_transfer.dart` in that directory | Profile stores in `lib/data/`; controller coordinates changes | `test/settings_transfer_test.dart`, `test/profile_isolation_test.dart`; `settings` |
| SQLite / startup / restore | `lib/main.dart` | `lib/data/app_database.dart`, `migration_gate.dart`, `backup_service.dart`, `profile_fingerprint.dart` in that directory | `test/database_initialization_test.dart`, `test/migration_gate_test.dart`; `database` |

## Dependency direction

Presentation calls the shared `AppController`, repository and existing services.
`LifeRepository` and its `part` files own Flutter SQLite writes; pure domain code
does not import UI or native adapters. Profile JSON stores own device/preferences
data. Keep native platform calls in adapters and the method-channel boundary.
Do not move shared scheduling, recurrence, snapshot encryption or version parsing
into separate Android/Windows implementations. The Windows companion's narrowly
scoped writer never migrates schemas. Android native surfaces never write SQLite.

## Common paths

- A new task field crosses model, repository/schema, controller, editor, transfer
  and native readers. Use `database` plus the affected presentation tests; expand
  to full verification for schema or shared-model changes.
- Calendar layout starts in `calendar_view.dart`; recurrence behavior starts in
  `recurrence.dart` and `event_repository.dart`. Native Calendar is independent.
- Android reminder delivery crosses Dart projection, native alarm/job and lifecycle;
  host planning tests alone cannot prove notification delivery after reboot/Doze.
- Drive transport changes start in `google_drive_provider.dart`; encryption in
  `cloud_backup_codec.dart`; restore/startup in `backup_service.dart` and `main.dart`.
  Preserve `drive.appdata`, UUID versions, account pinning and Before Restore.
- Android update discovery is Dart; signature verification, permission and install
  are native GitHub flavor behavior. Play has a separate store flow and no installer.
  Release tooling is `tools/prepare-android-release.py` and `.github/workflows/android-release.yml`.
- Small visual changes use the nearest shared control in `lib/features/shared/`;
  test the changed layout at compact width and larger text before broadening.

Read [Codex workflow](CODEX_WORKFLOW.md) for commands and interruption recovery.
