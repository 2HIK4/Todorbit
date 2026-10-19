# Design

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
