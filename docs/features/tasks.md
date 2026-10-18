# Tasks

The task-row Play action offers Start Task (sets In Progress without recording
time), End Work (sets On Hold), and Start Focus Session (starts the existing
single active actual-work timer). The focus dialog and sidebar mini timer show
seconds; pause excludes paused time, and stop leaves task completion unchanged.

Schema v17 stores curated built-in icon keys for tasks and recurring series,
categories, and projects. Schema v18 stores task checklist items independently
of true child tasks. Checklists can be edited, checked, removed, and reordered;
they never complete the parent task. Child tasks have their own metadata and
completion state. One level of nesting is supported. The parent row shows
checklist and child-task progress and can expand or collapse its children.

A task requires a nonblank title. Optional category, project, notes, status, priority, scheduled day and deadline are foundation fields. Projects belong to one category; assigning a project also determines its category. Unassigned tasks belong to Inbox. Completion records a UTC timestamp and can be reopened. Tasks can be archived or moved to recoverable Trash. Permanent deletion requires explicit confirmation and is blocked while linked records would be lost.

Schema v15 stores copied attachments (up to 16 MB each), external file/folder
references, and URL links per task. Copied bytes travel with SQLite backups;
external content does not. Missing external paths remain visible as unavailable.
Tags, subtasks, and richer task history remain future work. Validate
project/category consistency, preserve timestamps, and test
create/edit/complete/reopen/persistence.

Schema v5 implements prerequisites and persistent task sequences. Task details
can add or remove prerequisites from any project. Cycles are rejected without
losing existing links. A blocked indicator means at least one prerequisite is
not completed; it does not change the task's primary status or complete it
automatically. The Task sequences sidebar action creates, renames, deletes,
and orders sequences using accessible up/down controls. A task can belong to
one sequence; deleting a sequence keeps its tasks. Sequence order is not a
prerequisite relationship. Sequence tasks can be passed to Smart Reschedule in
their saved order.

Schema v7 stores recurring series as linked versions. Task details expose
"This and future occurrences" and "Entire series (pending occurrences)".
Both preview preserved, excluded, created, and colliding occurrences before
Apply. Completed work, sessions, dependencies, individual edits, reschedules,
and scheduling history keep their original task IDs. A compatible untouched
occurrence can be combined into the new version; every other same-day collision
requires Keep Both or Skip New. The operation checks revisions and links again
in one transaction and records its decisions. Task recurrence is date-only;
work-session times remain independent.
