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
