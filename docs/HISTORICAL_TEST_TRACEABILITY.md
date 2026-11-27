# Todorbit Historical Test Traceability & Verification Guide

This persistent engineering document establishes full traceability between historical testing procedures, acceptance ledgers, regression reports, and the current automated suites, synthetic fixtures, and deferred verification gates implemented in the Todorbit Developer Automation Toolkit (TDAT).

---

## 1. Traceability Matrix: Historical Procedures to Automated Harness

| Historical Test Procedure | Original Source / Context | Current Automated Suite | Reusable Fixture / Harness Command | Verification Level & Policy |
| :--- | :--- | :--- | :--- | :--- |
| **Recurrence Invariants & Series Expansion** | `docs/TEST_RUN_LEDGER.md`, calendar recurrence audits | [test/calendar_recurrence_invariants_test.dart](../test/calendar_recurrence_invariants_test.dart) | `dev fixture calendar-stress` | **Level 2 (Critical)**: Deterministic property invariants; DST/timezone leap edge cases; forward projection without infinite loops. |
| **Database Schema Forward Migration & Drift** | Drift schema version 27 $\to$ 29 upgrade, crash recovery | [test/database_migration_recovery_test.dart](../test/database_migration_recovery_test.dart) | `dev fixture migration` | **Level 2 (Critical)**: Zero data loss forward migrations; transaction rollback on failure; preservation of legacy columns. |
| **Simulated Network Drops & Sync Convergence** | Google Drive AppData sync, multi-device convergence | [test/sync_simulated_transport_test.dart](../test/sync_simulated_transport_test.dart) | `dev fixture sync-conflict` | **Level 2 (Critical)**: Multi-device CAS revision convergence; network drop tolerance; malformed payload rejection. |
| **Multi-Viewport Responsive Layout & Overflow** | Batch 1/2 UI redesigns, mobile 320dp, 1080p, 150% text | [test/lab_render_test.dart](../test/lab_render_test.dart) | `dev screenshot all` | **Level 1 (Fast)**: Headless offscreen Flutter layout laboratory; 11 viewports and dialogs; checks zero RenderFlex overflows and exports PNGs (no automated pixel-diffing against baseline PNGs). |
| **Modal Reachability & Sample Widget Render** | Mobile touch agenda, modal scroll reachability | [test/lab_render_test.dart](../test/lab_render_test.dart) (`modal-shell`, `accessibility`) | `dev screenshot modal-shell-scroll-reachability` | **Level 1 (Fast)**: Checks scroll reachability in `AppModalShell` and renders a sample `AppTaskRow`; does **not** constitute full screen-reader, TalkBack, Narrator, or WCAG contrast coverage. |
| **Isolated Profile SQLite Persistence (Test Harness)** | Batch 5 profile journeys, portable data isolation | [test/runtime_workflow_journey_test.dart](../test/runtime_workflow_journey_test.dart) | `dev runtime windows` | **Level 2 (Test Harness)**: Exercises SQLite CRUD, `db.close()`, and file reopen in isolated `APPDATA`/`LOCALAPPDATA`; does **not** launch `Todorbit.exe`, drive live UI, or restart an OS process. |
| **Live Windows Process Launch, UI & Restart** | Desktop UI driver workflows | [test_driver/windows_runtime_workflow_test.dart](../test_driver/windows_runtime_workflow_test.dart) | `dev runtime windows -LiveApp -BuildLiveApp` | **Level 3/4 (Live Debug Driver)**: Launches real `Todorbit.exe` in isolated profile, creates a task via `FlutterDriver` UI taps, exits, and restarts a second process to verify persisted UI rendering. |
| **Android 16 KiB Page Size Runtime Acceptance** | Android 15/16 ABI compliance, memory mapping | [tools/android-16k-runtime.py](../tools/android-16k-runtime.py) | `dev runtime android` | **Level 4 (Release Acceptance)**: Real emulator execution (`emulator-5554`); UIAutomator accessibility tree dumps; reports `BLOCKED` when emulator is absent. |
| **Native Windows Companion Self-Test** | C# Win32 companion, `%APPDATA%\TodoPilot` isolation | [tools/dev/native-self-test.ps1](../tools/dev/native-self-test.ps1) | `tools/dev/native-self-test.ps1` | **Level 2 (Critical)**: Dedicated process start with isolated roaming/local profile; verifies IPC and database reading. |
| **Release Package PE Headers & Inno Setup** | Installer validation, x64 architecture, debug CRT | [tools/verify-windows-artifact.py](../tools/verify-windows-artifact.py) | `dev package Windows` | **Level 4 (Release Acceptance)**: Validates binary PE architecture (Machine 0x8664), non-debug runtime, Inno Setup syntax. |
| **PowerShell Process Invocation Non-Interactivity** | Windows "Pick an app" (`OpenWith.exe`) trigger defect | [tools/test_process_invocation_safety.py](../tools/test_process_invocation_safety.py) | `python tools/test_process_invocation_safety.py` | **Level 1 (Fast)**: Asserts `-NonInteractive` on PowerShell invocations and explicit extensions (`flutter.bat`, `dart.exe`). |
| **Adversarial Evidence Cache Safety** | Source-aware verification evidence reuse & corruption | [tools/dev/test_evidence_cache_safety.py](../tools/dev/test_evidence_cache_safety.py) | `python tools/dev/test_evidence_cache_safety.py` | **Level 2 (Critical)**: Transitive dependency hashing; invalidation on source/config/lockfile changes; purge of corrupt/tampered JSON. |
| **Impact Analyzer Boundary Correctness** | Granular test selection and fallback triggers | [tools/dev/test_impact_behavior.py](../tools/dev/test_impact_behavior.py) | `python tools/dev/test_impact_behavior.py` | **Level 1 (Fast)**: Localized feature mapping, critical schema boundaries, shared UI tokens, platform files, and verification shadow mode. |

---

## 2. Reusable Fixture Scenarios

The Developer Automation Toolkit CLI provides deterministic fixture generation via `dev fixture <name>` (`tools/dev/generate_fixture.py`):

1. **`empty`**: Brand new profile with zero records. Verifies first-run initialization and onboarding defaults.
2. **`small`**: 5 tasks, 2 events, 1 category, 1 project. Standard development fixture.
3. **`typical`**: 50 tasks across various statuses (notStarted, inProgress, completed, cancelled), 15 calendar events, 5 categories, 3 projects. Used for realistic UI layout rendering and responsive testing.
4. **`large`**: 1,000 tasks, 200 events, 20 categories, 15 projects. Stresses query indexing, list virtualization, and memory boundaries.
5. **`calendar-stress`**: 100 dense overlapping events, multi-day spans, and recurring rules. Used for calendar time-grid rendering and conflict detection.
6. **`sync-conflict`**: Two simulated devices with diverging CAS tokens and conflicting edits. Used for convergence validation.
7. **`migration`**: Legacy SQLite schema version 27. Used to verify forward migration to schema 29 upon database opening.

---

## 3. Manual Verification Procedures (When Hardware/Environment is Unavailable)

Where full automation is blocked by environmental constraints (such as physical hardware or credentials), execute the following verified manual procedures:

### A. Physical Android Device Touch & DPI Verification
- **Preconditions**: Physical Android 14+ device connected via USB with Developer Mode enabled.
- **Procedure**:
  1. Build debug APK: `flutter.bat build apk --debug`.
  2. Install on device: `adb -d install -r build/app/outputs/flutter-apk/app-debug.apk`.
  3. Verify touch targets: Confirm all icon buttons, checkboxes, and tabs are $\ge 48 \times 48$ dp.
  4. Verify keyboard insets: Open Task Editor; tap Notes; verify keyboard does not obscure Save or Cancel buttons.
  5. Text scaling: Set system font size to "Largest" (150%); verify zero text clipping in today workspace.

### B. Windows Native Widget Flyout & Shell Integration
- **Preconditions**: Windows 11 desktop, native companion built (`build/windows/x64/runner/Release/TodorbitWidget.exe`).
- **Procedure**:
  1. Launch isolated companion: `powershell -NoProfile -File tools/dev/native-self-test.ps1`.
  2. Verify shell attachment: Confirm widget attaches to Windows notification area / taskbar corner without stealing window focus.
  3. Verify IPC: Create task in Flutter; observe companion renders updated title within 500ms.
  4. Consult checklist: Follow [docs/windows-widget.md](windows-widget.md).

### C. Real Google OAuth & Drive Synchronization
- **Preconditions**: Valid Google Cloud credentials configured in developer settings.
- **Procedure**:
  1. In Settings $\to$ Sync, initiate Google Account authorization.
  2. Verify consent screen opens in system browser without URI handler warnings.
  3. Trigger initial snapshot sync: Confirm backup file appears in Google Drive `appDataFolder`.
  4. Disconnect network: Confirm app transitions cleanly to offline mode with pending change badge.
  5. Reconnect network: Confirm sync journal flushes changes and recovers CAS lease.

---

## 4. Verification Gate Alignment

- **Level 1 (Fast)**: Executed locally via `dev verify quick` / `dev verify changed`. Reuses 4-fingerprint evidence cache.
- **Level 2 (Critical)**: Data safety, schema migrations, recurrence invariants, CAS sync, runtime workflow journeys. Never deferred.
- **Level 3 (Deferred Regression)**: Broad host suites, multi-module integration, recorded in [docs/DEFERRED_VERIFICATION.md](DEFERRED_VERIFICATION.md).
- **Level 4 (Release Acceptance)**: Installer signing, PE binary architecture, Android 16 KiB runtime, physical device checks. Mandatory before release publication.
