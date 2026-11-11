---
name: todorbit-engineering-quality
description: "Enforce Todorbit engineering standards, offline-first data safety, SQLite migrations, incremental Google Drive sync, cross-platform architecture (Windows/.NET and Android/Kotlin), root-cause debugging, performance profiling, and context-efficient AI coding workflows."
---

# Todorbit Engineering Quality & Maintainability

Deliver robust, maintainable, data-safe, and performant capabilities for Todorbit on Windows 10/11 and Android. This skill owns architectural integrity, backend/persistence logic, platform integration, performance measurement, and coding-agent operational discipline.

passing builds or unverified test claims do not establish correctness. Never claim a defect is fixed, a performance problem solved, or a cross-platform feature complete without source-anchored evidence.

---

## Three-Tier Standard Hierarchy

Treat rules by their strict level of authority:

1. **Mandatory Safety Rules (Non-Negotiable)**:
   - **Zero Data Loss**: Never wipe, reset, drop, or overwrite SQLite tables, profile JSON files, user backups, or widget settings as an error recovery fallback.
   - **Domain Invariants & Test Expectation Integrity**: Identify authoritative domain invariants before changing behavior. Never create or trust tests that merely encode existing implementation bugs. Differentiate visual display constraints from persistence constraints (display clipping must never truncate persisted timestamps or user data). Verify fixes against legitimate edge cases (overnight spans, multi-day durations, recurrence). Always prove fixes with focused regression tests that fail on the defect and pass strictly after correction.
   - **Forward-Compatible Migrations**: Schema alterations MUST be forward-migrated through explicit Drift migrations and verified in `MigrationGate`.
   - **CAS Task Concurrency**: All task writes MUST advance `updated_at` beyond the predecessor timestamp and check revision concurrency tokens via SQL compare-and-swap (CAS).
   - **Profile Isolation**: Never execute tests or debug builds against real production `%APPDATA%\TodoPilot` or personal accounts. Always use isolated, disposable profiles.
   - **Atomic Multi-Record Mutations**: Operations touching multiple records or tables MUST execute inside an explicit SQLite transaction.

2. **Recommended Engineering Practices (Strong Defaults)**:
   - **Layer Separation**: UI strictly in `lib/features/`, business/calculation logic in `lib/domain/`, SQLite/Drift access in `lib/data/`, coordinated via Riverpod `AppController`.
   - **Pure Domain Code**: `lib/domain/` MUST NOT import Flutter widgets or platform-native channels. Keep domain logic pure and deterministic.
   - **Smallest Safe Diff**: Prefer localized, reversible edits over broad architectural overhauls. Never introduce parallel implementations or speculative abstractions just to reduce file line count.
   - **Verified Root-Cause Fixes**: Diagnose the full caller graph and reproducible failure mechanism before modifying code. Band-aid checks (e.g. arbitrary null-coalescing or silent returns) hide architectural corruption.

3. **Optional Measured Optimizations**:
   - Only optimize when a bottleneck is confirmed by profiler evidence (DevTools, timeline traces, heap allocations). Never introduce complexity based on unmeasured performance hypotheses.

---

## Selective Reference Activation

Do not load all documentation into context. Activate only the reference matching your current engineering domain:

| Focus Area | Reference Document | Key Invariants Covered |
|---|---|---|
| **SQLite, Sync, Backup, Alarms** | [Data Safety & Persistence](references/data-safety-and-persistence.md) | Drift schema 28, migrations, CAS tokens, AES-GCM sync batches, Before Restore backups |
| **Windows & Android Native Integration** | [Cross-Platform Architecture](references/cross-platform-architecture.md) | Windows runner & .NET 10 companion (`WidgetDateNavigation`), Android shell (`MobileWorkspace` vs `Workspace`), lifecycle, Doze, alarms, calendar parity |
| **Profiling, Memory & 16GB RAM Limits** | [Performance & Profiling](references/performance-and-profiling.md) | Memory leak avoidance, 16GB RAM resource budgeting, build thrashing prevention, rendering efficiency |
| **Agent Efficiency, Search & Ledgers** | [Agent Workflow Efficiency](references/agent-workflow-efficiency.md) | Bounded search, test ledger policy, minimal context consumption, atomic Git checkpoints |

---

## Core Engineering Directives

### 1. Root-Cause Analysis & Bug Fixing
- **Step 1: Reproduce**: Construct a minimal deterministic failing test or isolated command reproducing the symptom.
- **Step 2: Trace Caller Graph**: Locate the authoritative data owner (`LifeRepository`, `AppController`, or native companion). Identify the exact sequence producing invalid state.
- **Step 3: Fix at the Root**: Correct the defect where the invariant is broken, not at downstream display consumers.
- **Step 4: Verify Boundary Invariants**: Verify that sibling consumers and undo/redo stacks remain unbroken.

### 2. Cross-Platform Parity & Architecture Discovery
- **Desktop vs Mobile Shell Divergence**:
  Desktop mounts `CalendarView` via `lib/features/workspace/workspace.dart`.
  Android unconditionally mounts `MobileWorkspace` via `lib/main.dart`, which renders `MobileCalendar`.
  - **Rule**: Changes to `CalendarView` do NOT automatically reach production Android users.
  - **Rule**: Testing a desktop widget wrapped in `ThemeData(platform: TargetPlatform.android)` proves widget layout behavior under mobile styling, but does NOT prove Android production UI exposes that widget.
  - **Rule**: When adding shared capabilities, explicitly identify both platform entry points and record parity or intentional mobile exclusions.

### 3. Developer Tooling & Verification Policy
- Before executing any verification, consult `docs/TEST_RUN_LEDGER.md` and `docs/TESTING.md`.
- Choose the smallest risk-based check:
  - **Quick**: Text/layout edits -> relevant analysis / single widget test.
  - **Feature**: Functional edits -> targeted feature test suite (preview via `tools/dev/verify.ps1 -Feature <name> -Mode Feature -Plan`).
  - **Critical**: Schema, persistence, sync, alarms, encryption -> isolation fixtures, migration roundtrips, atomic CAS CAS checks.
  - **Release**: Packaging, Inno Setup, APK alignment, signed update manifests.
- **No Test Invention**: Never claim tests passed if they were not run or were skipped. Record historical reuse accurately by referencing commit SHA and receipt.

### 4. Domain Invariant Protection & Test Expectation Integrity
- **Identify Domain Invariants First**: Before writing or altering code, identify the inviolable domain invariants (e.g. event duration invariance under a move gesture, task deadline independence from scheduled date).
- **Challenge Pre-Existing and New Test Assertions**: Passing tests can institutionalize corruption if they assert flawed expectations. Never assume a test expectation is valid simply because it exists or matches current runtime output.
- **Differentiate UI Presentation from Persistence**: Display boundaries (e.g., clipping an event visually at midnight in a day-view column) must never mutate, clamp, or truncate underlying persisted records.
- **Pre-Fix Failing Test Discipline**: When fixing a defect, first verify that the regression test fails against the unpatched behavior, then verify that it cleanly passes once the invariant is restored.
