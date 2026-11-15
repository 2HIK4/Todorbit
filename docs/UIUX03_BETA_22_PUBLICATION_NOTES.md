# Todorbit 1.0.19-beta.22 — Experimental Beta

Version 1.0.19-beta.22+45 for Windows x64 and Android GitHub distribution.

- Improve the sidebar and persistent search, with a shared Library menu for templates/routines and task sequences.
- Add Custom View multi-select category, project and priority filters, saved icons and view-management actions.
- Add category/project task visibility settings and synchronize those preferences across updated devices.
- Add Archive/Trash bulk selection with confirmed snapshots, atomic deletion and stale-record safeguards.
- Unify Resources: portable attachments, normalized links, Windows webpage-link/file/image/folder drag-and-drop and subtask resource assignments.
- Add a dedicated Task Details page with editing and return navigation.
- Add Focus Workspace with Stopwatch, Countdown and Pomodoro, correct work/break accounting and precise pause/resume.
- Retain Focus interval state across navigation and mini-timer return; improve Work Log totals and subsecond display. Process restart uses explicit checkpoint recovery and does not silently reconstruct a Pomodoro phase or count powered-off time.

## Migration and synchronization

Shared database schema advances to **29** through the existing verified Before
Upgrade backup/approval flow. Keep verified backups. Task/resource data, saved
views and preferences are preserved by the reviewed migration/sync/restore paths.
Update **all paired Windows and Android clients** before exchanging new data:
older clients reject schema-29 batches with update-required feedback and retain
local data/pending history. New clients accept supported schema-26/27/28 history.
Snapshot restore and incremental Sync remain separate. No downgrade migration is
provided; do not reopen a schema-29 profile in an older application.

Android retains its production package/signing identity with version code 45.
Windows remains unsigned under the established policy. Stable releases and the
separate reminder/alarm implementation are unchanged.

This is an experimental pre-release. Real Chrome input, physical DPI/accessibility,
Android background/IME/rotation, real multi-device service exchange and actual
built-in updater installation journeys remain manual acceptance; only executed
checks are claimed in the release evidence. Do not uninstall or clear app data
as an update workaround.
