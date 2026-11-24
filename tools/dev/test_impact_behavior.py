#!/usr/bin/env python3
"""
Behavioral Verification Suite for Todorbit Intelligent Impact Analysis.
Covers localized feature changes, shared UI, database migrations, platform files,
dependency configs, test infrastructure, unrecognized paths, empty diffs, and shadow mode.
"""

import json
import os
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


class TestImpactBehavior(unittest.TestCase):
    def _run_impact(self, explicit_files: list[str] = None, extra_flags: list[str] = None) -> dict:
        files_arg = ""
        if explicit_files is not None:
            quoted_files = ", ".join(f"'{f}'" for f in explicit_files)
            files_arg = f"-ExplicitFiles @({quoted_files})"
        flags_arg = " ".join(extra_flags) if extra_flags else ""

        script = f"""
        $ErrorActionPreference = 'Stop'
        Import-Module '{REPO_ROOT}/tools/dev/modules/Impact.psm1' -Force -DisableNameChecking
        $res = Invoke-ImpactAnalysis {files_arg} {flags_arg} -Json
        Write-Output $res
        """
        cmd = [
            "powershell",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            script,
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True, cwd=str(REPO_ROOT))
        self.assertEqual(proc.returncode, 0, f"Error running impact: {proc.stderr}")
        return json.loads(proc.stdout.strip())

    def test_empty_diff_returns_zero_selected_tests(self):
        """Empty diff selects 0 tests and reports no affected features."""
        res = self._run_impact(explicit_files=[])
        self.assertEqual(res["ChangedFilesCount"], 0)
        self.assertEqual(res["SelectedTestsCount"], 0)
        self.assertEqual(len(res["SelectedTests"]), 0)

    def test_direct_test_file_selected(self):
        """Editing a test file directly selects that exact test suite."""
        res = self._run_impact(explicit_files=["test/calendar_card_contrast_test.dart"])
        self.assertIn("test/calendar_card_contrast_test.dart", res["SelectedTests"])
        self.assertFalse(res["IsCritical"])

    def test_critical_database_schema_boundary(self):
        """Editing schema or database triggers Level 2 critical persistence tests."""
        res = self._run_impact(explicit_files=["lib/data/app_database.dart"])
        self.assertTrue(res["IsCritical"])
        self.assertIn("test/database_migration_recovery_test.dart", res["SelectedTests"])
        self.assertIn("test/database_initialization_test.dart", res["SelectedTests"])
        self.assertIn("test/migration_gate_test.dart", res["SelectedTests"])

    def test_shared_ui_design_tokens_boundary(self):
        """Editing shared UI tokens or components triggers shared UI quality tests."""
        res = self._run_impact(explicit_files=["lib/features/shared/app_task_row.dart"])
        self.assertTrue(res["IsSharedUI"])
        self.assertIn("test/app_task_row_test.dart", res["SelectedTests"])
        self.assertIn("test/settings_ui_quality_test.dart", res["SelectedTests"])
        self.assertIn("test/lab_render_test.dart", res["SelectedTests"])

    def test_platform_android_boundary(self):
        """Editing Android platform files selects Android platform tests."""
        res = self._run_impact(explicit_files=["android/app/src/main/AndroidManifest.xml"])
        self.assertTrue(res["IsPlatformChange"])
        self.assertIn("Android", res["Platforms"])
        self.assertIn("test/android_platform_test.dart", res["SelectedTests"])

    def test_platform_windows_boundary(self):
        """Editing Windows platform files selects Windows platform and native widget tests."""
        res = self._run_impact(explicit_files=["windows/runner/main.cpp"])
        self.assertTrue(res["IsPlatformChange"])
        self.assertIn("Windows", res["Platforms"])
        self.assertIn("test/native_widget_service_test.dart", res["SelectedTests"])
        self.assertIn("test/desktop_widget_test.dart", res["SelectedTests"])

    def test_dependency_config_boundary(self):
        """Modifying pubspec.yaml triggers dependency configuration fallback tests."""
        res = self._run_impact(explicit_files=["pubspec.yaml"])
        self.assertTrue(res["IsConfigChange"])
        self.assertIn("test/workspace_test.dart", res["SelectedTests"])
        self.assertIn("test/repository_test.dart", res["SelectedTests"])

    def test_test_infrastructure_boundary(self):
        """Modifying verify.ps1 or developer toolkit modules triggers infra safety test."""
        res = self._run_impact(explicit_files=["tools/dev/verify.ps1"])
        self.assertTrue(res["IsInfraChange"])
        self.assertIn("tools/test_process_invocation_safety.py", res["SelectedTests"])

    def test_unrecognized_source_fallback(self):
        """Unmapped or ambiguous paths trigger conservative safety fallback covering persistence, sync, security, platform, and UI."""
        res = self._run_impact(explicit_files=["some_unknown/random_file.txt"])
        for expected in [
            "test/workspace_test.dart",
            "test/mobile_workspace_test.dart",
            "test/repository_test.dart",
            "test/database_initialization_test.dart",
            "test/migration_gate_test.dart",
            "test/task_revision_concurrency_test.dart",
            "test/sync_journal_test.dart",
            "test/sync_apply_repository_test.dart",
            "test/backup_service_test.dart",
            "test/privacy_test.dart",
            "test/profile_isolation_test.dart",
            "test/event_recurrence_test.dart",
            "test/alarm_test.dart",
            "test/android_platform_test.dart",
            "test/native_widget_service_test.dart",
            "test/desktop_widget_test.dart",
            "test/app_task_row_test.dart",
            "tools/test_architecture_boundaries.py",
        ]:
            self.assertIn(expected, res["SelectedTests"], f"Missing fallback coverage: {expected}")
        self.assertGreaterEqual(res["SelectedTestsCount"], 15)

    def test_reverse_dart_dependency_propagation(self):
        """Editing an unmapped core Dart file resolves transitive test dependents."""
        res = self._run_impact(explicit_files=["lib/data/backup_service.dart"])
        self.assertTrue(res["IsCritical"])
        self.assertIn("test/backup_service_test.dart", res["SelectedTests"])
        self.assertIn("test/cross_platform_backup_test.dart", res["SelectedTests"])
        self.assertIn("test/sync_journal_test.dart", res["SelectedTests"])

    def test_deleted_test_file_not_scheduled_for_execution(self):
        """Deleted test files are recorded in DeletedFiles and never scheduled for flutter test."""
        res = self._run_impact(explicit_files=["test/nonexistent_deleted_test.dart"])
        self.assertIn("test/nonexistent_deleted_test.dart", res["DeletedFiles"])
        self.assertNotIn("test/nonexistent_deleted_test.dart", res["SelectedTests"])
        self.assertIn("tools/dev/check-docs.py", res["SelectedTests"])

    def test_docs_only_change_selects_docs_validator(self):
        """Documentation-only changes route to check-docs.py instead of unrelated Flutter tests."""
        res = self._run_impact(explicit_files=["docs/TESTING.md"])
        self.assertEqual(res["SelectedTests"], ["tools/dev/check-docs.py"])

    def test_auto_branch_baseline_detection(self):
        """When explicit files are not provided, impact analysis detects modified files on feature branch."""
        res = self._run_impact()
        self.assertGreater(res["ChangedFilesCount"], 0, "Should detect branch or working tree changes")
        self.assertGreater(res["SelectedTestsCount"], 0, "Should select affected tests")

    def test_verification_shadow_mode(self):
        """Specifying -Shadow generates shadow comparison output with candidate metrics."""
        res = self._run_impact(explicit_files=["lib/features/shared/app_task_row.dart"], extra_flags=["-Shadow"])
        self.assertTrue(res["ShadowMode"])
        shadow_dir = REPO_ROOT / ".buildlog" / "shadow"
        self.assertTrue(shadow_dir.exists())
        shadow_files = sorted(shadow_dir.glob("shadow-*.json"), key=os.path.getmtime, reverse=True)
        self.assertGreater(len(shadow_files), 0, "Shadow record file was created")
        latest_record = json.loads(shadow_files[0].read_text(encoding="utf-8-sig"))
        self.assertIn("TotalCandidates", latest_record)
        self.assertIn("OmittedCandidatesCount", latest_record)
        self.assertGreater(latest_record["TotalCandidates"], 0)

    def test_shadow_execution_detects_missed_failure_and_suggests_rule(self):
        """Real shadow execution (-Execute) runs omitted tests and catches missed failures."""
        import tempfile
        with tempfile.TemporaryDirectory(prefix="todorbit_shadow_stub_") as tmpdir:
            stub = Path(tmpdir) / "shadow_stub.cmd"
            stub.write_text(
                "@echo off\n"
                "echo %* | findstr /C:\"test/missed_failing_test.dart\" >nul\n"
                "if %errorlevel%==0 (\n"
                "  echo Simulated failure in missed_failing_test.dart\n"
                "  exit /b 1\n"
                ")\n"
                "exit /b 0\n",
                encoding="utf-8",
            )
            script = f"""
            $ErrorActionPreference = 'Stop'
            Import-Module '{REPO_ROOT}/tools/dev/modules/Impact.psm1' -Force -DisableNameChecking
            $rep = Invoke-ShadowVerification -SelectedTests @('test/selected_ok_test.dart') `
                -ChangedFiles @('lib/unmapped/foo.dart') `
                -CandidateOverride @('test/selected_ok_test.dart', 'test/omitted_ok_test.dart', 'test/missed_failing_test.dart') `
                -ShadowRunnerCommand '{stub}' -Execute -ShadowScope Full -Json
            Write-Output $rep
            """
            proc = subprocess.run(
                ["powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", script],
                capture_output=True, text=True, cwd=str(REPO_ROOT),
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            report = json.loads(proc.stdout.strip())
            self.assertTrue(report["Executed"])
            self.assertFalse(report["ShadowPassed"])
            self.assertEqual(report["ExecutedShadowTestsCount"], 2)
            missed_paths = [m["TestPath"] for m in report["MissedFailures"]]
            self.assertEqual(missed_paths, ["test/missed_failing_test.dart"])
            self.assertGreater(len(report["SelectionRuleSuggestions"]), 0)
            self.assertEqual(report["SelectionRuleSuggestions"][0]["MissedTest"], "test/missed_failing_test.dart")


if __name__ == "__main__":
    unittest.main()
