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
| Distribution | The packages are unsigned, Windows 10 has not been tested, and the GitHub account and destination repository have not been confirmed. No public release is authorized. |

## Resolved decisions and release work

- The creator approved the exact MIT text in `LICENSE`, with Copyright (c) 2026 Hussam Alkhatib. `LICENSE.proposed` was retired. This is the project's license; bundled third-party terms remain separate.
- Public UI, executable, widget, shortcut, package, and documentation names use Todorbit. The installer AppId, `%LOCALAPPDATA%\Programs\Life Manager` installation directory, `%APPDATA%\TodoPilot` profile, older `%APPDATA%\Life Manager` profile, marker, and native IPC identifiers remain stable.
- Upgrade packaging removes only exact old executable and shortcut names. It changes an existing widget sign-in entry only when it exactly matches the old installed executable; this still needs installed verification.
- The bundle includes Flutter `NOTICES.Z`, the project `LICENSE`, Lucide attribution, .NET runtime and Windows Desktop licenses and notices, and SQLitePCLRaw license and notice. See [third-party notices](../THIRD_PARTY_NOTICES.md).
- A Windows 2022 GitHub Actions workflow runs analysis, serial Flutter tests, Release build, and the packaged widget self-test. It has not run on GitHub yet.

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
