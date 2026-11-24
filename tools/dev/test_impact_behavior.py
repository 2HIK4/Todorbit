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
        """Editing Windows platform files selects Windows platform tests."""
        res = self._run_impact(explicit_files=["windows/runner/main.cpp"])
        self.assertTrue(res["IsPlatformChange"])
        self.assertIn("Windows", res["Platforms"])
        self.assertIn("test/windows_platform_test.dart", res["SelectedTests"])

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
        """Unmapped or ambiguous paths trigger conservative safety fallback."""
        res = self._run_impact(explicit_files=["some_unknown/random_file.txt"])
        self.assertIn("test/workspace_test.dart", res["SelectedTests"])
        self.assertIn("test/repository_test.dart", res["SelectedTests"])

    def test_verification_shadow_mode(self):
        """Specifying -Shadow generates shadow comparison output."""
        res = self._run_impact(explicit_files=["lib/features/shared/app_task_row.dart"], extra_flags=["-Shadow"])
        self.assertTrue(res["ShadowMode"])
        shadow_dir = REPO_ROOT / ".buildlog" / "shadow"
        self.assertTrue(shadow_dir.exists())
        shadow_files = list(shadow_dir.glob("shadow-*.json"))
        self.assertGreater(len(shadow_files), 0, "Shadow record file was created")


if __name__ == "__main__":
    unittest.main()
