# Ultimate UI/UX Agent Skill

A standalone, original, reusable agent skill designed to improve and audit websites and mobile/desktop applications. Includes a 28-category issue/fix catalog, risk-based test matrix, fix patterns, and report template.

**No skill guarantees a perfect design or zero bugs.** This skill requires actual runtime review and evidence, when tooling is available, and requires a clear report of anything untested.

## Install in Codex (project-local)

1. Extract `ultimate-ui-ux-skill.zip`.
2. Copy the folder `ultimate-ui-ux` into `<your-project>/.agents/skills/`.
3. Final path: `<your-project>/.agents/skills/ultimate-ui-ux/SKILL.md`.
4. Start/restart Codex session if it doesn't discover the skill immediately.
5. Ask: `Use $ultimate-ui-ux to inspect every relevant screen, popup, state and UI flow, fix verified problems, and report tests and gaps.`

Other agents may support a compatible `skills/<name>/SKILL.md` directory or different installation conventions. Check their documentation.

## What is included

- `SKILL.md`: skill metadata, activation triggers, workflow, evidence requirements.
- `references/issue-catalog.md`: 28 domains of visual, functional, responsive, state, platform and accessibility errors, each paired with repairs.
- `references/test-matrix.md`: pragmatic coverage and priority system.
- `references/fix-patterns.md`: implementation approaches and fragile patches to avoid.
- `references/report-template.md`: repeatable findings/test ledger.
- `references/sources.md`: the ten source projects used as **inspiration**, with links.

## Useful agent request

> Use `$ultimate-ui-ux` for an end-to-end UI/UX quality pass. Read project guidance first. Inventory routes, screens, widgets, popups, light/dark themes, states and interactions. Inspect rendered UI wherever possible. Use the issue catalog and risk-based test matrix. Fix confirmed issues without changing intended behavior or introducing visual inconsistency. Run targeted and regression checks; record exact commands, scope, results and any untested environments. Do not claim perfection or full accessibility compliance.

This package includes no downloaded third-party scripts or executable code.
