# Design

Use a compact Windows 11 inspired workspace: a 230 px navigation rail, a flexible content area, and a 360 px task details panel when space permits. Narrow windows switch details to a dialog.

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
