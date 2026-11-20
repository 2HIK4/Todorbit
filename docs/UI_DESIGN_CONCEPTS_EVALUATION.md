# Todorbit Visual Design Concepts â€” Evaluation & Recommendation

**Authored:** 2026-11-20
**Branch:** `design-foundation-docs`
**Prototypes:**
- Concept A: [`docs/design-concepts/concept-a-refined-minimalist.html`](design-concepts/concept-a-refined-minimalist.html)
- Concept B: [`docs/design-concepts/concept-b-modern-workspace.html`](design-concepts/concept-b-modern-workspace.html)

Both prototypes are self-contained HTML/CSS files with live light/dark theme toggles, interactive task selection, resizable side panels, and collapsible Progressive Disclosure sections. They can be opened in any browser.

---

## 1. Concept Overviews

| Aspect | Concept A: Refined Minimalist | Concept B: Modern Productivity Workspace |
|--------|------------------------------|------------------------------------------|
| **Visual identity** | Calm, spacious, Fluent-adjacent. Rounded cards, subtle borders, restrained blue accent (`#3B6FE0`). | High-density, professional, developer-tool feel. Dark-first, tabular task rows, indigo accent (`#6366F1`) + cyan. |
| **Task row style** | Card-style list item with left priority border. Due date and tags in a metadata row below the title. | Tabular/grid layout: Checkbox \| Title \| Project \| Due Date \| Priority \| Badges. |
| **Information density** | Medium: 48â€“56 dp per task row. Generous white space. Highly legible at any screen size. | High: 36â€“40 dp per task row. 30% more tasks visible simultaneously. |
| **Task details panel** | 380 dp default. Form-style vertical layout with labeled fields. | 420 dp default. Tabbed workspace (Details / Subtasks / Focus Log) with a 2-column metadata grid. |
| **Dark theme** | Deep slate (`#0F0F13` bg, `#1A1A22` surface). Soft contrast. | Dark graphite (`#181920` bg, `#21222C` surface). High-contrast indigo glow accents. |
| **Navigation** | Standard category tree with pill-style selection. | Grouped sections with quick-add header button and inline keyboard shortcut indicator. |

---

## 2. Detailed Evaluation

### Concept A: Refined Minimalist

**Strengths:**
- **Superior readability:** Generous line-height and spacing make scanning effortless. Does not induce cognitive overload.
- **Natural Progressive Disclosure:** Advanced fields (recurrence, reminders, dependencies) sit comfortably in collapsible cards that don't crowd the viewport.
- **Easy cross-platform parity:** The card-style row maps directly to Android's `ListTile` patterns with minimal adaptation.
- **Matches existing codebase:** Close to Todorbit's current component structure (uses `ExpansionTile`, `CardTheme`, `ListTileThemeData` already in `app_theme.dart`). Lowest implementation risk.
- **Better accessibility headroom:** Ample space for â‰¥48 dp tap targets and large text scaling (up to 200%) without clipping.

**Weaknesses:**
- Shows fewer tasks on screen simultaneously (~8â€“10 tasks on a standard 1080p display before scrolling).
- Power users with large monitors (1440p+) may find the horizontal space underutilized in the list pane.

---

### Concept B: Modern Productivity Workspace

**Strengths:**
- **High information throughput:** Tabular layout lets power users compare due dates, priorities, and projects across many tasks in a single glance.
- **Excellent desktop space utilization:** Makes effective use of wide monitors (â‰¥1200 dp) without feeling sparse.
- **Multitasking panel:** The tabbed detail workspace (Details, Subtasks, Focus Log) allows deep editing without leaving the main view.
- **Appealing to developers / technical users:** Aesthetic resembles Linear, Raycast, or GitHub Projects.

**Weaknesses:**
- **Poor Android translation:** Tabular columns cannot fit on a mobile screen (<600 dp). Would require maintaining two substantially different task-row implementations, defeating the goal of a unified design system.
- **Higher implementation complexity:** Requires a custom grid/table widget rather than reusing Flutter's built-in `ListTile` / `Card` infrastructure.
- **Fragile at large text scale:** Fixed-column layouts clip when `textScaleFactor â‰¥ 1.5` unless complex truncation or column-hiding logic is added.
- **Higher cognitive load:** Initial visual impression is busier, conflicting with the "simple by default" product requirement.

---

## 3. Product Requirement Scorecard

| Requirement | Concept A (Minimalist) | Concept B (Workspace) | Winner |
|-------------|:---------------------:|:---------------------:|:------:|
| 1. Excellent default experience | â˜…â˜…â˜…â˜…â˜… | â˜…â˜…â˜…â˜†â˜† | **A** |
| 2. Simple by default, powerful on demand | â˜…â˜…â˜…â˜…â˜… | â˜…â˜…â˜…â˜†â˜† | **A** |
| 3. Hide irrelevant technical info | â˜…â˜…â˜…â˜…â˜… | â˜…â˜…â˜…â˜…â˜† | **A** |
| 4. Cross-platform consistency (Win + Android) | â˜…â˜…â˜…â˜…â˜… | â˜…â˜…â˜†â˜†â˜† | **A** |
| 5. Deep customization via tokens | â˜…â˜…â˜…â˜…â˜† | â˜…â˜…â˜…â˜…â˜† | Tie |
| 6. Desktop space utilization (large screens) | â˜…â˜…â˜…â˜†â˜† | â˜…â˜…â˜…â˜…â˜… | **B** |
| 7. Implementation safety & component reuse | â˜…â˜…â˜…â˜…â˜… | â˜…â˜…â˜†â˜†â˜† | **A** |
| 8. Accessibility & text-scaling tolerance | â˜…â˜…â˜…â˜…â˜… | â˜…â˜…â˜…â˜†â˜† | **A** |

---

## 4. Recommendation

**Strongly recommend Concept A (Refined Minimalist)** for the following decisive reasons:

1. **Cross-platform shared components:** Concept A's `AppTaskRow` works identically on Windows and Android (with minor padding adjustments). Concept B would require divergent implementations for mobile vs. desktop, re-introducing the exact fragmentation identified in RC-1 of the UI audit.
2. **True to "Simple by Default":** Todorbit is a personal productivity app, not an enterprise issue tracker. Concept A delivers a calm, focused experience for ordinary users while preserving full access to advanced features via contextual Progressive Disclosure.
3. **Safe, incremental migration:** Concept A reuses existing `buildAppTheme()` typography, `AppSpacing`, and `ExpansionTile` mechanisms. It can be implemented in the pilot with ~400 lines of new Flutter code. Concept B requires extensive custom layout work.
4. **Desktop responsiveness:** Concept A scales naturally from 600 dp to 1920 dp by adjusting list pane margins and side-panel width, without column truncation issues.

> [!NOTE]
> **This recommendation is proposed for Codex and product owner review.** It is not approved.
> Implementation must not begin until the design direction is selected.
