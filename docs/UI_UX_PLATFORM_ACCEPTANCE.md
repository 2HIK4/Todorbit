# Platform acceptance handoff, Batch 6

This is an executable human checklist for the gaps in the existing
[40-group audit](UI_UX_PERMANENT_QUALITY_AUDIT.md#batch-6-platform-acceptance-and-theme-transfer).
It is **not a passing receipt**. Batch 6 could operate Windows Flutter through
Driver, but Windows native Computer Use was unavailable. The fresh Android AVD
eventually booted with package/connectivity services, but reliable operation was
not established after offline periods and repeated Bluetooth-service aborts.
No Todorbit installation or Android UI acceptance occurred in that AVD.

## Final acceptance session, 2026-11-04

Continues `227ecf8b6c720449003654fce15149ed92fdec26` on
`feature/final-platform-acceptance`. The W/N/A procedures below remain the test
plan. Detailed ignored evidence is in `.buildlog/verify/final-platform-acceptance/`;
`baseline.json` records the three protected storage-document hashes and initial
dirty patch. No application source, assertions or dependencies have changed.

Windows Computer Use (`sky.list_apps()` and `cua.getState()`) reports the missing
native pipe, os error 2. DTD discovery/connect succeeds, initially with no apps.
The installed personal processes (app 31540, companion 17028) are excluded from
all interaction. Native picker, keyboard, Narrator, shell, DPI and multi-monitor
variants need human observations; Driver cannot close them.

The retained disposable API35 `TodorbitBatch6` AVD was started once at
17:58:33+03:00 on `emulator-5584`, using its existing userdata and unchanged host
OpenGL/no-Vulkan configuration. Startup was initially offline and then lacked
IME/real Home. At 18:01:59 and 18:04:33, boot=1, `system_server` PID592 remained
unchanged, package/input/input_method/activity services were found, package
queries succeeded and Home resolved to Pixel Launcher. Both crash buffers were
empty. Actual ADB swipe opened the drawer, and tapping Settings eventually
resumed its activity. An expansive IME diagnostic timed out while dumping the
IME's internals; it is not an application failure. This establishes a bounded
environment preflight only. No Todorbit installation or app acceptance occurred
during that boot. The AVD was stopped at 18:06:10 to leave memory for a
current-source development APK build; health must be rechecked after resuming.

The current-source development x64 APK built and passed native alignment, SHA-256
`0f0063f8328fcc72b73876c1ffbb8af20e3d915cb1ad0a0f28147c9a39376566`.
The same AVD resumed at 18:19:20 after the build, with unchanged data/image/config.
It passed one service sample at 18:21:34 (PID579), then **failed** the separated
check at 18:24:00. Crash evidence records `system_server` SIGABRT in
`WifiScanningSer` at 18:22:38, Pixel Launcher finalizer timeout and dependent
`DeadSystemException`s. Package, input, IME and activity services are absent even
though boot still reports1. No installation was attempted. Android app/native
execution remains environment-blocked; A10's conditional rerun is separate below.
The earlier first-boot preflight PASS is retained
only for that bounded observation. There is no third launch or product workaround.

No whole W/N/A ID is complete from these capability checks. See the session
[receipt](UI_UX_PERMANENT_QUALITY_AUDIT.md#final-platform-acceptance-continuation)
for invocations, reuse decisions and later outcomes.

## Record outcomes

Use one row per ID **and substep** below; split theme, orientation, scale and
device variants when their results differ. Do not mark a group PASS if only one
variant ran. Retain failures and later corrections, rather than replacing them.

| ID / substep | Local time + offset | Revision / dirty hashes / artifact SHA-256 | Device / OS / scale / theme / input | Resolved disposable profile | Expected / actual | Outcome | Screenshot / log / reproduction | Retest reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Preparation / Android startup | 2026-11-04 17:58:52+03:00 | `227ecf8`; FPA `baseline.json` | API35 x64 AVD `TodorbitBatch6`, `emulator-5584` | Retained Batch6 AVD; no Todorbit installed | Expected available services; ADB offline | BLOCKED | FPA `sample1-*` | First sample in one bounded boot |
| Preparation / Android partial boot | 2026-11-04 17:59:40+03:00 | Same source/configuration | Same AVD, native service probes | Same AVD | Package/input/activity found; IME absent, Home=`FallbackHome`, boot property empty | INCONCLUSIVE | FPA `sample2-*` | Distinguish partial startup from app readiness |
| Preparation / Android separated health | 2026-11-04 18:01:59 and 18:04:33+03:00 | Same source/configuration | API35, 720×1280/240dpi, host OpenGL; ADB native gestures | Same AVD; no app-private profile yet | Boot1, PID592 stable, all required services/real Home present, empty crashes; drawer and Settings operate | PASS, environment preflight only | FPA `sample3-*`, `sample4-*`, `android-drawer-second.png`, `preflight-resumed.log` | First fully available sample followed by check >2 minutes later; no A-ID passed |
| Preparation / Windows profile | 2026-11-04 18:17–18:19+03:00 | `227ecf8`; executable `07e3d879…369c`, kernel `1326d47d…912b`; full hashes in FPA | Win11 26200, Debug 1264×681, dark, Driver | FPA `windows-profile/Roaming/TodoPilot` | Actual VM APPDATA/LOCALAPPDATA both match; Drift, displayed Data profile and on-disk DB agree; synthetic `B6 Today` saved for 2026-11-04 | PASS, preparation only | FPA `windows-readback.json`, runtime tool transcript; PID19636, checkout Debug executable | Current-source fixture for human W01; not native picker/input evidence |
| W01 / Save and editor reopen | Report recorded 2026-11-04 18:49:17+03:00; execution time unreported | Same Windows source/artifact/profile | Human report, dark/100% | Same disposable profile | User reports the scoped Save/reopen test passes, then reports accidentally closing the app | PASS, reported assertions only | Session user reply; FPA `w01-saved-before-cold-start.json` | Resource-kind qualification below; no cold-start result inferred from normal app exit |
| Preparation / human profile confirmation | Report recorded 2026-11-04 18:40:50+03:00; execution time unreported | Same Windows source/artifact above; docs HEAD `fb19a42` | Human report; theme/scale unreported | Same disposable profile suffix from guidance | User explicitly replied “Matched” to the displayed database-path check | PASS, profile check only | Session user reply; FPA `human-w01-file-selection-184050.json` | Human confirmation after automated preparation; no app test inferred |
| W01 / actual Windows picker opens | Report recorded 2026-11-04 18:40:50+03:00; execution time unreported | Same Windows source/artifact above | Human interaction; exact input mix/theme/scale unreported | Same human-confirmed disposable profile | User replied “yes it worked” to the scoped picker/file/title question; picker opened | PASS, reported assertion only | Same human receipt and preceding exact instructions | First human native-picker observation; no theme/scale variants inferred |
| W01 / selected resource added | Same report time | Same source/artifact/profile | Same reported human run | Same disposable profile | Guided `resource.txt` selection/addition succeeded | PASS, file-add assertion only | Same human receipt | Earlier receipt called it a link before kind verification; later readback identifies a managed attachment |
| W01 / dirty title after file selection | Same report time | Same source/artifact/profile | Same reported human run | Same disposable profile | Guided unsaved title survived the picker/file-add step | PASS, reported assertion only | Same human receipt | Does not pass viewer return, caret, Save/reopen or cold restart |
| W01 / real viewer and correct content | Report recorded 2026-11-04 18:46:38+03:00; execution time unreported | Same Windows source/artifact; docs HEAD `fb19a42` | Human report, Notepad, dark, Windows display scale100% | Same human-confirmed disposable profile; current checkout PID19636 verified | User confirms correct fixture content displayed in Notepad | PASS, reported assertion | FPA `human-w01-viewer-return-184638.json`; session user reply | First real-viewer observation for this reported variant |
| W01 / Alt+Tab return | Same report time | Same source/artifact/profile | Physical Alt+Tab, dark/100% | Same isolated window | User confirms returning to Todorbit with Alt+Tab | PASS, reported assertion | Same viewer-return receipt | Does not establish broad shell/keyboard acceptance |
| W01 / dirty title after viewer return | Same report time | Same source/artifact/profile | Same human run, dark/100% | Same disposable profile | User confirms unsaved title preserved and draft remains open/unsaved | PASS, reported assertion | Same viewer-return receipt | Save/reopen/cold restart remain pending |
| W01 / caret visibility after return | Same report time | Same source/artifact/profile | Same human run, dark/100% | Same disposable profile | User confirms text caret visible; no unexpected UI behavior | PASS, visible-caret assertion only | Same viewer-return receipt | Exact focused control was not identified; no W06/W09 acceptance inferred |
| W01 / exact focused control after return | Same report time | Same source/artifact/profile | Same human run, dark/100% | Same disposable profile | Caret visible, but focused control not named | INCONCLUSIVE | Same viewer-return receipt | Do not infer a specific focus target from caret visibility alone |
| W01 / saved title and resource identity | 2026-11-04 18:50:15+03:00 | Same source/artifact, read-only SQLite | Owned app already closed; no native input | Same disposable database | Stored title=`B6 TodayW01 unsaved`; resource ID `6a921743-ccdd-430f-87c3-fb1f97f8737f`, kind=`managed`, label=`resource.txt`,50 bytes, SHA-256 equals original fixture | PASS, persisted-record assertion | FPA `w01-saved-before-cold-start.json`; fixture hash in transcript | New saved data after human actions; correct prior unverified external-link classification |
| W01 / external-link-specific journey | Qualified18:54:34; clarified19:21:52+03:00, 2026-11-04 | Same source/artifact | Prior human run, dark/100% | Same disposable profile | Initially INCONCLUSIVE; user confirms using Attach a copy of a file, consistent with the managed record. No external-file journey ran | NOT TESTED | Saved-record receipt and FPA `human-w01-attachment-cold-192152.json` | Retains initial classification uncertainty and its resolution; external-link variant still required |
| W01 / actual cold process and title | 2026-11-04 18:51:52–18:54:34+03:00 | Original executable/kernel hashes match; no rebuild | New Debug PID30008, Driver read-only title check | Same supplied child APPDATA/LOCALAPPDATA; actual Drift path agrees | Old PID19636 absent before launch; existing binary/profile reopened, Today displays exact saved title | PASS, process/title assertion | FPA `w01-cold-launch.json`, `w01-cold-mcp-actions.json`, `w01-cold-runtime.log` | User's saved normal app close permits real restart; resource GUI/open after restart still pending |
| W01 / attachment presence after cold restart | Report recorded2026-11-04 19:21:52+03:00; execution time unreported | Same source/artifact, cold PID30008 | Human report, preceding dark/100% variant | Same isolated profile | User reports the scoped cold check passes: task/title and resource remain | PASS, reported assertions | FPA `human-w01-attachment-cold-192152.json` | Attachment variant only |
| W01 / attachment kind and original add control | Same report time | Same source/artifact/profile | Same human run | Same isolated profile | User explicitly identifies Attachment and original Attach a copy of a file action; agrees with DB kind=managed | PASS, reported assertion | Same human receipt | Resolves route uncertainty; no product defect |
| W01 / attachment viewer after cold restart | Same report time | Same source/artifact/profile | Same human run | Same isolated profile | User reports scoped synthetic-content/viewer check passes | PASS, reported assertion | Same human receipt | Other resource types/themes/scales not inferred |
| W01 / attachment removal persists | Report/readback recorded2026-11-04 19:25:27+03:00; human execution time unspecified | Same source/artifact/profile | Human, reported dark/100%; read-only corroboration | Same isolated task | User confirms removal survives editor reopen; DB has no resources for that task, saved title unchanged | PASS, scoped assertion | FPA `w01-attachment-removal.json` | Human removal changes profile state; prior presence readback cannot prove absence |
| W01 / original survives attachment removal | Same report/readback time | Same source/artifact/profile | Same human run plus file hash | Same synthetic original under FPA `fixtures` | User confirms original opens with correct content; original SHA-256 remains `964fcd8e…7187` | PASS, scoped assertion | Same removal receipt, full hash retained | Completes reported attachment sequence only; external-link and other theme/scale variants remain |
| Preparation / Android resumed healthy sample | 2026-11-04 18:21:34+03:00 | `227ecf8`; APK hash above, not installed | Same API35 AVD after deliberate stop/build/resume | Retained disposable AVD | Boot1, PID579, required services and Home present; empty crash buffer | INCONCLUSIVE | FPA `resume2-*` | One sample cannot qualify this new boot |
| Preparation / Android resumed separated check | 2026-11-04 18:24:00+03:00 | Same source, APK not installed | Same API35 AVD | Same AVD; no Todorbit private data | Expected stable services; system_server gone, package/input/IME/activity absent; crash confirmed | FAIL, environment preflight | FPA `resume3-*`, `android-failure-details.log` | >2 minutes after previous sample; no install/retry permitted on this failed guest |
| A01-A09,A11-A12 / application execution | 2026-11-04, after resumed preflight failure | Same source; retained APK not installed | No healthy disposable Android device; no physical device connected | None opened | Required Android app/native/IME/launcher/reader execution unavailable | BLOCKED | Failed environment rows above | No A-ID or variant executed |
| A10 / conditional shared Tasks rerun | 2026-11-04 | 417 compared source/assertion/dependency files unchanged | No new app/native fix or shared defect observed | No Android app opened | New shared-dependency rerun is not applicable; retain earlier scoped Tasks evidence without expanding it | NOT TESTED | FPA `reuse.json`; earlier Batch3 Tasks receipt | N/A applies only to triggering a new shared Tasks run, not OEM/ARM64 acceptance |
| A10 / physical OEM and ARM64 | 2026-11-04 | Same source | No disposable physical device connected | None | Physical acceptance requires a real device | BLOCKED | Initial ADB inventory | Emulator evidence cannot pass this variant |

Allowed outcomes: PASS (observed assertion), FAIL (observed mismatch), BLOCKED
(named environment/tool obstacle), NOT TESTED, INCONCLUSIVE. Applicability is
separate: record why an unsupported feature is N/A; do not count it as PASS.
State whether input came from a physical keyboard, tapped Android IME keys,
ADB key events, Flutter Driver or a screen reader. A screenshot alone does not
establish keyboard, focus, announcements, persistence or physical shell behavior.
Add the completed receipt to [the test ledger](TEST_RUN_LEDGER.md).

### Guided testing stopped at the owner's request

The owner requested **“skip the tests and publish the app if any new changes have
been added.”** Further guided/native/device test execution is stopped. The
dark/100% attachment observations above remain scoped passes. The external-link
stage and all other unexecuted W/N/A variants retain NOT TESTED, INCONCLUSIVE or
BLOCKED as recorded; none becomes PASS or N/A because it was skipped. Publication
does not establish app-wide acceptance. See the
[beta12 publication receipt](UI_QUALITY_BETA_12_PUBLICATION.md).

### Last guided substep, retained for later: W01 file selection and return

Use only the checkout Debug app (current PID30008; original PID19636 closed), whose Data
profile ends in `final-platform-acceptance/windows-profile/Roaming/TodoPilot`.
The installed personal app and companion are excluded. If the session is closed,
`python .buildlog/verify/final-platform-acceptance/session.py windows` relaunches
the same isolated profile; record the new PID and reconfirm the displayed path.

Completed human stage: user confirmed the profile matched, then reported success
to the scoped instructions to append ` W01 unsaved`, use Resources > Link file,
select the synthetic fixture in the Windows picker, and check file addition/title
preservation. The next report confirms correct Notepad content, physical Alt+Tab
return, preserved unsaved title and a visible caret, with no unexpected behavior,
in dark theme at100% Windows display scale. The focused control was not named.
User then reports Save/editor-reopen passed and the app was closed accidentally.
Readback confirms the saved title is `B6 TodayW01 unsaved` and the resource is a
managed **Attachment**. Earlier wording called this a link before checking its
kind. User has now confirmed the original action was **Attach a copy of a file**;
the managed kind is correct. The external-link variant is NOT TESTED. No
application defect is indicated.

The old test process was absent; the exact existing Debug binary/profile has
been cold-started as PID30008. User confirms title/resource presence, displayed
Attachment kind and viewer contents after cold restart. User also confirms
removal persists after editor reopen and the original opens correctly; readback
shows no remaining task resources and an unchanged original-file hash. The
reported dark/100% attachment sequence is recorded. Next is the external-link
variant in the same isolated window:

1. Append ` W01 link draft` to the task title and leave it unsaved.
2. In Resources, hover the document icon and confirm tooltip **Link an existing
   file**, then choose the same original `resource.txt` through the Windows picker:
   `D:\AI_Projects\life_manager\.buildlog\verify\final-platform-acceptance\fixtures\resource.txt`.
3. Confirm the row says **External file**. If it says Attachment, stop and report
   that before further actions. Otherwise open it, confirm synthetic content,
   Alt+Tab back and verify the new unsaved title suffix remains.
4. Report displayed type, viewer content/result and retained draft suffix. Keep
   the draft unsaved; external-link Save/reopen/cold checks follow the observation.

Expected: an external-file resource with a working viewer and preserved dirty
title. The attachment and external-link routes remain separate observations.
Only the reported dark/100% attachment sequence is covered so far; no whole W01 pass.

Every W01-W11 and N01-N08 group still has open native variants. Automated execution
is **BLOCKED** by native Computer Use; human assertions other than those recorded
above remain **NOT TESTED**. In particular, no folder/Cancel/Escape (W02), missing
target (W03), settings OS save/import (W04), native draft/focus return (W05),
physical input/reader (W06-W09), OS scaling/monitors (W10-W11), or actual widget
display/input/preview/menu/shell/persistence (N01-N08) is passed. The exact actions
and expected results remain in the original W/N tables below. Sign-in/Explorer
recovery needs a disposable Windows user/VM; no such environment was established.

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
