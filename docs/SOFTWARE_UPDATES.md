# Windows software updates

> **2026-10-26 release update:** the owner has now approved an enabled
> v1.0.13 **experimental pre-release**, main merge and website updates.
> This supersedes the earlier publication hold below, while preserving
> every skipped/unverified test and unresolved policy limitation. See
> [the publication record](TODORBIT_1_0_13_PUBLICATION.md) and
> [release notes](TODORBIT_1_0_13_RELEASE_NOTES.md). Historical blocked
> conclusions below describe their earlier checkpoints.

2026-10-26 private engineering checkpoint: real production-service GitHub
checks/downloads validated both actual public v1.0.12 assets and correctly offer
no newer release to v1.0.13. The actual bundled portable helper passed isolated
readiness/parent-exit, injected version-mismatch rollback/reopen and a complete
local v1.0.12 -> private v1.0.13 swap/restart, preserving all 44 tables, selected
preferences and exact profile path. No setup was run; personal installation
registration and Run entries were unchanged. Registered installed-mode execution
and physical in-app update GUI remain unverified. The owner skips clean-user/VM
acceptance for this release. See [evidence and limits](GOOGLE_DRIVE_ENGINEERING_ACCEPTANCE.md).

Settings > Software Updates checks published releases from `2HIK4/Todorbit`.
Stable ignores pre-releases; Pre-release may choose either. The checker compares
semantic versions and requires the exact Windows x64 setup or portable asset,
its uploaded state, size, HTTPS GitHub release URL, and GitHub's SHA-256 asset
digest. Missing metadata blocks installation. Untagged builds are not updates.
Automatic checking is on by default and makes no download or install change.
The per-profile `update-settings.json` is versioned and stored beside the
profile's existing settings. A malformed or newer format is reported; it is
never overwritten with defaults.

Downloads go to the active profile's `updates/<tag>` folder. Interrupted
downloads leave no accepted package. The app verifies size and SHA-256 during
download and immediately before installing. HTTPS redirects are restricted to
GitHub release delivery hosts. The confirmation dialog explicitly states that
current releases are unsigned: the GitHub digest checks integrity, but does
not independently authenticate the publisher. Do not accept an unsigned
update if you cannot trust the release or repository account.

The update helper is packaged with the app as a Flutter asset. Todorbit waits
for its ready receipt before closing; an early helper failure remains visible
in Settings. The helper rechecks the package and registered target, checks for
a second app at the same bundle path before handoff, then waits for the main
app and widget to exit. It holds a Windows update mutex during installation;
new app launches exit promptly and the helper restarts Todorbit. An
existing conflict is reported with its process ID. For a registered
installation it runs the
existing Inno Setup package with the same AppId and install location. For a
portable copy, the app validates and extracts the complete ZIP to a sibling
folder before closing. The helper renames the existing application folder to
a rollback folder and moves the complete new folder into the *same exact
path*. This keeps the location-derived portable profile identity. The helper
restarts Todorbit only after the replacement executable's product version
matches the selected release. It records a result in
`updates/<tag>/last-install-result.txt`. A failed or canceled setup records the
error and attempts to reopen the available app. Inno Setup runs silently for
this per-user installation; its progress window may appear, but the wizard and
UAC prompt should not appear for the default path. The installer writes
`updates/<tag>/installer.log` for diagnosis.
An installation moved to a protected location may fail because this per-user
installer does not request elevation; install manually from the owning account
after reviewing its permissions. Running an elevated installer under a different
account could select a different profile and is not attempted automatically.
After a post-handoff failure the helper also shows a Windows error message;
the detailed reason remains in the result file and appears in Software Updates
on the next visit.
The helper waits for the native widget from that installation to exit before
replacing files. A portable restart that exits within three seconds triggers
binary rollback. The updater leaves profile databases, attachments, backups,
and other settings in place; the Software Updates page writes only its own
`update-settings.json` preferences.
Do not move the portable folder during recovery.

On next launch the existing migration gate checks the SQLite schema. A schema
upgrade requires the user's approval and creates a verified SQLite online
backup before migration. Binary rollback does not reverse a database
migration. If the older executable cannot open a newer database, leave the
database untouched and use the matching version or a reviewed database restore.
The `updates` folder and portable rollback folder can be removed only after
checking the new app and preserving any backup you need.

The published v1.0.6 app still contains the failed detached handoff. Upgrading
that registered copy to [v1.0.8](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.8)
requires one manual installer run (after verifying the published package).
Keep the same Windows account, AppId, and installation path. Later updates are
intended to use the repaired in-app flow, which still needs a registered-install
test. Do not run a disposable test against the personal registered installation
or profile.

## Publishing a compatible release

1. Set the same version in `pubspec.yaml` and the standalone native widget
   project. Build the Windows Release bundle and run the native widget
   self-test and the checks in `docs/windows-widget.md`.
2. Run `./installer/build-installer.ps1` and `./tools/build-portable.ps1`.
   Keep the bundle together. Inspect both packages for personal data, settings,
   databases, logs, and secrets.
3. Create a **published GitHub Release** tagged `vX.Y.Z` or a valid semantic
   pre-release tag such as `vX.Y.Z-rc.1`. Use the exact asset names
   `Todorbit-X.Y.Z-win-x64-setup.exe` and
   `Todorbit-X.Y.Z-win-x64-portable.zip` (with the pre-release suffix in each
   filename when present). Upload complete files and confirm GitHub displays a
   SHA-256 digest for each asset. Mark pre-releases appropriately and include
   release notes.
4. Sign both packages with an approved publisher certificate when available.
   Until then, retain the explicit unsigned warning and do not describe the
   GitHub digest as a signature.
5. On isolated Windows profiles, exercise installed and portable updates,
   restart, widget shutdown, profile identity, database migration and recovery,
   and repeated attempts. Do not test against a personal profile.

If an update fails, inspect `last-install-result.txt`, keep the staged package
and rollback folder, and retry after resolving file locks or install
registration. For a portable swap failure, the helper tries to put the old
folder back. For an installer failure, use the verified previous installer;
keep the profile and its backups untouched. An Inno exit code of zero and a
restart request do not by themselves prove the new app launched correctly.
The three-second portable restart check catches immediate exits, but it does
not establish that startup, migration approval, or later use succeeded. Keep
the rollback folder until the updated app and profile have been inspected.
