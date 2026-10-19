# TodoPilot 1.0.2 public-release audit

Updated 2026-10-19. This is a candidate assessment, not permission to publish.
The working build and automated tests use disposable data. The production
database, installed TodoPilot, and normal Windows profile were not used for
release acceptance.

## Verdict: NOT READY

### Publication blockers

| Finding | Evidence | Required decision or check |
| --- | --- | --- |
| Open-source license is unapproved | `LICENSE.proposed` is the only project license file. README calls MIT a proposal. | Creator reviews and approves a license, then the approved text and contribution terms are checked before publication. |
| Product-name clearance is unresolved | Existing productivity products use [TodoPilot](https://www.todopilot.app/), [ToDoPilot for Windows](https://www.todopilot.com/), and [TodoPilot on the App Store](https://apps.apple.com/jp/app/todopilot/id6804931706). A search result is not a trademark determination. | Creator obtains jurisdiction-appropriate name review, including the [USPTO search process](https://www.uspto.gov/trademarks/search), and decides whether to retain the brand. |
| Installed release behavior lacks direct acceptance | Inno Setup compiles, but no install, registered upgrade, uninstall, or reinstall was performed in a disposable Windows user or VM. | Run the `ACCEPTANCE.md` install and data-retention cases without the normal user profile. |
| Native desktop behavior remains partly unobserved | Self-tests and isolated shell attachment checks do not prove visible opacity, Win+D, input, or DPI behavior on target desktops. | Complete the manual checklist in `windows-widget.md`, including wallpaper contrast, resize, context menu, lock, and recovery. |

## Automated functional coverage

`flutter analyze` and 191 serial Flutter tests pass at this checkpoint. Tests
cover task CRUD and stale edits; category/project relationships; checklists and
subtasks; Anytime; calendar filters and event recurrence; Smart Reschedule;
habits, goals, templates, focus work, saved views, search, notifications,
Archive/Trash, backup/restore, import/export, attachments, PIN behavior,
appearance persistence, theme JSON validation, and contributors. These are
repository and Flutter widget checks; `ACCEPTANCE.md` tracks actual Windows GUI
flows separately. The Windows Release build and packaged native self-test pass.
The extracted portable widget self-test initially exposed a test-harness
assumption that ignored `PORTABLE-MODE`; that assertion was corrected, rebuilt,
and both packaged and extracted self-tests then passed. The final 27-entry ZIP
has the two executables, Flutter notices, outlined in-app mark, and Lucide
attribution, with no database, backup, log, key, or legacy executable entry.
Inno Setup 7.1.0 compiled the 1.0.2 installer; both packages are unsigned.

## Security and data review

- Fresh and portable profile isolation, explicit legacy import, backup before
  migration, and archive/restore are covered by disposable tests and prior
  isolated Release UI checks. An actual installer upgrade is still untested.
- App lock protects the UI, not SQLite files against someone with access to the
  Windows account. The README and release guide state this limitation.
- Theme import is validated data and does not modify the contributor registry.
  Native widget commands use profile-scoped IPC, with self-tests for mutex and
  command routing. Real two-process privacy behavior needs GUI acceptance.
- Targeted source and previously recorded Git-history scans found no obvious
  committed database, key, or credential. This is a scoped scan, not proof that
  arbitrary sensitive text is absent. Package entry and byte checks are a
  separate release gate.
- Flutter license notices and Lucide ISC attribution are required in both
  distributions. The .NET package vulnerability audit found no vulnerable
  packages in the current NuGet and local SDK sources; it is scoped to those
  sources and the native widget project.

## Public documentation and release quality

README, contribution and security guidance, code of conduct, changelog,
developer/theming documents, issue and pull-request templates, and a real
isolated-profile screenshot are present. The approved license, name clearance,
and GitHub destination are pending. The packages are unsigned; Windows
SmartScreen or antivirus reputation has not been verified. Windows 10 support
and installer shortcut/uninstall behavior are not claimed as tested.

No confirmed security, data-loss, or critical-function defect was found in the
automated gate. The unresolved publication decisions and manual release gates
above prevent a READY verdict.

The outlined orbit's transparent PNG and packaged Flutter asset were inspected.
The isolated Release process started, but the Windows inspection tool did not
enumerate its window. Thus the new sidebar mark has **not** passed the requested
actual-build visual check in either theme; this remains a manual gate.
