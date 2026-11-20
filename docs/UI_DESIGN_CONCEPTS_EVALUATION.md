# Todorbit Visual Design Concepts — Evaluation & Design Iterations

**Authored:** 2026-11-20
**Branch:** `design-foundation-docs`
**Prototypes:**
- Concept A (Iteration 1): [`docs/design-concepts/concept-a-refined-minimalist.html`](design-concepts/concept-a-refined-minimalist.html)
- Concept B (Iteration 1): [`docs/design-concepts/concept-b-modern-workspace.html`](design-concepts/concept-b-modern-workspace.html)
- Concept C v1 (Iteration 2 Baseline): [`docs/design-concepts/concept-c-adaptive-workspace.v1.html`](design-concepts/concept-c-adaptive-workspace.v1.html)
- **Concept C Refined (Final UX Refinement):** [`docs/design-concepts/concept-c-adaptive-workspace.html`](design-concepts/concept-c-adaptive-workspace.html)

All prototypes are standalone, offline-capable HTML/CSS/JS applications that can be opened in any web browser.

---

## 1. Product Owner Review of Iteration 1 (Concepts A & B)

**Verdict:** Neither Concept A nor Concept B was approved.

### Critical Deficiencies Identified:
1. **Generic Appearance:** Neither concept established a distinctive Todorbit identity. Concept A resembled generic note apps; Concept B resembled developer issue trackers.
2. **Space Utilization Trade-offs:** Concept A was clean but sparse and underutilized desktop width. Concept B was over-dense, clipping long task titles and producing cognitive fatigue.
3. **Small Metadata Reliance:** Both concepts relied heavily on tiny, hard-to-read metadata badges.
4. **Task Editor vs. Property Inspector:** Both detail side-panels felt like database inspectors rather than focused, enjoyable task editing workspaces.
5. **Fixed Viewport Bias:** Neither prototype demonstrated adaptive responsiveness across varied desktop window widths (1000×800) or Android mobile viewports (390×844).
6. **Incomplete Product IA:** The navigation models did not clearly accommodate Todorbit's full feature set (Habits, Goals, Focus Sessions, Reports, Backups, Settings).

---

## 2. Concept Comparison Matrix

| Attribute | Concept A: Refined Minimalist | Concept B: Modern Productivity | Concept C (Refined Final UX) |
|---|---|---|---|
| **Visual Identity** | Plain minimalist card list, generic blue (`#3B6FE0`). | High-density developer grid, dark indigo (`#6366F1`) + cyan. | **Celestial Twilight / Luminous Slate:** bespoke orbital brand identity, twilight obsidian dark theme (`#0D0E14` / `#151722`), high-contrast luminous light theme (`#F5F6FA` / `#FFFFFF`), violet brand accent (`#7C3AED`). |
| **Task Presentation** | Vertical cards with colored left borders. | Strict multi-column tabular grid. | **Adaptive Task Rows:** 52 dp balanced default (or 40 dp compact toggle). Geometric priority shapes matching Todorbit domain model (▲ High, ■ Med, ◆ Low, None). |
| **Title Readability & Wrapping** | Single-line ellipsis truncation. | Severe tabular truncation. | **Exceptional 2-Line Wrapping:** Dedicated primary line with generous font scaling (14px–17px); handles long titles gracefully without truncation or layout overflow. |
| **Domain Invariant Clarity** | Planned and Due dates rendered similarly. | Single "Due" date column. | **Strict Todorbit separation:** Labeled Planned Date (🗓️ intentional schedule in warm amber) vs. Hard Deadline (⏰ commitment gate in coral red). |
| **Today View Comprehensiveness** | Tasks only. | Tasks only. | **Unified Today View:** Integrated **Active Focus Session Banner** (running timer with pause/resume) + **Fixed Events Timeline** (e.g. lectures, dentist appointment) + Planned Tasks. |
| **Task Details Workspace** | Form fields in cards; property inspector feel. | Tabbed metadata grid with tiny text. | **Unified Task Workspace:** Clean non-nested form, auto-wrapping title textarea, direct dual-date pickers, inline subtask completion, and contextual progressive disclosure accordions. |
| **Data Realism** | Generic developer placeholders. | Generic developer placeholders. | **Realistic Everyday Data:** University assignments, thesis proposal, dentist appointments, grocery & pharmacy errands, and recurring habits. |
| **Responsive & Text Scaling** | Fixed viewport assumption. | Fixed viewport table (broken on mobile). | **Arbitrary Viewports & Text Scaling:** Previews for 1440 Wide, 1100 Med, 820 Narrow Desktop, and 390 Mobile; includes live **Text Scale Factor** controls (100%, 125%, 150%) and **Empty State** toggle. |
| **Information Architecture** | Basic subset of views. | Basic subset of views. | **Complete Todorbit IA:** Schedule (Today, Calendar, Upcoming & Overdue, All Tasks), Productivity (Focus Sessions, Habits, Goals, Reports), Projects & Categories, Preferences, and Sync status. |

---

## 3. Systematic Resolution of the 12 Final UX Refinement Objectives

### Objective 1: Improve Readability & Contrast
- Base font size set to a comfortable `14px`, task titles to `14.5px–15px` weight 600, section headings to `12px` uppercase.
- Verified WCAG AA contrast (>4.5:1) across both Dark (`#F3F5FC` on `#151722`) and Light (`#111424` on `#FFFFFF`) themes.
- Metadata text uses legible `12.5px` with distinct semantic color badges, eliminating unreadable micro-labels.

### Objective 2: Reduce Visual Clutter
- Removed excessive nested card borders, redundant pills, and multi-colored pill soup.
- Tasks display only essential metadata: Planned date / Deadline, Project dot + name, and Subtask/Checklist progress counter.
- Background surfaces simplified to unified layers: Canvas (`--bg-app`) and Card Surface (`--bg-surface`).

### Objective 3: Fix Title Truncation
- Task titles now use a 2-line flexible clamp (`-webkit-line-clamp: 2` with `line-height: 1.4` and `word-break: break-word`) instead of cutting off with a 1-line ellipsis.
- Extremely long academic and professional task titles (e.g. *"Draft and submit comprehensive thesis proposal on distributed consensus protocols to academic advisory committee"*) render cleanly and legibly without clipping or breaking row alignment.

### Objective 4: Improve Task-Details Editor
- Eliminated card-inside-a-card nesting. Replaced with clean, cohesive input cells with subtle borders.
- Replaced single-line input with an auto-wrapping title textarea.
- Dual schedule cards explicitly explain their roles: *"When you intend to work on it"* vs. *"Hard completion commitment"*.
- Checklist and subtasks are editable and checkable directly within the panel.

### Objective 5: Hide Internal Technical Terminology
- Completely removed developer-only references (e.g. SQLite, WAL checkpoint, CAS concurrency tokens, Drift schema, IPC).
- Replaced with clear user-facing language: *"Synced · Offline Ready"*, *"All edits saved locally"*, and *"When this task is completed, next occurrence will be scheduled automatically"*.

### Objective 6: Refine Progressive Disclosure
- Common actions (*Add Task*, *Filter*, *Search*) are immediately accessible.
- Advanced operations (*Smart Reschedule*, *Bulk edit*) are placed in secondary positions to avoid dominating the primary view.
- Advanced task settings (*Recurrence Rules*, *Alarms & Notifications*, *Prerequisites & Blockers*) are tucked inside clean, collapsible accordions.

### Objective 7: Preserve Todorbit's Actual Feature Model
- **Priorities:** Strictly uses Todorbit's four actual priorities from `lib/domain/models.dart`: None (0), Low (1), Medium (2), and High (3).
- **Statuses:** Strictly uses Todorbit's `TaskStatus`: Not Started, In Progress, Waiting, On Hold, Completed, Cancelled.
- **Distinct Concepts:** Preserves separation between Planned Dates, Deadlines, Fixed Calendar Events, and Focus Sessions.

### Objective 8: Demonstrate Today View's Tasks, Events, and Focus Sessions
- **Active Focus Session Banner:** Displays current running focus timer (18:24 remaining on Thesis research) with pause affordance.
- **Fixed Events Timeline:** Displays time-bound appointments (*CS450 Distributed Systems Lecture* at 10:00 AM, *Dentist Appointment* at 2:30 PM).
- **Tasks for Today:** Organizes tasks into Overdue Deadlines and Planned Today groups.

### Objective 9: Realistic Sample Data
- Replaced synthetic developer tasks with diverse, relatable examples:
  - *Academic / University:* Raft consensus assignment, Thesis proposal draft.
  - *Errands / Healthcare:* Grocery list (almond milk, spinach), pharmacy prescription pickup, dentist appointment.
  - *Personal Habits:* Daily 20-minute evening mindfulness and stretching routine.
  - *Hardware:* Replacement ergonomic keyboard arm (Waiting status).

### Objective 10: Arbitrary Viewport Resizing & Text Scaling
- Added a responsive simulation bar with:
  - Presets: 1440 Desktop Wide, 1100 Desktop Medium, 820 Narrow Desktop, 390 Mobile.
  - **Text Scale Factor Control:** 100%, 125%, 150% text scaling simulation to test accessibility font enlargement without layout breakage.
  - **Empty State Switcher:** Allows toggling between the populated Today view and an empty state card (*"All clear for today!"*).

### Objective 11: Explicit Prototype Simulation Notice
- Added a permanent notice in the simulator bar: *(Visual prototype simulation — no actual database writes)*.
- Clear dialog notices on interactive triggers (e.g. "Saved locally. Prototype simulation").

### Objective 12: Keyboard Accessibility & Interaction Semantics
- Checkboxes implemented with semantic `<button>` tags, explicit `aria-label`, and high-contrast `:focus-visible` outlines.
- Priority cues combine geometric shapes (▲ High, ■ Med, ◆ Low) with text labels to ensure full accessibility without relying on color alone.

---

## 4. Remaining Trade-offs & Implementation Notes

1. **Ultra-Wide Screens (≥1920 dp):** On ultra-wide displays when the detail panel is closed, the task list should be centered with a `max-width: 960px` in production Flutter code to prevent excessively wide text scanning.
2. **Desktop Drag vs. Mobile Touch:** Drag-to-resize side panel functionality is enabled on desktop viewports; on mobile (Android), the task editor must use a full-screen route or bottom sheet.
3. **Simulated State:** Prototype interactions (checkbox toggling, empty state switching, text scaling) are client-side JavaScript simulations. Production integration will bind to Drift SQLite, `LifeRepository`, and Riverpod `AppController`.

---

*Open [`docs/design-concepts/concept-c-adaptive-workspace.html`](concept-c-adaptive-workspace.html) in Google Chrome, Microsoft Edge, or Firefox to review.*
