# Private clean Windows acceptance

Use a disposable Windows user/VM. Never install this test setup on the owner's
normal account. APPDATA redirection is useful for local smoke but does not
isolate the Windows secure-storage identity or installer registration.

## Prepared Windows Sandbox path

On the current host Sandbox is disabled and the session is not elevated. The
owner action is: open **Turn Windows features on or off**, enable **Windows
Sandbox**, approve Windows elevation and restart when requested. This does not
require buying a domain or changing Google Cloud. The agent has not enabled it.

Prepare a fresh handoff from the reviewed private packages:

```powershell
./tools/prepare-windows-sandbox-acceptance.ps1 -PackagesDirectory '<private run>\packages'
```

Open the emitted `Todorbit-Acceptance.wsb` after Sandbox is enabled. It maps only
two package files, a fixed hash manifest and the runner read-only. A separate
empty output folder receives bounded `acceptance.json`; no profile/token files
are automatically exported. No repository, OAuth JSON or personal directory is
mapped. Network access supports normal Google authorization during manual work.

The runner refuses execution outside `WDAGUtilityAccount` at the specified
Sandbox location. Inside the fresh VM it verifies package hashes, installs per
user, checks registration, extracts portable to a path with spaces, starts and
restarts each distinct profile, inspects SQLite read-only, runs packaged widget
self-test, uninstalls while checking database preservation and reinstalls. The
script itself has been parsed and its host guard tested; actual VM execution
must produce evidence before any clean-user PASS. A script PASS covers only
the listed process/schema/installer checks, not GUI or Google acceptance.

## Manual checks remaining inside the VM

1. Start only one candidate at a time. Verify **Settings > Privacy & Data** shows
   the Sandbox user path: installed `TodoPilot` or location-keyed portable
   `TodoPilot\portable-…`. Confirm empty synthetic planner and no saved Google
   session. No JSON import/client ID entry should be needed or visible.
2. Connect an authorized external Google account through the normal browser.
   Record warning/block text without passwords, codes, callback URLs or tokens.
   Stop on security warnings; do not bypass them.
3. Create synthetic tasks/events/recurrence/relationships and recognizable
   preferences. Create full and settings-only encrypted backups. Observe real
   progress, verified completion, errors and history. Keep the recovery phrase
   private; do not put it in results or screenshots.
4. In a distinct disposable restore profile, verify wrong phrase rejection and
   preview/confirmation cancellation preserve sentinel records/settings. Confirm
   full restore, restart, Before Restore and recovery receipt. Separately apply
   selective settings/hotkey merge; planner rows must stay unchanged.
5. Restart, refresh, disconnect and reconnect normally. Confirm history survives.
   Delete only snapshots created for this VM test. Test offline/cancellation
   only against disposable objects; record which errors were actually exercised.
6. Check light/dark, narrow/normal windows, larger text, keyboard traversal,
   confirmations, disabled controls, focus and progress/error readability.
   Check physical Windows scaling separately from widget tests.
7. Repeat for installed and portable packages. Export only the bounded smoke
   result and a non-secret manual checklist; never copy the secure store, entire
   profile or recovery phrase back to the host. Closing Sandbox destroys its
   local data, not uploaded Google objects; clean up test objects first.

Full data-comparison and cloud evidence requirements remain in
[release readiness](GOOGLE_DRIVE_RELEASE_READINESS.md#required-packaged-acceptance--unverified).
Do not treat prepared scripts or the earlier account result as completed VM/UI
acceptance, Google policy approval or permission to publish.
