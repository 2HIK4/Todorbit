# Todorbit Design System

## The Today workspace

Todorbit uses neutral surfaces and a restrained teal accent. The date anchors
Today, New task is the primary action, and a divided list gives task titles
room. Calendar commitments stay visible alongside the work they affect.
Windows keeps navigation and a resizable editor. Android keeps its own
navigation and full-screen editor. Both use the same section typography,
surface roles and row rhythm.

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

## Rollout and checks

Protect editor drafts on navigation, keep planned dates and deadlines separate,
and let existing controllers own persistence and scheduling. Inspect real
Flutter renders where practical alongside targeted behavior tests. Record
Windows and Android coverage separately, including narrow layouts and 150%
text. Use the [testing policy](TESTING.md) for evidence.

Next batches are Inbox and task lists, followed by Calendar and event editing.
Focus, Habits and Goals come next, then Settings, sync feedback and native
widgets. Review each batch in light and dark before expanding.
