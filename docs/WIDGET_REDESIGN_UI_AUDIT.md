# Widget redesign and shared application UI audit

Date: 2026-10-26. This records implemented Flutter findings alongside the
native widget redesign. It does not treat source review or widget tests as
physical Windows acceptance.

## Shared standards

- `SettingsSection` gives an expandable group one rounded boundary, a strong
  heading, secondary description, and related content with consistent 16 px
  padding. Expansion keeps field drafts alive. `SettingsHelperText` gives
  supplemental copy the theme's secondary text role and a readable line height.
- Setting labels and values use the available field width. Related commands
  wrap when they cannot fit beside their label. Dialog content scrolls while
  actions remain available.
- Flutter tooltips use a 600 ms initial delay, 100 ms exit delay, palette-derived
  surface/text/border, 8 px corners and 12/8 px internal padding.
- Color editing uses a visible swatch, wheel and validated HEX field. The
  scrollable picker owns its text controller through route dismissal.
- Keyboard menu traversal skips disabled options and scrolls the focused item
  into view. Existing checked choices, anchoring and native Flutter focus
  behavior remain in the shared select.

These follow Microsoft's [settings grouping guidance](https://learn.microsoft.com/en-us/windows/apps/design/app-settings/guidelines-for-app-settings)
and [tooltip guidance](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/tooltips).
The 600 ms delay is a Todorbit choice within the requested range;
Microsoft's [Win32 tooltip guidance](https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-tooltips-and-infotips)
describes a 500 ms default initial delay.

## Implemented findings

| Location/component | Original problem and root cause | Severity | Fix applied | Verification |
| --- | --- | --- | --- | --- |
| Widget editor and backup expanders | Borderless expansion headings and independently padded children did not communicate group boundaries. | Medium | Reusable `SettingsSection`; secondary descriptions and consistent expanded content padding. Backup actions, retention and explanation groups use it. | Section draft-retention and containment widget test at 360×600, 1.5× text, dark/light. Root integration results recorded below. |
| Application tooltips | Main `ThemeData` supplied no tooltip treatment or hover timing, leaving Material defaults disconnected from the desktop palette. | Medium | Shared `desktopTooltipTheme` applied by the real application theme. | Mouse-hover tests verify no hint at 500 ms, appearance after the delay, palette text and dismissal in both themes. |
| Shared anchored selects | Arrow handling requested focus on the immediately adjacent item even if that item was disabled; long-menu traversal did not explicitly reveal the focus target. | Medium | Skip disabled entries, focus the first available opening choice, reveal traversed choices. | Keyboard selection past a disabled item; existing anchor, viewport and keyboard tests. |
| Theme opening-screen and calendar defaults | Fixed 160/135 px trailing fields competed with labels in `ListTile`, especially with larger text. | Medium | Full-width labeled selects with shared spacing; palette mode switches to a select at constrained widths. | Narrow dark/light tests open the full-width field and select Calendar. |
| Theme color editor | Fixed-height picker gave wheel, HEX input and helper text competing space. The caller disposed its controller before the dialog's closing animation completed. | High | Shared scrollable `ColorPickerDialog` owns its controller, swatch and validated HEX; stable Cancel/Reset/Confirm actions. | 360×600, 1.5× text test rejects invalid HEX, accepts `#12AB34`, closes with no controller exception. |
| Theme and hotkey name prompts | Callers disposed text controllers when `showDialog` completed, while outgoing routes could still render. | High | Shared stateful `TextPromptDialog` disposes only with its route; keyboard submission remains available. | Text prompt keyboard submit/dismiss test; preset business logic unchanged. |
| Hotkey settings | Preset field shared one inflexible row with four icon commands; shortcut rows reserved a trailing control group before laying out long labels. | Medium | Preset commands wrap below the field; binding commands follow the shortcut label and secondary group text. | Narrow dark/light rendering and search interaction at 1.5× text. |
| Task preferences and Notifications | Unscrollable content columns could push the lower controls beyond short/high-text-scale dialogs. | High | Scrollable AlertDialog content; notification explanations use secondary helper styling. | Narrow tests interact with the checklist select, verify the controller receives Compact, and reach notification actions/unavailable explanation. Existing notification opt-in test still exercises persistence and companion launch. |
| Locked application shell | Centered non-scrollable column combined PIN entry, Unlock and a long recovery paragraph. It had no way to reach content when height/text scaling exceeded the viewport. | High | Padded scrollable lock content, secondary recovery copy; privacy state and verification are untouched. | Dark/light 360×480, 1.5× test enters a PIN, scrolls to Unlock and verifies the manager stays locked. |
| Backup explanations | Retention and storage explanations used ordinary body foreground and inconsistent extra padding inside expanders. | Low | Shared section/helper controls, with the same text and backup actions. | Shared component tests and existing backup/cloud regressions in integration; no account, credentials or cloud configuration changes. |
| Embedded backup panel / expandable groups | Integration exposed duplicate horizontal padding, an overflowing fixed header/content column, and expansion booleans being read as nested scroll offsets. | High | Embedded panel owns its padding; controls and history use one scroll region; section descendants have an isolated PageStorage bucket. | Existing 440px dark/light backup tests create a backup and verify success without exceptions. |

## Application coverage and boundaries

The source pass inspected workspace/sidebar and task-detail breakpoints, Task
Editor, Calendar Day/Week/Month, Event/Session forms and the earlier calendar
audit, Habits, Goals/progress history, Reports, Templates, focus/time tracking,
Archive/Trash, advanced search, theme/settings hub, hotkeys, task preferences,
privacy, notifications, backup/settings transfer and update controls. It reused
the existing wrapping actions, constrained dialogs and anchored select rather
than replacing stable feature layouts. The shared tooltip and select changes
apply to their existing callers throughout these features.

Unchanged feature flows retain their existing regression tests. Source review
alone does not establish populated visual acceptance, keyboard/screen-reader
behavior or physical display scaling for each screen. Native calendar, task,
dragging, resize, text contrast and menu changes are implemented and verified
by the separate native workstream; its exact evidence belongs in the final
implementation record.

## Verification record

Focused command:

```powershell
flutter test --no-pub test/settings_ui_quality_test.dart test/anchored_select_field_test.dart test/notification_dialog_test.dart test/theme_customization_test.dart
```

Early runs passed the tooltip, section retention, disabled-choice keyboard,
HEX picker and existing notification/theme/select cases. New test harness
failures were corrected: a label-only scroll did not reveal the complete field,
and an assertion originally checked the previous dialog after replacing it.
Tests now interact with complete field hit targets and assert the resulting
preference value. The root integration run records the final pass/failure count,
analysis and build results with the overall implementation report.

No physical DPI, screen-reader, Release screenshot, native mouse input,
Explorer composition, multi-monitor or Win+D claim is made by these Flutter
tests. No personal profile was opened or modified for them.
