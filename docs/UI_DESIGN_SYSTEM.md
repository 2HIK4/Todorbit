# Todorbit Design System

## The Today workspace

Todorbit uses neutral surfaces and a restrained teal accent. The date anchors
Today, New task is the primary action, and a divided list gives task titles
room. Calendar commitments stay visible alongside the work they affect.
Windows shows navigation and a resizable editor when they fit beside the
workspace. Below that breakpoint, an open task occupies the workspace and
keeps its existing editor instance. Closing it reveals navigation again.
Android keeps its own navigation and full-screen editor. Both use shared
section typography, surface roles and row rhythm.

Beta 26 supplied shared form controls and task rows. Today repeated task
counts and each row had a card border. Desktop showed fixed appointments by
count, while Android showed their titles and times. The new hierarchy uses
proximity, compact metadata and headings to give tasks and appointments room.

Things illustrates why planning and deadlines need separate labels. Todoist
shows how Today can answer one question across projects. Linear's display
preferences show how metadata can stay configurable without crowding the list.
Todorbit retains its own schedule, timer and navigation contracts.
[Things](https://culturedcode.com/things/support/articles/2803579/) ·
[Todoist](https://www.todoist.com/help/todoist/get-started/plan-your-day-with-the-today-view-UVUXaiSs) ·
[Linear](https://linear.app/docs/display-options)

## Tokens and controls

- Default light uses #F6F8F9 canvas, #FFFFFF surface and #006A66 accent.
  Dark uses #15191C canvas, #20262A surface and #70DACE accent.
  ColorScheme assigns foregrounds, surfaces and interaction states.
  TodorbitThemeTokens owns status and priority roles.
- Use ThemeData typography with the platform font. Today uses a 32 sp page
  title, 15 sp section headings and 14–15 sp row content. Use the 4, 8, 12,
  16 and 24 dp AppSpacing rhythm and AppLayout breakpoints and touch sizes.
- Start with themed Material buttons, icon buttons, inputs, menus and surfaces.
  Use AnchoredSelectField for bounded selections, AppModalShell and shared
  action bars for adaptive modals, and StatusNotice for feedback.
  AppPageHeading keeps the primary action next to the page title when space
  allows. AppSectionHeading and AppEmptyState support grouped lists.
- AppTaskRow accepts task data, derived progress and action callbacks. The owner
  supplies timer state, opens editors and persists completion. Keep completion
  and opening independent. Use SettingsSection for expandable forms. The task
  editor uses its divider variant and shares date controls and save behavior
  between Create and Edit.
- Use AppMotion for transitions and honor system and app reduced-motion settings.
  Keep focus visible and selection distinguishable. Check contrast on canvas,
  surfaces and selected states. Keep Android touch targets at 48 dp. Check
  large text and long titles against actual available layout space.
  [NN/g](https://www.nngroup.com/articles/visual-hierarchy-ux-definition/) ·
  [Flutter](https://docs.flutter.dev/ui/adaptive-responsive/best-practices) ·
  [WCAG](https://www.w3.org/TR/WCAG22/)

## Batch 1 presentation rules

- Limit desktop Today to an 800 dp content column. Keep calendar commitments
  and planned tasks in separate groups. Only reserve space for schedule
  shortcuts when an actionable summary exists.
- Use localized, abbreviated dates with the year. Task rows and details use
  Planned and Due. Forms label the corresponding inputs Scheduled day and
  Deadline. Keep their clear actions distinct. Place Repeat beside the date
  controls during Create. Edit groups recurring occurrence actions together.
  Let the title field wrap while preserving a single-line title value.
- In Edit, identify resources and checklist or subtask actions that save
  immediately. Keep draft fields under the form's Save changes action and
  dedicated saves beside their own fields.
- Allow Android task titles up to four lines. The details view and actions
  sheet show the complete title. Keep text labels for priority and identify
  the task timer with the action it performs. When phone width and text scale
  make navigation captions wrap, keep full destination names in semantics and
  tooltips. Give the app-bar title its own line and keep actions reachable.
- Use text for frequently used actions where it fits. Icon actions need an
  accessible name. Keep a hover tooltip for truncated sidebar destinations
  and retain the full name for assistive technology.

## Batch 2 task-list presentation

- Inbox, All tasks, date and status views, categories, projects and saved
  views share the task list presentation. Use the bounded Today column on
  Windows and a scrollable list with the existing app bar on Android.
- Use shared sort labels and show a specific empty message for search or
  filter results. In scoped views, give events their own heading and keep
  task completion controls in the task section.
- Keep recurring series as expandable rows. Place the subtask disclosure
  below its parent so it does not take space from the title. Show category
  and project metadata where it adds context. Keep the existing density
  preference and separate task opening from completion.
- Move Android's New task action into the toolbar when compact navigation
  is active. Where the floating button is used, reserve trailing space so
  the last row can scroll above it. Check the editor's final explanatory
  text and actions against its fixed Save bar at 320 dp and 150% text.

## Batch 3 calendar and event editing

- Use shared display date and time formatting. Show the year in period
  headings or editor date values. Preserve the preferred first weekday,
  saved view, item filters and date-only keys. Android follows its clock
  setting and Windows retains the 24-hour timeline.
- Use today and selection treatments independently. Show date-only items
  above the time grid. Keep planned tasks, deadlines, all-day events and
  work sessions distinguishable by label or icon and accessible name.
- Keep title and start time visible where overlap lanes permit. Provide the
  full title and range through hover and semantics. Keep continuation labels
  in view while scrolling and position drag time badges from the proposal.
  Preserve the engine's geometry, resize hit areas and commit boundaries.
- Keep Android date navigation and grouped agenda in the touch shell.
  Verify the final agenda row and all actions above the navigation bar.
- Use the shared modal shell, date/time buttons, disclosure sections and
  action bar for events. Keep editable titles wrapped with a single-line
  value. Keep Close and Save reachable with an IME. The Windows side panel
  uses a focused presentation when narrow without remounting the draft.

## Batch 4 Focus, Habits and Goals

- Keep the Focus clock and primary action visible before mode settings at
  compact widths. Use tabular digits and a text state for running, paused
  and break intervals. Use labeled controls and retain the separate timer
  review path. Keep ticking local to the Focus and compact timer widgets.
- Use the bounded content column for Habits and Goals. Keep habit date
  arrows adjacent and connect check-in to the selected date. Present the
  result, units and streaks as text. Keep goal completion separate from
  measured progress and show linked contributions beneath the total.
- Keep New habit and New goal in their own toolbars. Android retains New
  task in Workspace actions, keeping the agenda and list actions clear.
  Compact goals group linking, milestones and history in More actions.
- Use the keyboard-aware modal shell, scrollable form and fixed action bar
  for habit and goal editing. Verify Create/Edit with a live draft at
  320 dp and 150% text and with simulated keyboard insets.

## Batch 5 Settings, Sync and native widgets

- Keep Settings category navigation next to content at regular desktop
  widths. Switch to a labeled section picker when available width and
  text scale leave insufficient reading space. Use divider disclosure
  sections on Android and keep advanced options available on demand.
- Show the current Sync state, last confirmed success and pending change
  count together. Announce status changes and label busy progress.
  Keep recovery explanations and conflict decisions tied to their owners.
- Use normal emphasis for archive counts and error emphasis for destructive
  actions. Shared Files names and metadata wrap at phone widths. Make
  category-empty feedback distinct from an empty library.
- Match fallback native widget roles to the Flutter defaults. Published
  palettes take precedence. Android measures rows using the pixel rounding
  of the native layout and preserves access to the heading and date
  controls in compact Calendar widgets.

## Cross-surface presentation

- Let search headings wrap on narrow screens. Keep the short query label
  and scope hint above filter help so they remain visible when the keyboard opens.
- Reset clears active filters, including criteria carried in from an existing
  view. Preserve the view name and icon and commit changes on explicit save.
- Keep the report help action with its heading. Format the displayed period
  and day labels with the shared local date formatter.
- Use the compact dialog edge inset for portable settings. Keep categories
  scrollable and import, export, confirmation and dismissal reachable.
- Announce cancelled timeline entries and maintain contrast on their rendered
  cards. Keep compact Android widget date targets at 48 dp. Use shorter
  empty messages before they crowd out the footer at enlarged text.

## Customization and compatibility

Settings → Appearance retains System, Light and Dark, two editable palettes,
HEX inputs, built-ins, named palettes and version-1 JSON import/export.
Custom palettes can be saved, applied to either appearance, duplicated, renamed
or deleted. Reset both palettes to return to Todorbit defaults while retaining
saved presets and layout preferences. Existing explicit colors retain their
stored values. Review low-contrast colors in the preview before saving.

Text scale, density, motion, sidebar order, visibility and width, opening view,
calendar view and task detail presentation use existing preference owners.
Preferred Windows editor width is device-local. The visible width is clamped
to the window, and resizing leaves the editor state mounted.
Windows and Android widget settings have independent owners.

For a contributed palette, start with a version-1 export, edit its nine opaque
HEX roles for each mode, check contrast and import it through Appearance.
Flutter contributors should use the existing color, spacing and component
contracts before extending them. Keep file formats and storage keys compatible.

## Android launch screen

Use the existing orbit geometry on the neutral launch background. Keep the
art inside the Android 12 circular safe area in both system themes and use
the same visual for older supported Android versions. Verify the actual
starting window and its first-frame handoff on a Release APK.

## Rollout and checks

Protect editor drafts on navigation, keep planned dates and deadlines separate,
and let existing controllers own persistence and scheduling. Inspect real
Flutter renders where practical alongside targeted behavior tests. Record
Windows and Android coverage separately, including narrow layouts and 150%
text. Use the [testing policy](TESTING.md) for evidence.

See the [final integration audit](UI_REDESIGN_FINAL_ACCEPTANCE.md) for the
67-category review, render inventory and remaining release acceptance gates.
