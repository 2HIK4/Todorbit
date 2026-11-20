# Todorbit Visual Design Concepts — Evaluation & Design Iteration 2

**Authored:** 2026-11-20
**Branch:** `design-foundation-docs`
**Prototypes:**
- Concept A: [`docs/design-concepts/concept-a-refined-minimalist.html`](design-concepts/concept-a-refined-minimalist.html)
- Concept B: [`docs/design-concepts/concept-b-modern-workspace.html`](design-concepts/concept-b-modern-workspace.html)
- **Concept C (Iteration 2):** [`docs/design-concepts/concept-c-adaptive-workspace.html`](design-concepts/concept-c-adaptive-workspace.html)

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

| Attribute | Concept A: Refined Minimalist | Concept B: Modern Productivity | **Concept C: Adaptive Workspace (New)** |
|---|---|---|---|
| **Visual Identity** | Plain minimalist card list, generic blue (`#3B6FE0`). | High-density developer grid, dark indigo (`#6366F1`) + cyan. | **Celestial Twilight / Luminous Canvas:** bespoke orbital brand identity, twilight slate dark theme (`#0F1017` / `#171823`), subtle violet-indigo accent (`#7E74F1`), clean responsive cards. |
| **Task Presentation** | Vertical cards with colored left borders. | Strict multi-column tabular grid. | **Adaptive Task Rows:** 52 dp balanced default (or 38 dp compact toggle). Geometric priority shapes (▲ P1 Urgent, ■ P2 High, ▬ P3 Normal) ensuring readability without relying on color alone. |
| **Title Readability** | Good, but single line. | Poor; frequent truncation. | **Exceptional:** Dedicated primary line with generous font scaling (14.5px / 13.5px), handles long titles gracefully without layout break. |
| **Domain Invariant Clarity** | Planned and Due dates rendered similarly. | Single "Due" date column. | **Strict Todorbit separation:** Labeled Planned Date (🗓️ intentional schedule) vs. Hard Deadline (⏰ commitment gate) with distinct color semantics. |
| **Task Details Workspace** | Form fields in cards; property inspector feel. | Tabbed metadata grid with tiny text. | **True Task Workspace:** Resizable side panel (340–650 dp) with drag handle, prominent editable title, dual schedule cards, interactive subtask checklist, progressive disclosure accordions, and optional **Expanded Modal Workspace** (⤢). |
| **Responsive Adaptation** | Fixed width assumption. | Fixed width table (broken on mobile). | **Built-in multi-viewport simulator:** Live preview modes for Desktop Wide (1440×900), Medium Desktop (1000×800 with auto-collapsed padding), and Mobile (390×844 with bottom navigation & full-screen editor). |
| **Information Architecture** | Basic subset of views. | Basic subset of views. | **Complete Todorbit IA:** Today, Calendar, Upcoming & Overdue, All Tasks, Focus Sessions, Habits, Goals, Reports, Projects, Google Drive Sync status, Preferences. |
| **Density Options** | Fixed medium density. | Fixed compact density. | **User-selectable:** Balanced (52 dp) vs. Compact (38 dp) toggle in toolbar. |

---

## 3. Deep Dive: Concept C Innovations

### 3.1 Distinctive Visual Identity
Concept C avoids generic SaaS tropes (excessive drop shadows, heavy purple gradients, redundant container borders). It introduces a refined, calm aesthetic:
- **Dark Theme:** Deep celestial obsidian (`#0F1017` canvas, `#171823` card surfaces, `#272B3E` subtle structural borders).
- **Light Theme:** Luminous clean slate (`#F6F7FB` canvas, `#FFFFFF` cards, `#E2E6F0` crisp outlines).
- **Brand Motifs:** Circular orbital check-rings that visualize subtask completion progress, paired with a modern geometric brand logo.

### 3.2 Dual Scheduling System (Planned Date vs. Deadline)
Todorbit's core architectural principle is that when you plan to work on a task is distinct from when that task is due. Concept C explicitly visualizes this:
- **Planned Date:** Rendered in warm amber (`#F59E0B`) with an intentional calendar icon (e.g., `🗓️ Planned: Today`).
- **Deadline:** Rendered in coral red (`#F43F5E`) when overdue or distinct secondary slate when upcoming (e.g., `⏰ Deadline: Nov 25`).

### 3.3 Genuine Task Details Workspace
The side panel in Concept C is not an inspector:
- Draggable resize handle with visual grip feedback.
- Prominent inline-editable task title.
- Interactive subtask list directly inside the panel (check off subtasks, view progress).
- Contextual progressive disclosure accordions for Recurrence, Alarms, and Dependencies.
- An **Expanded Workspace button (⤢)** that opens complex tasks in a distraction-free two-column editing canvas.

### 3.4 Cross-Platform Responsive Architecture
Concept C includes an integrated simulator bar in the prototype:
1. **Desktop Wide (1440 × 900):** Side rail navigation + task stream + persistent resizable details panel.
2. **Desktop Medium (1000 × 800):** Narrowed sidebar (210 dp), compact panel (380 dp), and adaptive headers that avoid truncation or overflow.
3. **Mobile Shell (390 × 844):** Auto-hides the desktop sidebar, replaces it with a native mobile bottom navigation bar (Today, Calendar, New, Focus, Settings), and opens the task editor as an overlay modal with full touch clearance.

---

## 4. Remaining Trade-offs & Limitations

1. **Horizontal Space in Wide Viewports:** When the details panel is closed on an ultra-wide display (≥1920 dp), the single-column task stream must have an explicit maximum content constraint (e.g., `max-width: 900px`) centered in the workspace to prevent unreadably long text lines.
2. **Gesture Conflicts on Mobile:** The drag-to-resize side panel feature is strictly desktop-only; on Android, the task editor must remain a full-screen route or bottom sheet.
3. **Simulated State in Prototype:** Interactions (saving, checkbox toggles, panel resizing, theme switching) are demonstrated using client-side vanilla JavaScript; production SQLite transactions and CAS tokens will be connected during Phase 2 implementation.

---

## 5. Design System Implementation Refinements

Based on Concept C, the following updates are scheduled for the Todorbit Design System:

1. **`AppLayout` Tokens:**
   - `breakpointCompact = 600`
   - `breakpointMedium = 1050`
   - `breakpointWide = 1200`
   - `rowHeightBalanced = 52`
   - `rowHeightCompact = 38`
   - `panelMinWidth = 340`
   - `panelDefaultWidth = 440`
   - `panelMaxWidth = 650`
2. **`AppTaskRow` Widget:**
   - Parameter `density: TaskListDensity.balanced | TaskListDensity.compact`.
   - Accessible `priorityPip` rendering geometric shapes (▲, ■, ▬) in addition to theme colors.
3. **`AppTaskDetailPanel` Widget:**
   - Stateful horizontal drag gesture detector persisting width preference to `ThemeCustomization`.
   - Dual-date selector widget separating planned dates from deadlines.

---

*Concept C prototype is available at `docs/design-concepts/concept-c-adaptive-workspace.html`. Open directly in Google Chrome, Microsoft Edge, or Firefox.*
