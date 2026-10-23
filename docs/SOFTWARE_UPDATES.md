# Windows software updates

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

The update helper is packaged with the app as a Flutter asset. It rechecks the
package after the main app exits. For a registered installation it runs the
existing Inno Setup package with the same AppId and install location. For a
portable copy, the app validates and extracts the complete ZIP to a sibling
folder before closing. The helper renames the existing application folder to
a rollback folder and moves the complete new folder into the *same exact
path*. This keeps the location-derived portable profile identity. The helper
restarts Todorbit. It records a result in `updates/<tag>/last-install-result.txt`.
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
