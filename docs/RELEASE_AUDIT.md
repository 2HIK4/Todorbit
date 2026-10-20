# Todorbit 1.0.3 public-release audit

Updated 2026-10-20. This is a candidate assessment, not permission to publish.
The normal installed application and personal data were not used for acceptance.

## Verdict: NOT READY

| Open gate | Evidence and required check |
| --- | --- |
| Formal name clearance | The creator selected Todorbit after the [preliminary review](NAMING_REVIEW.md). Public web and exact GitHub-name searches found no direct exact match at the time, but trademark register results were not verified. A jurisdiction-specific review of similar marks remains necessary. |
| Installed upgrade and uninstall | Inno Setup compiles, but a fresh install, registered TodoPilot upgrade, uninstall, and reinstall have not been run in a disposable Windows user or VM. Confirm profile selection, data retention, shortcuts, and widget sign-in migration with [the acceptance matrix](ACCEPTANCE.md). |
| Native desktop behavior | A packaged widget self-test and earlier read-only Explorer attachment inspection do not prove Win+D visibility, wallpaper opacity, input, DPI, multiple monitors, or Explorer recovery. Complete the [manual widget checklist](windows-widget.md). |
| Broad GUI acceptance | The extracted 1.0.3 portable app opened from a path with spaces and showed the renamed dark Today UI. A disposable task dated today appeared and persisted after restart; a second extraction was empty. The earlier isolated 1.0.2 app showed the outlined mark in both light and dark themes and completed an Anytime task. Other end-to-end flows in [the acceptance matrix](ACCEPTANCE.md) remain open. |
| Distribution | The packages are unsigned and Windows 10 has not been tested. The authenticated `2HIK4` account and private `2HIK4/Todorbit` repository are confirmed. No public release is authorized. |

## Resolved decisions and release work

- The creator approved the exact MIT text in `LICENSE`, with Copyright (c) 2026 Hussam Alkhatib. `LICENSE.proposed` was retired. This is the project's license; bundled third-party terms remain separate.
- Public UI, executable, widget, shortcut, package, and documentation names use Todorbit. The installer AppId, `%LOCALAPPDATA%\Programs\Life Manager` installation directory, `%APPDATA%\TodoPilot` profile, older `%APPDATA%\Life Manager` profile, marker, and native IPC identifiers remain stable.
- Upgrade packaging removes only exact old executable and shortcut names. It changes an existing widget sign-in entry only when it exactly matches the old installed executable; this still needs installed verification.
- The bundle includes Flutter `NOTICES.Z`, the project `LICENSE`, Lucide attribution, .NET runtime and Windows Desktop licenses and notices, and SQLitePCLRaw license and notice. See [third-party notices](../THIRD_PARTY_NOTICES.md).
- The Windows 2022 GitHub Actions workflow passed analysis, serial Flutter tests, Release build, and the packaged widget self-test at tag `v1.0.3` (`919c618`).

## GitHub and package verification on 2026-10-20

- `v1.0.3` resolves to `919c618`; the existing private prerelease targets the development branch at that commit. All four observed Windows workflow runs passed, including the tag run. The only change after the original `67619fe` package checkpoint is the README screenshot; application source is unchanged. No binary or tag was replaced.
- Local installer and portable hashes match `release/SHA256SUMS.txt` and the GitHub asset digests. The uploaded checksum file's digest also matches the local file. The ZIP CRC check passed; its 33 entries include four directory entries and 29 files. No database, backup, log, key, or obsolete executable appears in its entries. The installer remains unsigned; its installed behavior has not been tested.
- The README, MIT license, contributor and security guidance, third-party notices, issue template, PR template, and source build commands are present. Visual inspection found that the screenshot committed at `919c618` displayed old TodoPilot branding and an empty Today view. The original `67619fe` sample-profile image shows Todorbit and a task and has been restored on `main` and the development branch. The existing prerelease tag still contains the incorrect screenshot; resolving that tag snapshot requires a reviewed release strategy. A scoped scan of 51 Git revisions found no tracked private data paths or common token/private-key signatures; this does not prove the entire history contains no personal information.
- Private `main` now exists as a linear descendant of the development branch and is the default branch. Existing branches and the prerelease tag remain. Repository topics are `flutter`, `windows`, `productivity`, `sqlite`, and `offline-first`.
- GitHub vulnerability alerts were enabled. Branch protection returned HTTP 403 because this private repository's current plan does not provide that feature; Dependabot alert listing was unavailable. Review those settings after publication.
- The existing prerelease notes have two malformed Portfolio/LinkedIn Markdown links and describe portable data only generally. A safe metadata-only correction would replace those links with standard `[Portfolio](...)` and `[LinkedIn](...)` links and point users to `docs/INSTALLATION.md` for the location-keyed `%APPDATA%\\TodoPilot` profile. The prerelease metadata was left unchanged pending the release review; no assets need replacement for this correction.

## Validation scope

`flutter analyze`, all 191 serial Flutter tests, and the final Windows Release
build passed. Two focused Flutter tests passed after their fixture paths were
renamed. The native .NET Release build had no warnings, and the packaged and
extracted portable widget self-tests passed. Inno Setup 7.1.0 compiled the
installer. The 29-file ZIP contains both executables, MIT and third-party
notices, Flutter notices, and the Todorbit brand asset; its entry scan found no
database, backup, log, key, or old executable. The installed behavior is still
unverified. Current package paths and hashes are in [PROGRESS.md](PROGRESS.md)
and `release/SHA256SUMS.txt`.

A targeted review of tracked paths and 48 Git revisions found no private key, database, credential, or obvious token signature. This scan does not prove the absence of all sensitive data. The .NET vulnerability query reported no vulnerable packages from the configured NuGet and local SDK sources. App lock protects the UI and does not encrypt SQLite files. Theme JSON is validated data and does not alter the official contributor registry.

No confirmed data-loss, security, or essential-function defect was found in the tested scope. The open gates above prevent a READY verdict.
