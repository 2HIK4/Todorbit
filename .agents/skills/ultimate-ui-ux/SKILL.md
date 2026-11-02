---
name: ultimate-ui-ux
# Description doubles as an activation trigger for agents supporting Agent Skills.
description: "Design, inspect, implement, audit, debug, and polish web, desktop, and mobile interfaces. Apply when a user asks to improve UI/UX, inspect all screens, fix visual inconsistencies, test accessibility, responsiveness, themes, forms, dialogs, motion, input interactions, edge cases, or perform comprehensive end-to-end UI review. Includes evidence-based runtime verification and regression testing."
---

# Ultimate UI/UX: Design, Audit, Fix, Verify

**Mission:** Deliver interfaces that are visually coherent, understandable, operable, accessible, responsive, and reliable. Treat this as a repeatable quality workflow, not a promise of perfection. **Do not claim 100% coverage, perfect design, WCAG compliance, or zero bugs without sufficient independent evidence.**

## Activation and mode

Use this skill for UI construction, redesign, audit, debugging, polish, or shipping review. First infer the requested mode:

- **Build:** Design new UI that fits audience, product, and existing design conventions.
- **Audit:** Report findings with exact steps, context, severity, and evidence. Avoid modifying code if explicitly asked only to review.
- **Fix:** Make minimal, maintainable, verified corrections; do not silently overhaul the design.
- **Polish:** Refine typography, spacing, hierarchy, motion, microcopy, and clarity without changing working behavior.
- **Ship review:** Run the widest feasible release-relevant coverage, report residual risks and untested combinations.

## Mandatory start

1. Read project guidance before touching code: e.g. `AGENTS.md`, `README.md`, `docs/CODEX_WORKFLOW.md`, `docs/TESTING.md`, design specifications, relevant architecture and release documents. Follow existing build/test conventions and the user's constraints.
2. Identify target products (marketing page, data-heavy app, native mobile, desktop utility), supported platforms, frameworks, main user flows, users and accessibility needs.
3. Inventory *actual* routes, screens, panels, windows, dialogs, popovers, notifications, forms, widgets, settings, themes, and shared components. Use repo searches, navigation maps and runtime exploration; don't guess scope from filenames.
4. Detect current design system and preserve established visual language unless redesign is authorized. Review tokens, font scale, component primitives, icon library, spacing, borders, radii and interaction patterns. Prefer deliberate simplicity over decorative uniformity.
5. Inspect actual rendered UI using browser automation, emulator/simulator, desktop automation, or screenshots *where available*. Verify tool capability rather than assuming it. If impossible, clearly mark visual/interaction coverage **NOT TESTED**, and use code inspection as an explicitly weaker substitute.

## Operating sequence (complete this loop)

### A. Discover and prioritize
- Map components to routes/screens, states and real user journeys. Include long text, empty state, error, partial load, loading, disabled, hover, focus, selected, success, and failure.
- Read `references/issue-catalog.md`: **28 categories**, each with symptom-to-fix rules. Run category-specific checks, not merely a superficial visual pass.
- Read `references/test-matrix.md` to choose representative viewport/theme/input/accessibility/locale combinations. Use risk-based pairwise coverage and targeted edge cases; avoid impossible exhaustive cross-product assertions.
- Record baseline screenshots/screens, failures, logs and expected behavior before changing code where feasible.
- Prioritize **P0 blocking**, **P1 critical**, **P2 significant**, **P3 polish**. Trust/safety, data loss, broken workflows and accessibility blockers outrank aesthetic details.

### B. Choose or refine design language
- Intent first: define the screen's job, primary action, critical information, and the hierarchy needed to achieve it.
- Prefer existing semantic design tokens. Create or extend missing tokens for primary/secondary/tertiary text, background/surface/border, states, spacing, type scale, radius, focus ring, motion and elevation.
- Establish title > section heading > body > label > helper/caption hierarchy. Avoid same-size, same-weight, same-white text everywhere; maintain meaningful readability and contrast.
- Align repeated components, improve whitespace rhythm, and simplify dense copy. Never solve overflow by simply hiding content that users need.
- Use product-appropriate visuals. Avoid generic templates, indiscriminate cards, random gradients and unnecessary animation. Respect platform-native expectations.

### C. Validate behavior, accessibility and resilience
- Run available linters, tests and relevant build checks. For web: keyboard-only navigation, accessible names, focus behavior, label/error announcement, responsive layout, zoom, theme, browser navigation, realistic waits and failures. For native: screen reader, system text size, device rotation/safe areas, background-resume, keyboard/gesture/back.
- Use automated accessibility tools where possible, but **never** equate a clean automated scan with complete WCAG compliance.
- WCAG 2.2 AA reference checks: ordinary text contrast **>=4.5:1**, large text **>=3:1**, meaningful non-text UI contrast generally **>=3:1**, relevant 200% text resize, 320 CSS px reflow where applicable, 24x24 CSS px target size or qualifying spacing/exception for 2.5.8. Prefer **44x44 CSS px or platform guidance** for comfortable touch targets when feasible. Check actual spec/exceptions rather than treating a single number as universal.
- Include keyboard-only, screen reader if available, reduced motion, high contrast, RTL/LTR, localization, long strings, missing data, large lists, and reduced network reliability.
- Test interactions *end to end*. A clickable-looking element must execute the intended action; success should reflect confirmed underlying state.

### D. Fix with minimal regression risk
- Find root cause before patching. Fix the component/design token/layout rule, not the individual screenshot using magic offsets.
- Prefer semantic HTML/native controls, adaptive layout, correct focus lifecycle, semantic colors, concise copy and tested state logic.
- Protect data and user work. Warn before destructive actions; preserve draft state; guard against double submission and stale responses.
- Don't introduce a new dependency without a clear need and license/security review. No unrelated refactors, wide redesign or silently removed features.
- Recheck the exact failing case **and** adjacent consumers of shared components, theme variants and sizes. Document remaining limitations.

### E. Evidence and delivery
- Record every test actually run with **command/action, environment, scope, result, and why run**. Note previous run/commit when relevant to avoid redundant unchanged tests.
- For visual findings provide screenshot or reproducible path/steps when supported. A passing compile, static test or screenshot alone does not prove interaction correctness.
- Output findings via `references/report-template.md`. List **fixed and re-tested**, **open**, **not tested** separately. Never assert a verification occurred if tool/device unavailable.
- Stop only when release blockers within scope are corrected or explicitly reported, and the available regression suite plus targeted visual checks pass. Report untested scenarios clearly.

## Required evidence for UI changes

For each significant fix, capture: `Screen/component | Issue & severity | Reproduction | Root cause | Change | Tests | Evidence | Remaining risk`. Put screenshots, automation traces, and logs in the project's normal artifacts directory if authorized, and avoid storing sensitive user data.

## References to load as needed

- `references/issue-catalog.md` — exhaustive **practical** symptom/fix catalog, organized into 28 issue domains.
- `references/test-matrix.md` — risk-based viewport, theme, interaction, accessibility, locale, platform and state coverage.
- `references/fix-patterns.md` — example fixes and anti-patterns for web, Flutter, native and desktop.
- `references/report-template.md` — auditable issue list, test ledger and release decision.
- `references/sources.md` — ten reviewed inspiration skills, attribution, and normative external standards. This is an **original synthesis**, not a copied bundle of third-party skills or their code.

## Scope guardrails

- A skill provides guidance, **not** a browser, emulator, device, screen reader, accessibility certification, or automatic execution environment.
- No exhaustive list can anticipate all future UI bugs. Test high-risk journeys, unusual content, platform differences and real user needs.
- Preserve exact user-stated behavior and existing design unless changes requested; explain material tradeoffs.
- An audit with no detected issues is not proof of perfection. State the scope and evidence honestly.
