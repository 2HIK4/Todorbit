# Design

## Native widget control polish (2026-10-21)

The Edit Task date field is one painted surface containing a native borderless
text box and two 32 px icon actions. The actions keep native button focus and
keyboard activation, but paint no competing outlines. The field owns its
rounded border and focus ring. Typed ISO dates, calendar selection, and clear
remain independent for Scheduled day and Deadline.

Choice controls remain themed WinForms buttons and ToolStrip menus. Their arrow
is now painted at a fixed trailing inset; the label has its own ellipsis width.
Clearing the button's parent color behind its rounded shape removes square
corner artifacts. Quick Add uses the same rounded border and a matching form
region. The editor has 16 px after its last field; its fixed footer no longer
draws an unnecessary divider. Default client height is 570 px.

Shared native tokens in `WidgetEditorStyle` define the corner, field height,
date action width, palette blend, and surface border. Date action width and
glyph geometry scale with control DPI; physical DPI rendering still needs
manual acceptance. The selective refactor
keeps native text editing, popup keyboard behavior, the painted Explorer host,
IPC, and repository writes. It avoids a broader widget rewrite because the
defects were in the transient editor controls and their parent painting.

This applies desktop principles from `apple-design` `accessibility.md` (input
methods), `text-fields.md` (labels and spacing), `buttons.md` (press state),
and `entering-data.md` (clear choices), translated to Windows conventions.

## Native widget redesign (2026-10-21)

The Explorer-attached surface remains a compact task companion. Its header now
uses a simple app-window and outward-arrow symbol for Open Todorbit. A slim
task-list scroll cue replaces the text range that crowded the last row at the
minimum widget height. Empty copy describes the selected view. Selected tabs
choose readable text from the active accent, including custom palettes.

The native Edit Task form uses the same background, surface, accent, text,
border, and error roles as the Flutter theme JSON. It groups Task details,
Schedule, Organization, and Status and priority. Related fields share columns
at regular widths and stack at compact widths. The form has a natural 570 px
client height, a scrollable content area for small screens, and fixed actions.
Native text editing remains available for selection and paste. Choice menus,
date entry, a themed calendar, focus rings, and buttons use the same surface
and border treatments. Save remains primary; Cancel and Open full details are
secondary. The date inputs retain separate planned-day and deadline values.

The contextual menu keeps Windows ToolStrip keyboard and popup behavior. Its
selection and check colors blend opaque palette tokens, and the close action
has its own separator. These choices follow `apple-design` guidance on
hierarchy (`layout.md`), legible text (`typography.md`), grouped forms
(`entering-data.md`), accessible input (`accessibility.md`), and short contextual
menus (`context-menus.md`), translated to Windows controls and conventions.

Offscreen WinForms renders cover dark, light, narrow, and date-calendar states.
They do not establish Explorer composition, real DWM caption colors, physical
input, menu placement, or DPI behavior; those remain manual acceptance checks.

## Feedback round 4, part 2 (2026-10-20)

The checklist row gives its text the flexible column. A separate checkbox
retains a consistent position, while a single overflow menu holds edit,
reorder, and removal. Long text starts at two selectable lines and has an
explicit Show more/Show less control. Thin separators distinguish dense lists
without surrounding each item with a card. The same checklist dialog is used
for saved and draft edits; its width follows the viewport and typing wraps
within a multiline field.

Task scheduling keeps planned day distinct from deadline. The two controls
share a row when the editor is wide enough and stack below 470 px; each has a
visible label and its own clear action. Resource actions use familiar attach,
file, folder, and link icons with short labels. An empty Resources section
shows the actions directly, while a file drag supplies transient target
feedback. Draft subtasks have one overflow menu and light separators.

The task-list Info action describes the actual filter, including the difference
between planned dates and deadlines. Settings uses six sections and keeps the
existing controls in their established dialogs. A compact window uses a
section picker instead of a permanent category rail. Theme mode lives in
Appearance & Themes; widget opacity, layout lock, and startup can also be
changed in Settings while the context menu retains direct access.

The native widget keeps its Explorer child host. Its context menu uses the
current semantic palette through a Windows ToolStrip renderer, with native
menu dismissal and keyboard behavior. The update-time footer is removed and
the task area grows into the freed space. The native task editor is shorter,
resizable, DPI aware, and uses matching palette colors for its controls.

These choices apply Apple Design Skill guidance from `layout.md` (Visual
hierarchy), `typography.md` (Ensuring legibility), `accessibility.md`
(Mobility), `lists-and-tables.md` (Best practices), `icons.md` (Best practices),
`popovers.md` (Best practices), and `settings.md` (Desktop). Windows controls
and shortcuts remain native to this app.

## Feedback round 3 (2026-10-19)

The Windows title bar, lavender identity, and light/dark themes stay native to
the app. Calendar entries now use compact tinted blocks, a restrained accent
edge, and text for type and status. Cancelled titles are struck through; a
secondary status and accessible tooltip remain. A scheduled subtask shows its
parent as the primary line and its own title underneath.

Month cells use measured height and text scale to decide how many complete
entries fit. The remaining count opens a day preview, as does clicking empty
day space in Month or Week. The preview keeps the current calendar layout,
offers details and quick creation, and has an explicit Day View action. Empty
calendar areas use a Windows-style right-click creation menu; event and task
entries keep their own click target.

At the Round 3 checkpoint, task creation began without a date. Round 4 Part 1
changed the default planned day to Today. Anytime collects tasks with neither a
planned date nor a deadline. The task panel leads with title, notes, and
scheduling; organization, checklists, subtasks, and resources follow; rare
settings live in labeled advanced groups. The scrollable form clears the fixed
save action. Category and project selectors provide creation in context while
keeping the unsaved task draft.

Saved View creation labels the name, filters, sort, and save action directly
in Advanced Search. Zero matches are valid. The event color menu is anchored
to its field and offers eight distinct named colors. All surfaces retain
keyboard focus, Escape dismissal, and semantic text/icon cues where applicable.

Use a compact Windows 11 inspired workspace: a 230 px navigation rail, a flexible content area, and a 360 px task details panel when space permits. Narrow windows switch details to a dialog.

## Feedback round 2 visual audit and rules (2026-10-19)

The isolated Release baseline was inspected at 1266×713 in dark mode. Empty
Today had a small planned-task chip and a generic empty message; the new-task
panel showed title, notes, resource guidance, status, priority, category, and
project before the scheduled day. The fixed Save button stayed visible, but
the date was below the first viewport. Empty Calendar displayed a dense toolbar
and seven equally styled columns without an obvious current-day marker. The
rest of the feature screens still require populated Release UI review. The
light Today/task-row state was also inspected after the refinement and retained
readable foregrounds, outlines, selection, and native caption colors.

Keep one restrained indigo/lavender accent across both themes. Shared theme
styles now set a 26 px page heading, 600-weight headings, secondary text color,
40 px minimum button height, 10 px button and field corners, subtle card and
dialog surfaces, semantic outlines, and a 2 px focused field border. Use the
accent for selection, active work, and primary actions; ordinary metadata uses
on-surface-variant. Keep 8/12/16/20/24 px spacing steps where practical.

The task editor puts title, notes, scheduled day, and deadline first, followed
by resources/checklist for existing tasks and category/project. Status/priority
and estimates/schedule protection are labeled expandable groups. Existing
nondefault values open their group on edit. Recurrence and progressive plans
stay distinct from checklist items. The editor scrolls past the fixed Save
action so lower controls remain reachable at short window heights.

Today uses real task, event, and planned-session counts with calendar links;
the task list remains the main work surface. The focus dialog gives the live
clock a calm surface and explicit running, paused, stopped, and review states,
with recorded total directly below. Its width and height respect the viewport.
The sidebar mini timer uses a distinct compact surface. Calendar week highlights
today; month marks the selected day and uses icons plus truncated tooltips to
separate events, sessions, and tasks. Smart Reschedule and Advanced Search
dialogs also clamp their dimensions to the available window.

No database, domain, native frame, or widget behavior changes are part of this
refinement. Other feature screens inherit the shared theme but still need
screen-specific visual acceptance, especially populated views and compact DPI
layouts. Automated widget tests confirm interaction, not visual quality.

Use Material 3, rounded 10–14 px surfaces, restrained indigo accent, 8 px spacing increments, and clear hover/focus/selected states. Light and dark themes share semantic colors. Text and icons communicate status together. Destructive actions require confirmation. Keyboard shortcuts: `Ctrl+N` creates a task; `Ctrl+K` opens search when implemented.

Reusable controls include navigation items, task rows, empty states, section headings, status chips, and editing fields. Every visible primary action must work or say it is unavailable.

The native widget uses the same restrained indigo semantic palette through a
shared System/Light/Dark preference. Its compact header separates the draggable
title region from vector icon buttons, followed by explicit Today, Inbox, All
Tasks, and Upcoming selectors. Task rows reserve distinct checkbox and title
targets. The bottom Quick Add field exposes its destination and uses a focused
accent outline. At 340x420 minimum size, labels and controls remain explicit;
larger sizes add task capacity rather than decoration.

Because Explorer-hosted child windows cannot reliably activate for keyboard
input, any widget text editor is a short-lived Life Manager-owned top-level
surface positioned over or near the native widget. Persistent WinForms child
controls, focus-stealing timers, keyboard hooks, and synthetic input are not
part of the design.
