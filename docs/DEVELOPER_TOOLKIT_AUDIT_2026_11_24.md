# Todorbit Developer Automation Toolkit & AI Engineering Harness: Comprehensive Infrastructure Audit

**Date:** 2026-11-24  
**Author:** Todorbit Engineering (Antigravity)  
**Baseline Commit:** `7ede8890cc1216cf70b6dfa1454cb1ab45b53cd2` (HEAD of `feature/todorbit-ui-redesign-2`)  
**Worktree:** `D:/AI_Projects/life_manager`  
**Branch:** `feature/todorbit-developer-toolkit`  
**Status:** Audit complete. Worktree isolation verified. Concurrent Codex development protected.

---

## 1. Executive Summary and Baseline Selection

Todorbit is an offline-first Flutter productivity application targeting Windows 10/11 desktop and Android mobile.
This audit assesses all existing engineering infrastructure, scripts, test suites, architecture rules, CI workflows, and documentation to establish the foundation for the **Todorbit Developer Automation Toolkit (TDAT)** and **AI Engineering Harness**.

### Baseline Commit Selection
- **Selected Baseline:** `7ede8890cc1216cf70b6dfa1454cb1ab45b53cd2`
- **Subject:** `Scroll Android integration agenda before opening event`
- **Rationale:** This commit represents the exact tip of `feature/todorbit-ui-redesign-2` in the repository `C:/Users/User/Documents/Codex/Todorbit-redesign-source`. It incorporates:
  - All 5 batches of UI Redesign 2.0 (`bb37558` through `2227ff0`).
  - Batch 5 and full app-wide acceptance records (`aac266d`, `2f4c18a`).
  - Beta 27 release candidate preparation (`50f5652`).
  - Integration test agenda scrolling stabilization (`7ede889`).
- **Concurrent Development Isolation:**
  - The active Codex session owns worktree `C:/Users/User/.codex/worktrees/todorbit-ui-redesign/Todorbit-redesign-source` with uncommitted files (`AGENTS.md`, `README.md`, `docs/TODORBIT_BETA_27_CANDIDATE.md`).
  - The toolkit operates in a strictly isolated dedicated worktree at `D:/AI_Projects/life_manager` on branch `feature/todorbit-developer-toolkit`.
  - Zero modification, resets, or interaction will occur on Codex worktree files or release signing artifacts.

---

## 2. Infrastructure Inventory

### 2.1 Existing Capabilities to Reuse Unchanged
1. **Verification Core (`tools/dev/verify.ps1`):**
   - Clean execution pipeline capturing stdout/stderr per step into `.buildlog/verify/<timestamp>/`.
   - Structured JSON result output (`result.json`) with timestamps, tool durations, and exit codes.
   - Integrated steps for `dart format`, `flutter analyze --no-pub`, `flutter test --no-pub`, and `git diff --check`.
2. **Feature Mapping (`tools/dev/features.json`):**
   - Maps 23 functional features to primary source paths and dedicated test files.
3. **Architecture Boundary Enforcement (`tools/test_architecture_boundaries.py`):**
   - 39 automated unit tests verifying layer dependencies (domain vs data vs presentation), direct SQLite access restrictions, UI/service separation, and platform import cleanliness.
4. **Documentation Integrity Validation (`tools/dev/check-docs.py`):**
   - Verifies markdown cross-references, architecture map references, and feature catalog sync.
5. **Windows Plugin Symlink Workaround (`tools/dev/prepare-windows-plugins.ps1`):**
   - Creates NTFS junctions in `windows/flutter/ephemeral/.plugin_symlinks` without requiring Windows Developer Mode privileges.
6. **Isolated Profile Journey Testing (`tools/dev/test-profile-journeys.ps1`):**
   - Runs database initialization, startup recovery, and resource journey tests with disposable APPDATA and pinned SDK binaries.
7. **Native Windows Companion Tools:**
   - `tools/dev/native-self-test.ps1`, `tools/dev/native-command.ps1`, `experiments/widget-shell-probe/`.

### 2.2 Capabilities to Extend
1. **Unified CLI Entrypoint (`tools/dev/verify.ps1` -> `dev` / `tools/dev/dev.ps1`):**
   - Currently, `verify.ps1` has 3 modes (`Quick`, `Feature`, `Full`). `Quick` requires manual specification of `-ChangedPaths` and `-Tests`.
   - Must extend into a unified CLI with subcommands: `help`, `doctor`, `status`, `context`, `impact`, `verify`, `runtime`, `scenario`, `screenshot`, `fixture`, `diagnose`, `reproduce`, `benchmark`, `report`, `cleanup`, `self-test`.
2. **Impact Analysis:**
   - Currently, no automated dependency propagation or changed-file detection exists; agents must manually look up features in `features.json`.
   - Must implement conservative, explainable impact analysis detecting staged/unstaged/untracked changes, resolving Dart import graphs, and selecting minimum sufficient verification scopes (`Quick`, `Changed`, `Feature`, `Platform`, `Full`, `Release`).
3. **Evidence Reuse (Test Caching):**
   - `docs/TEST_RUN_LEDGER.md` documents a 4-fingerprint model (source hash, test hash, dependency lockfile hash, toolchain/environment), but enforcement has been manual.
   - Must automate content-addressed fingerprinting and validation so unchanged suites return `REUSED` instantaneously, saving tokens and machine cycles.
4. **Test Discovery & Registry:**
   - `features.json` lists ~70 test files, whereas the repository contains 219 tests in `test/` and 3 in `integration_test/`.
   - Must establish an automated, validated registry indexing 100% of repository tests with metadata (cost, tier, prerequisites, historical bug ties).
5. **Verification Receipts & Diagnostics:**
   - Must produce concise, machine-readable receipts (`PASS`, `REUSED`, `FAIL`, `BLOCKED`, `TIMEOUT`, `SKIPPED`) with failure extraction and targeted reproduction commands.

### 2.3 Missing Capabilities
1. **Environment Doctor (`dev doctor`):**
   - Automated health checks for Flutter 3.47.7, Dart 3.13.5, MSVC Community 2022, Windows 10 SDK, Android SDK 36, JDK 21 (`C:\Program Files\Android\openjdk\jdk-21.0.8`), memory/disk limits, lock contention, and abandoned test profiles.
2. **Session Ownership & Resource Locking (`dev session`, `dev cleanup`):**
   - Mutex/file locks preventing simultaneous Flutter compilation, emulator runs, or background jobs on the 16 GB laptop. Safe bounded cleanup with path-traversal prevention.
3. **AI Engineering Navigation & Context Packs (`dev context <feature>`, `dev repomap`):**
   - Deterministic context generator providing compact summaries of files, entrypoints, design rules, known regressions, and relevant skills without expensive AI indexing.
4. **Deterministic Synthetic Fixture Generator (`dev fixture <name>`):**
   - Reproducible generators for empty, small, typical, large, calendar-stress, recurrence-conflict, and migration workspaces with fixed seeds.
5. **Visual Regression & Layout Lab (`dev screenshot <scenario>`):**
   - Headless offscreen Flutter rendering for responsive viewports (desktop vs 320 dp mobile), 150% text scale, light/dark themes, and screenshot diffing.
6. **Reliability & Fault-Injection Laboratory:**
   - Automated fault-injection verifying SQLite write interruption, simulated network disconnects during sync, CAS token conflicts, and backup recovery.
7. **Performance Benchmarking (`dev benchmark`):**
   - Automated measurement of startup latency, memory footprints, calendar rendering under 1,000 events, and search latency.
8. **Permanent Automation-First Engineering Policy:**
   - Explicit agent workflow codified in `AGENTS.md` and repository skills.

---

## 3. Coverage Gaps and Recoverable Testing Work

### 3.1 Recoverable Historical Testing Procedures
- **Manual Download / Update Verification:** Procedures in `docs/SOFTWARE_UPDATES.md` and `docs/UPDATE_DOWNLOAD_RECOVERY.md` can be automated as offline mock-server integration tests.
- **Calendar Drag/Resize & Recurrence Invariants:** Procedures tested manually during UI Redesign Batch 3 can be codified as automated property-based interaction tests.
- **Multi-Instance Sync Conflict Resolution:** Multi-profile file-system sync tests previously run ad hoc can be standardized into deterministic simulated transport tests.
- **Settings Export / Scoped Import Integrity:** Procedural checks from Batch 5 can be converted into end-to-end roundtrip assertions.

### 3.2 Significant Coverage Gaps
1. **Unregistered Tests:** ~140 unit and widget test files are unmapped in `features.json`.
2. **Property-Based Invariants:** Recurrence scheduling math lacks generative property tests covering leap years, DST shifts, and complex repeat rules.
3. **High-DPI & Text-Scaling Layout:** Automated tests rarely check 150% text scale at 320 dp width outside a few layout tests.
4. **Backward Schema Compatibility:** Need automated migration checks validating schema 27 -> 28 -> 29 data survival.

---

## 4. Safety, Resource, and Environmental Constraints

1. **Host Memory Limit (16 GB RAM):**
   - Compiling Windows release binaries and running Android emulators simultaneously risks system memory exhaustion. The toolkit must enforce concurrency limits and resource locks.
2. **Zero Production Data Mutation:**
   - Absolutely no test or automation script may access `%APPDATA%\TodoPilot`, `%APPDATA%\Life Manager`, or production cloud storage.
   - All tests must redirect `APPDATA`, `LOCALAPPDATA`, and temporary storage to disposable sandbox paths.
3. **Safe Cleanup Rules:**
   - Cleanup must default to dry-run mode.
   - Paths must be validated to strictly reside inside `.buildlog/` or verified disposable profile roots.
   - Directory junctions and symlinks must be safely unlinked without deleting target directories.
4. **Codex Release Protection:**
   - No modifications to `C:/Users/User/.codex/worktrees/todorbit-ui-redesign/Todorbit-redesign-source`.
   - No modification to signing keys, release configurations, or uncommitted Codex work.

---

## 5. Implementation Roadmap

- **Phase 1: Automation Foundation:** Unified CLI (`tools/dev/dev.ps1` and `dev.cmd`), centralized test registry, Environment Doctor, session locking, and toolkit self-tests.
- **Phase 2: Intelligent Verification:** Conservative impact analyzer, source-aware 4-fingerprint evidence reuse, structured verification receipts, and failure reproduction.
- **Phase 3: AI Engineering Harness:** Repository map generator, feature context packs, and regression knowledge retrieval.
- **Phase 4: Test Recovery & Coverage Expansion:** Automation of historical manual checks, unmapped test registration, property-based recurrence tests, and schema migration assertions.
- **Phase 5: Application & UI Laboratory:** Synthetic fixture engine, responsive layout/screenshot runner, accessibility verification.
- **Phase 6: Reliability & Package Verification:** Fault-injection harness, simulated sync transport, installer & APK package verification.
- **Phase 7: Performance & Benchmarking:** Startup and memory benchmark runner, toolkit efficiency metrics.
- **Phase 8: Validation & Policy Consolidation:** Comprehensive toolkit self-tests, AGENTS.md policy consolidation, and final review.
