# Agent Workflow Efficiency & Context Optimization

This reference guides AI coding agents (Codex, Gemini Antigravity) to operate with maximum context efficiency, precision, and safety in Todorbit.

---

## 1. Minimal Context Consumption Principles

Excessive context consumption degrades agent reasoning, wastes token budget, and causes hallucinations.

### Rules of Engagement:
1. **Start with the Map**: Always consult `docs/ARCHITECTURE_MAP.md` first to locate feature entry points. Never read the entire `docs/` folder or scan repository trees broadly.
2. **Targeted Search**:
   - Use `git grep -n` or bounded `rg -n` scoped to specific subdirectories (e.g. `lib/features/calendar/`).
   - Strictly exclude `.dart_tool/`, `build/`, `.buildlog/`, `windows/flutter/ephemeral/`, and dependencies.
3. **Bounded File Reading**:
   - Inspect specific line ranges with `read_file` rather than reading thousand-line source files in their entirety.
   - When inspecting test results, read only summary lines and failure traces.

---

## 2. Test Ledger Lookup & Pass Reuse Policy

Before running any test or build command, follow `docs/TESTING.md` and `docs/TEST_RUN_LEDGER.md`:

### Invariants:
1. **Never Rerun Solely Because a Task Started**: An unedited boundary does not invalidate previous passes.
2. **Compare 4 Fingerprints**:
   - Source code hash/manifest of affected files.
   - Assertions executed.
   - Dependencies and configuration.
   - Host environment.
3. **Reuse Valid Passes**: If the boundary code is unchanged, reuse the recorded pass from `docs/TEST_RUN_LEDGER.md`.
4. **Record Invalidation Reason**: If rerunning, explicitly state what code change or failed hypothesis invalidated the prior result.
5. **No Test Invention**: Never label an unexecuted command as "Passed". Record unverified areas explicitly as "Pending" or "Manual".

---

## 3. Git Discipline & Safe Checkpoints

1. **Check Baseline First**:
   - Run `git status --short`, `git branch --show-current`, and `git log -3 --oneline`.
   - Never reset or stash unrelated uncommitted changes.
2. **Preserve Untracked Work**:
   - Untracked files (e.g. `docs/STORAGE_*.md`) may represent ongoing operator work or diagnostic evidence. Do not delete, ignore, or commit them without explicit authorization.
3. **Atomic, Single-Purpose Commits**:
   - Separate documentation/tooling fixes from runtime functional code changes.
   - Stage explicit files (`git add <file1> <file2>`) rather than `git add .` or `git add -A`.
   - Review staged diff with `git diff --cached` and `git diff --check` before committing.
4. **Interrupted Work Protocol**:
   - When ending a session or handoff, record:
     - Exact branch and commit SHA.
     - Files modified or created.
     - Completed checks and results.
     - Next concrete, actionable task.

---

## 4. Minimal Implementation & The Ponytail Decision Ladder

Adopt the "laziest senior developer" discipline to prevent over-engineering, speculative abstractions, and redundant code:

### The Decision Ladder (Evaluate Before Writing Code):
1. **YAGNI (You Aren't Gonna Need It)**: Skip speculative features, unrequested options, and premature flexibility. Deliver strictly the core solution.
2. **Codebase Reuse**: Search for existing helpers, widgets, services, or domain models in Todorbit before writing new ones (`lib/features/shared/`, `lib/domain/`, etc.). Reuse existing patterns.
3. **Platform & Stdlib Native First**: Prefer built-in Dart/Flutter standard APIs (`SingleChildScrollView`, `LayoutBuilder`, `MediaQuery`, `ScrollController`, `ValueNotifier`) over introducing custom wrapper widgets or utility classes.
4. **Existing Installed Dependencies**: Use dependencies already registered in `pubspec.yaml`. Never add a new third-party dependency for a capability that takes a few lines of clean code.
5. **Minimal Implementation Diff**: Write the smallest working change that touches only necessary files, preserves existing layers, and maintains architectural conventions. Deletion of redundant code beats addition of wrapper layers.
6. **Explicit Boundaries & Limits**: Every task receipt must conclude with an explicit statement of what was skipped, what was not tested, and any known limitations or environmental constraints.

---

## 5. Targeted Dependency Mapping & Decoupling (Untangle-Informed, Safety-Bounded)

When diagnosing architectural friction or multi-file bugs, use targeted structural inspection without performing broad or unverified codebase refactorings:

### The Core Inquiry: "Should These Pieces Change Together?"
- **Detect Hidden Links**:
  - Duplicated logic or constants across desktop and mobile shells (e.g. recurrence calculations duplicated between Dart and Windows .NET companion).
  - Implicit call order or convention assumptions between callers and repositories.
  - Colocated logic scattered arbitrarily across unrelated folders.
- **Detect Needless Links**:
  - Callers depending directly on component internals or private fields.
  - Stable domain models importing volatile presentation widgets.
  - Pass-through wrappers that only change when the wrapped class changes.
  - Caller-specific parameter bloat leaked into general domain functions.
- **Detect Surplus**:
  - Dead code, unused imports, speculative extension hooks, or configurations for invariants that never vary.
- **Treat Special Cases as Design Signals**:
  - One-off `if` branches for single callers, swallowed exceptions, or arbitrary sleep/retry delays are architectural warnings that an underlying lifecycle, transaction, or domain concept is missing. Diagnose and fix the root model rather than adding more one-off branches.

### Strict Todorbit Safety Constraints:
- **NO Repository-Wide Refactoring in One Pass**: Never execute untargeted repository-wide refactoring workflows. Refactor only the bounded subsystem under active authorized modification.
- **NO Test Deletion**: Never delete existing tests, assertions, or fixtures under the guise of "cleanup". Tests are non-negotiable regression safety nets.
- **Zero Data Loss & Safe Migrations**: Structural changes must never compromise SQLite forward migrations (Schema 29), monotonic CAS revision tokens, or user data preservation.
