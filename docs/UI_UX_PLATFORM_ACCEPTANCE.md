# Platform acceptance handoff, Batch 6

This is an executable human checklist for the gaps in the existing
[40-group audit](UI_UX_PERMANENT_QUALITY_AUDIT.md#batch-6-platform-acceptance-and-theme-transfer).
It is **not a passing receipt**. Batch 6 could operate Windows Flutter through
Driver, but Windows native Computer Use was unavailable. The fresh Android AVD
eventually booted with package/connectivity services, but reliable operation was
not established after offline periods and repeated Bluetooth-service aborts.
No Todorbit installation or Android UI acceptance occurred in that AVD.

## Record outcomes

Use one row per ID **and substep** below; split theme, orientation, scale and
device variants when their results differ. Do not mark a group PASS if only one
variant ran. Retain failures and later corrections, rather than replacing them.

| ID / substep | Local time + offset | Revision / dirty hashes / artifact SHA-256 | Device / OS / scale / theme / input | Resolved disposable profile | Expected / actual | Outcome | Screenshot / log / reproduction | Retest reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Pending | | | | | | NOT TESTED | | |

Allowed outcomes: PASS (observed assertion), FAIL (observed mismatch), BLOCKED
(named environment/tool obstacle), NOT TESTED, INCONCLUSIVE. Applicability is
separate: record why an unsupported feature is N/A; do not count it as PASS.
State whether input came from a physical keyboard, tapped Android IME keys,
ADB key events, Flutter Driver or a screen reader. A screenshot alone does not
establish keyboard, focus, announcements, persistence or physical shell behavior.
Add the completed receipt to [the test ledger](TEST_RUN_LEDGER.md).

## Isolated preparation

Read [Testing](TESTING.md), [Windows widgets](windows-widget.md), and
[Android setup](ANDROID_SETUP.md). Use a build from the recorded source; keep
packaged Release acceptance separate from Debug. Never select the running
installed personal Todorbit or its companion. Retain profiles and evidence.

For Windows, the following **PowerShell 7** launch creates a new profile, starts
only the existing checkout's Debug executable, and records its environment. If
that executable is missing, build Debug from the intended source first; do not
substitute the installed app. Debug avoids Release's sign-in registration flow.

```powershell
git rev-parse HEAD
git status --short
$acceptExe = (Resolve-Path 'build/windows/x64/runner/Debug/Todorbit.exe').Path
$acceptRoot = Join-Path (Get-Location).Path ('.buildlog/manual-platform-' + [guid]::NewGuid().ToString('N'))
$acceptRoaming = Join-Path $acceptRoot 'Roaming'
$acceptLocal = Join-Path $acceptRoot 'Local'
$acceptFixtures = Join-Path $acceptRoot 'fixtures'
New-Item -ItemType Directory -Path $acceptRoaming,$acceptLocal,$acceptFixtures | Out-Null
if (Test-Path (Join-Path (Split-Path $acceptExe) 'PORTABLE-MODE')) { throw 'Use a nonportable Debug bundle for this procedure.' }
Set-Content (Join-Path $acceptFixtures 'resource.txt') 'Synthetic Todorbit platform acceptance resource.' -Encoding utf8
Set-Content (Join-Path $acceptFixtures 'invalid-settings.json') '{"format":"todorbit-shareable-settings","version":999,"categories":{}}' -Encoding utf8
Set-Content (Join-Path $acceptFixtures 'invalid-theme.json') '{"version":999}' -Encoding utf8
New-Item -ItemType Directory -Path (Join-Path $acceptFixtures 'linked-folder') | Out-Null
$acceptInfo = [System.Diagnostics.ProcessStartInfo]::new()
$acceptInfo.FileName = $acceptExe
$acceptInfo.UseShellExecute = $false
$acceptInfo.Environment['APPDATA'] = $acceptRoaming
$acceptInfo.Environment['LOCALAPPDATA'] = $acceptLocal
$acceptProcess = [System.Diagnostics.Process]::Start($acceptInfo)
[pscustomobject]@{
  PID=$acceptProcess.Id; Executable=$acceptExe; APPDATA=$acceptRoaming
  LOCALAPPDATA=$acceptLocal; ExpectedProfile=(Join-Path $acceptRoaming 'TodoPilot')
} | ConvertTo-Json | Tee-Object (Join-Path $acceptRoot 'launch.json')
Get-FileHash -LiteralPath $acceptExe -Algorithm SHA256
```

**Before interaction**, inspect Settings > Privacy & Data > Data profile and location and
confirm the actual path is `$acceptRoaming/TodoPilot`; confirm the SQLite file
appears there. Record the app PID and checkout executable path. Stop if these
do not match. For cold restart reuse the exact environment and executable above.
Companions launched by that app inherit its isolated environment; record their
PID/executable and observe changes only in this profile. Do not toggle Windows
startup in this checklist. Actual sign-in/installer behavior needs a disposable
Windows user or VM, since APPDATA alone does not isolate registry credentials.

For Android, use an explicitly disposable device/AVD and record its serial, API,
image revision, emulator version/renderer (if applicable), build hash and actual
app-private path. `adb devices -l` must identify the intended serial before any
installation or storage operation. Do not uninstall, clear data, wipe an AVD,
replace an image, or grant broad storage access to recover from a failure.
Before installation, sample `getprop sys.boot_completed`, `service check package`,
`cmd package list packages android`, `pidof system_server` and crash logs twice,
at least two minutes apart. Investigate service crashes/PID replacement before
using the environment as acceptance evidence. Mere boot completion is insufficient.
On a healthy emulator, install the recorded current-source development APK using
the [setup procedure](ANDROID_SETUP.md#install-and-exercise). Retain its data.
Place only the synthetic fixtures in that device's Downloads using Files or
`adb -s <verified-disposable-serial> push <fixture> /sdcard/Download/`.

In each platform's UI create a task `B6 Today`, an Inbox task `B6 Inbox`, a long
Unicode task, an event `B6 Agenda` on today at a recorded local time, one Goal
and one Habit. Record their IDs when available. Add 12 further tasks/events only
for dense widget/agenda cases; keep empty cases in a second disposable profile.
Use today's date, rather than the historical date in an old screenshot.

## Windows native pickers and return journeys

| ID / groups | Steps and assertions |
| --- | --- |
| W01 / S04,S40 | Edit `B6 Today`; leave an unsaved title suffix. Resources > Link file: select synthetic resource.txt in the **OS dialog**. Verify type/name, open it in the real viewer, return focus to Todorbit, and verify the parent draft survives. Save/reopen and cold restart; resource and title persist. Repeat with Add attachment; removing the reference must preserve the external original. |
| W02 / S04,S40 | Resources > Link folder: select linked-folder in the OS folder chooser. Open it in Explorer and return. Repeat file and folder selection with Cancel and native Escape; verify no new resource or parent-draft mutation. |
| W03 / S04 | Rename/move only the synthetic linked external file outside Todorbit. Reopen its resource: useful missing/unavailable feedback, no discarded task draft or app crash. Add a replacement resource through the supported UI. There is no dedicated Relink action. Test a deliberately unavailable test folder only if provisioned safely; otherwise record the access-denial variant NOT TESTED. |
| W04 / S20,S32 | Theme export uses a **text path prompt**, not a Windows picker: export to a new path longer than 60 characters; compare JSON after importing it, then Cancel. Separately use Share Settings > Export JSON's actual save dialog; choose destination, cancel, then export. Existing files must not be silently overwritten. Import through the actual native file chooser; cancel, then select the exported settings and inspect category preview. |
| W05 / S32,S40 | With a dirty parent editor, open/cancel any supported settings/resource chooser, switch to its native dialog and back, then close the child. Parent text, caret/focus and saved rows stay intact. Import invalid-settings.json and invalid-theme.json; show actionable errors, retain current settings and allow correction. |

## Windows keyboard, accessibility and scaling

Use both empty and populated views; sample light, dark and the imported palette.

| ID / groups | Steps and assertions |
| --- | --- |
| W06 / S19-S22,S40 | With the physical keyboard, traverse task editor, Settings, theme editor, date/color/select popups and confirmations using Tab/Shift+Tab. Record actual order and visible/unobscured focus. Enter/Space activate the intended control once; Escape closes the active layer, preserves a protected dirty draft and restores focus to its opener. Reach primary actions without a mouse. |
| W07 / S22 | In Hotkeys save a disposable preset, rebind New task, try an existing conflicting and an OS-reserved combination, then Cancel/Save as supported. Test actual key dispatch outside and inside text inputs and modal dialogs. New task/search/navigation must not activate unexpectedly while typing. Restore the preset and cold restart; stored binding and dispatch agree. Record the exact keys and conflict feedback. |
| W08 / S20,S21,S35 | Change a setting, Undo, Redo; confirm displayed and saved values separately. In text input use text Undo/Redo; it must not undo an unrelated settings change. Check Ctrl+Z, Ctrl+Shift+Z and Ctrl+Y where supported. Switch opening page, sidebar order and Calendar preferences, close/reopen and cold restart. |
| W09 / S19-S24,S40 | With Narrator actually speaking, record names/roles/values, order, selected/disabled state, validation/error/status announcements and entry/exit of nested modals. Include a populated task, resource error, Settings, theme color chooser and dirty-draft confirmation. Record spoken output or a short recording. A UIA tree alone is not a Narrator pass. |
| W10 / S20,S40 | On the test Windows environment record original contrast/text/DPI settings. Check an available high-contrast theme, 200% system text, ordinary/narrow/short windows and resizing with an open popup. Verify legibility, reachable actions and popup bounds. Restore the original settings afterward. Distinguish OS text, display scaling and app text scale. |
| W11 / S36-S37,S40 | If two monitors exist, record topology and each DPI, move app/widgets/popup across them, resize and restart. Position/size stay accessible, text and hit targets agree with the current monitor. Otherwise record physical multi-monitor testing unavailable; do not infer it from geometry unit tests. |

## Windows Tasks and Calendar companion

Run the relevant [native manual checklist](windows-widget.md#manual-regression-checklist)
for **both** widgets. Native Release/self-test remains mandatory after native
changes; it never substitutes for these observations. Do not kill/restart Explorer
or change startup registration as part of this profile-only procedure.

| ID / groups | Steps and assertions |
| --- | --- |
| N01 / S35-S37 | Enable Tasks, then Calendar. Record one isolated companion PID and two independently visible desktop windows. Hide/show each; the other keeps its visibility/geometry. Stop/restart only that companion via the isolated app/profile; both saved states return without duplicates. |
| N02 / S36 | In Today and Inbox use native Quick Add with physical typing, insertion, selection, paste, Backspace/Delete, Escape and Enter. Verify dates/destination, exactly one saved task, app refresh, completion persistence, long title/tooltips and empty state. Edit/reopen a task and open full details to the correct task. |
| N03 / S37 | Verify today's date, month navigation, selected date, correct task/event/session agenda and month indicators. Scroll all dense agenda rows; wheel over the grid must not scroll the agenda. Open a task/event/session and verify correct identity/date in Todorbit. Check empty and populated days. |
| N04 / S35-S37 | Configure Tasks; change title/opacity/color/text size, observe the **actual desktop preview**, then Cancel and compare saved JSON/appearance. Apply a different draft; editor stays open. Make another change then Cancel; latest Apply remains. Repeat for Calendar. Disabled Calendar must explain preview availability. |
| N05 / S35 | Give the widgets different appearance and specific navigation/cell/agenda settings. Apply to All: cancel confirmation once, then approve. Only listed shared appearance changes copy; visibility, geometry, lock, Tasks navigation/input and Calendar cells/indicators/agenda remain independent. Preset save/select/rename/delete, Undo/Redo and restart must match saved libraries. |
| N06 / S36-S37 | Exercise actual context menus, hover tooltips, keyboard focus, hidden headers/navigation and Edit This Widget. Drag header/background and every resize edge/corner; controls must not drag accidentally. Verify minimum size, text scale, opacity 0/30/70/100 and readable opaque text/input over light/dark wallpaper. |
| N07 / S36-S37 | Physically press Win+D twice and Alt+Tab; cover widgets with a normal window. Widgets belong to the desktop, stay below normal apps and do not steal focus. Leave visible five minutes; no black surface or capture-triggered repaint. Record actual observation, not an offscreen render. |
| N08 / S36-S37 | Close/reopen Todorbit three times with both widgets running; data and geometry persist and one companion remains. On a disposable Windows user/VM only, separately exercise approved sign-in and Explorer recovery. Record these variants NOT TESTED if that environment is unavailable. |

## Android Flutter and actual IME

| ID / groups | Steps and assertions |
| --- | --- |
| A01 / S01,S09,S19,S40 | Disable the emulator's hardware-keyboard preference if needed to expose its existing soft keyboard. Open task, event, Goal, Habit and a Settings text field. **Tap letters on the visible IME**, including mixed text, then insertion/deletion/cursor movement/selection. Record keyboard package, visible composing/caret state and resulting saved text for each field. Driver enter_text, ADB input text and clipboard paste alone do not pass this case. |
| A02 / S09,S19,S40 | With each dirty editor and IME open, rotate portrait/landscape, scroll to the last input and primary actions, and open an anchored selector near the bottom. No covered Save/Cancel, overflow, unexpected scroll jump or detached popup. Press system Back once to dismiss IME and again to leave; observe dirty-draft protection. Return from Files/viewer without losing the draft. |
| A03 / S20-S21,S40 | Repeat representative task/event/Goal/Habit/settings input in light and dark, with increased **system** font size in portrait and landscape. Record exact scale/viewport. Save, stop/reopen the app normally, then force-stop/relaunch only this disposable app to verify saved records/preferences. Unsaved process-death draft recovery is not promised. |

## Android native documents and transfer

Current SAF imports copy provider bytes into app-private temporary storage;
managed attachments are then retained in the profile. There is no persisted-URI
relink feature in this resource UI. Do not fabricate a grant-revocation journey
or request broad storage permission to test a capability that is absent.

| ID / groups | Steps and assertions |
| --- | --- |
| A04 / S04,S40 | From a dirty task draft choose Add attachment, select synthetic resource.txt through actual Android Files, open it in a real viewer and return. Cancel selection separately. Save/restart/reopen; the managed copy and parent text remain. Renaming/removing only the provider's synthetic original after import must not remove the completed app-private copy. |
| A05 / S04,S32,S40 | Where the disposable provider supports denial/unavailability, select an unreadable or unavailable synthetic document; observe useful failure and retained draft/settings. Restore provider availability and retry. If no controlled provider/failure mechanism exists, mark that variant BLOCKED or NOT TESTED. Revocation during reading is separate from revocation after a completed copy. |
| A06 / S20,S32 | Export theme/settings through ACTION_CREATE_DOCUMENT to Downloads; cancel and return once, then save. Import via ACTION_OPEN_DOCUMENT, inspect preview, Cancel, then selected Apply. Reject malformed/incompatible JSON without changing current values. Restart and compare stored values. Confirm there is no request for unrestricted storage. Transfer the valid settings into a second disposable profile/device; visibility, geometry, PIN, grants and platform navigation remain local as applicable. |

## Android Calendar launcher widget

| ID / groups | Steps and assertions |
| --- | --- |
| A07 / S38 | From the actual launcher add **Calendar**. Cancel configuration once (no ghost configured widget), add again, choose options and Apply. Record widget ID/launcher package, current date, week start and actual empty/populated agenda. This is distinct from a native RemoteViews test window. |
| A08 / S09,S38 | Navigate dates/months and every supported action. Open B6 Agenda and B6 Today; correct identity/date/editor opens. Repeat with Todorbit backgrounded and fully stopped as supported; dirty editors are protected when a widget activation arrives. Record any action unavailable in the actual widget rather than assuming desktop parity. |
| A09 / S38 | Change appearance/settings and verify preview/Apply/Cancel behavior actually provided by Android configuration. Resize through launcher handles to minimum/large sizes, including long content and increased system font. Refresh/restart app and launcher, then reboot the disposable device; widget identity/content/settings persist. Test same-signature app update only if a compatible verified pair is already available. |
| A10 / S38 | Recheck Tasks only for shared dependencies touched by a confirmed fix or an observed shared problem. Otherwise retain its earlier scoped evidence and record no new Tasks acceptance. Physical OEM/ARM64 widget acceptance still requires a real device; an emulator launcher is insufficient. |

## Actual Android accessibility

| ID / groups | Steps and assertions |
| --- | --- |
| A11 / S09,S19-S24,S38,S40 | If TalkBack is already available on the disposable device, enable it and use speech plus touch exploration. Verify task/event/Goal/Habit labels, roles, order, focused field, actions and validation/status announcements; navigate into/out of nested modals and native Files and back. Record spoken output, not package presence. |
| A12 / S38,S40 | Explore and activate the Calendar widget with TalkBack: date/agenda labels, order, navigation actions and correct item opening. Repeat important controls with large system text. If TTS/service/launcher cannot provide meaningful speech/actions, record INCONCLUSIVE/BLOCKED and the exact obstacle. A physical-device run remains a separate result. |

Prioritize W01-W05, W06/W09, N02-N07 and A01-A09/A11-A12. These close native
input, accessibility and persistence risks that host tests cannot settle. Record
high-impact unverified cases explicitly; do not declare app-wide acceptance
complete while they remain open.
