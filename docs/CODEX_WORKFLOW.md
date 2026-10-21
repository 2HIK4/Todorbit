# Codex workflow

Use a new chat for a distinct objective; continue the current chat while fixing or reviewing the same change. Start with the goal, affected screen or behavior, constraints, and observable acceptance criteria. Link a prior decision or progress entry only when it matters.

Use low reasoning for narrow, reversible edits and routine questions; medium for multi-file implementation or debugging; high for migrations, native interop, difficult regressions, and architectural tradeoffs. Raise effort when evidence warrants it. Keep the model choice and effort adjustable per task; do not sacrifice correctness to save tokens.

Search relevant directories with `rg` and exclude `build/`, `.dart_tool/`, generated Windows files, and dependencies. Inspect a Git diff before broadening tests. Run focused diagnostics first; use full Flutter analysis/tests and Windows/native builds at integration or release milestones. Validate visual changes in an isolated profile and use `docs/windows-widget.md` for native widget changes. Report what passed and what remains manually unverified.

Record durable product decisions in `docs/DECISIONS.md` and meaningful checkpoints in `docs/PROGRESS.md`. Keep handoffs to the current state, changed files, verification, and next concrete action. For Windows design use [Microsoft Fluent guidance](https://learn.microsoft.com/en-us/windows/apps/design/) first; use `docs/THEMING.md` for Todorbit tokens. Apple Design is an optional independent UX review, not the Windows platform rulebook.
