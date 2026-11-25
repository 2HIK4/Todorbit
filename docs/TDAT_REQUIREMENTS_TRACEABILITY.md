# Todorbit Developer Automation Toolkit (TDAT) - Requirements Traceability Matrix

**Date:** 2026-11-24  
**Branch:** `feature/todorbit-developer-toolkit`  
**Baseline Commit:** `7ede8890cc1216cf70b6dfa1454cb1ab45b53cd2`  
**Status:** Safety-hardened; known hardware/OS/runtime gates tracked explicitly below.

---

## 1. Classification Legend

- **VERIFIED**: Implemented, backed by automated tests, and verified with reproducible evidence.
- **PARTIAL**: Core implementation or harness exists, with documented scope limits or optional deeper modes.
- **BLOCKED**: Requires external hardware, authorized 16 KiB emulator, candidate APK, or signing credentials (reported honestly without fake claims).

---

## 2. Requirements Traceability & Status

| ID | Mission Requirement | Status | Source Location | Test / Verification File | Verification Evidence & Honest Limits |
| :--- | :--- | :---: | :--- | :--- | :--- |
| **REQ-01** | Concurrent worktree isolation & baseline recording | **VERIFIED** | `.git/worktrees`, `AGENTS.md` | `git worktree list`, `docs/DEVELOPER_TOOLKIT_AUDIT_2026_11_24.md` | Baseline `7ede889` isolated from Codex worktrees (`feature/todorbit-ui-redesign-2`, `feature/todorbit-beta27-refinement`). |
| **REQ-02** | Comprehensive infrastructure audit | **VERIFIED** | `docs/DEVELOPER_TOOLKIT_AUDIT_2026_11_24.md` | `tools/dev/check-docs.py` | Baseline inventory committed in `7c192f8`. |
| **REQ-03** | Unified Developer CLI (`dev`) | **VERIFIED** | `dev.cmd`, `dev.ps1`, `tools/dev/dev.ps1` | `tools/dev/test_toolkit_self.ps1` | Dispatches core, verification, lab, diagnostics, runtime, and benchmark commands cleanly. |
| **REQ-04** | Centralized test registry indexing 100% of tests | **VERIFIED** | `tools/dev/modules/Registry.psm1`, `tools/dev/registry.json` | `dev registry --validate`, `tools/test_registry_sync.py` | 225 executable suites indexed (210 Dart unit/widget + 3 integration + 12 tool checks); enforces cache-ineligibility invariants on regeneration. |
| **REQ-05** | Windows "Pick an app" OpenWith defect fix | **VERIFIED** | `tools/dev/modules/Doctor.psm1` (`Resolve-TodorbitTool`) | `tools/test_process_invocation_safety.py` | Resolves explicit `.bat`/`.exe` (and `adb.exe`), caches toolchain hash, enforces `-NonInteractive`. |
| **REQ-06** | Conservative impact analysis & shadow execution | **VERIFIED** | `tools/dev/modules/Impact.psm1` | `tools/dev/test_impact_behavior.py` | Handles committed/staged/unstaged/deleted/renamed/untracked changes, reverse Dart dependencies, broad unmapped fallbacks, and real `-Execute` shadow checks (`dev verify changed -Shadow`). |
| **REQ-07** | Source-aware evidence cache (4-fingerprint) | **VERIFIED** | `tools/dev/modules/Evidence.psm1`, `tools/dev/dev.ps1` | `tools/dev/test_evidence_cache_safety.py` | Wired into `dev verify changed`; hashes transitive Dart imports, lockfile, toolchain, env, config, and arguments; rejects mid-run mutations, non-Dart/env-gated tests, and registry tampering. |
| **REQ-08** | AI feature context packs (`dev context`) | **VERIFIED** | `tools/dev/modules/Harness.psm1`, `tools/dev/feature_contexts.json` | `dev context calendar`, `dev context time-tracking` | Curated context packs for all 23 registered features in `tools/dev/features.json`. |
| **REQ-09** | Compact repository map (`dev repomap`) | **VERIFIED** | `tools/dev/modules/Harness.psm1` | `dev repomap` | Metrics dynamically aligned with `registry.json` and `features.json` (23 features). |
| **REQ-10** | Persistent agent handoff (`dev handoff`) | **VERIFIED** | `tools/dev/modules/Harness.psm1` | `dev handoff`, `dev handoff --resume` | Serializes branch, commit, dirty files, impact analysis, and pending checks into `.buildlog/handoffs/latest.json` (UTF-8 no BOM). |
| **REQ-11** | Calendar recurrence invariants test | **VERIFIED** | `lib/domain/recurrence.dart` | `test/calendar_recurrence_invariants_test.dart` | 6 property-based tests covering intervals, month-end clamping, leap years, and monotonicity. |
| **REQ-12** | Database forward migration recovery test | **VERIFIED** | `lib/data/app_database.dart`, `lib/data/migration_gate.dart` | `test/database_migration_recovery_test.dart` | Automated step-up from schema 27 $\to$ 29 with data preservation and future schema protection. |
| **REQ-13** | Simulated cloud sync transport test | **VERIFIED** | `lib/data/cloud/sync_engine.dart` | `test/sync_simulated_transport_test.dart` | 4 simulated transport tests (not live Google OAuth/Drive). |
| **REQ-14** | Deterministic synthetic fixture generator | **VERIFIED** | `tools/dev/generate_fixture.py`, `tools/dev/modules/Fixtures.psm1` | `dev fixture <name>` | 7 deterministic fixture scenarios (`empty`, `small`, `typical`, `large`, `calendar-stress`, `sync-conflict`, `migration`). |
| **REQ-15** | Headless offscreen layout screenshot lab | **PARTIAL** | `test/lab_render_test.dart`, `tools/dev/modules/Lab.psm1` | `dev screenshot all` | Verifies 11 offscreen scenarios with 0 RenderFlex overflows and exports PNGs. **Limits**: no automated pixel-diff baseline comparison; `accessibility-semantics-inspection` only checks widget presence, not full screen-reader/WCAG contrast audits. |
| **REQ-16** | Windows runtime verification (Harness vs Live App) | **PARTIAL** | `tools/dev/modules/Runtime.psm1`, `test/runtime_workflow_journey_test.dart`, `test_driver/windows_runtime_workflow_test.dart` | `dev runtime windows` / `dev runtime windows -LiveApp` | Default `dev runtime windows` passes Flutter test-harness SQLite persistence (`NativeAppProcessLaunched=false`). Live `Todorbit.exe` UI interaction + real OS process restart (`-LiveApp -BuildLiveApp`) is implemented and reports `BLOCKED` on hosts with Windows Developer Mode disabled (`Building with plugins requires symlink support`). |
| **REQ-17** | Android 16 KiB emulator runtime automation | **BLOCKED** | `tools/dev/modules/Runtime.psm1`, `tools/android-16k-runtime.py` | `dev runtime android` | Resolves `adb.exe` and inspects emulator/APK preconditions; currently **BLOCKED** unless an authorized API 36 16 KiB emulator (`PAGE_SIZE=16384`), `.buildlog/16k-runtime/candidate.apk`, and `APK_SHA256` are provided. |
| **REQ-18** | Multi-worktree cross-session resource locking | **VERIFIED** | `tools/dev/modules/Session.psm1` | `tools/dev/test_session_locking_safety.py` | Cross-worktree coordination in `%TEMP%\todorbit_global_locks`, RAM monitoring, and path traversal safety. |
| **REQ-19** | Failure diagnostics & reproduction commands | **VERIFIED** | `tools/dev/modules/Diagnostics.psm1`, `tools/dev/dev.ps1` | `dev diagnose last`, `dev reproduce` | Extracts failure stack trace and reproduction command when `dev verify changed` fails. |
| **REQ-20** | Windows PE and Android package verification | **PARTIAL** | `tools/verify-windows-artifact.py`, `tools/dev/modules/Reliability.psm1` | `dev package Windows` | Audits Inno Setup config and existing x64 PE binaries when built (`Release` binary required for full binary scan; Android check only inspects manifest/tooling unless APK exists). |
| **REQ-21** | Empirical performance benchmarking | **PARTIAL** | `tools/dev/modules/Benchmarks.psm1`, `test/performance_benchmark_test.dart` | `dev benchmark all` | Records single-pass widget-test timings and RSS deltas; does **not** prove absence of memory leaks or Release-mode runtime performance. |
| **REQ-22** | Deep behavioral self-test & CI enforcement | **VERIFIED** | `tools/dev/test_toolkit_self.ps1`, `.github/workflows/ci.yml`, `.github/workflows/windows-ci.yml` | `dev self-test`, `tools/test_registry_sync.py` | 16 self-tests locally; Ubuntu CI enforces `test_registry_sync.py` + `test_process_invocation_safety.py`; Windows CI enforces all 5 TDAT safety suites. |
| **REQ-23** | Permanent automation-first policy codification | **VERIFIED** | `AGENTS.md`, `.agents/skills/todorbit-engineering-quality/SKILL.md`, `README.md` | `tools/dev/check-docs.py` | TDAT workflow, registry maintenance, and non-interactive safety codified across docs and skills. |
| **REQ-24** | Comprehensive documentation manual | **VERIFIED** | `docs/DEVELOPER_AUTOMATION_TOOLKIT.md`, `docs/HISTORICAL_TEST_TRACEABILITY.md` | `tools/dev/check-docs.py` | CLI manual, diagnostics playbook, and honest capability boundaries documented. |
