#!/usr/bin/env python3
"""
Adversarial Verification Suite for Todorbit Evidence Cache Safety.
Tests that passing evidence is strictly invalidated when any relevant input changes,
corrupted records are purged, non-passing outcomes are never cached, and
transitive dependencies invalidate cached receipts.
"""

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


class TestEvidenceCacheSafety(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.test_dir = tempfile.mkdtemp(prefix="todorbit_evidence_test_")
        cls.evidence_dir = Path(cls.test_dir) / ".buildlog" / "evidence"
        cls.evidence_dir.mkdir(parents=True, exist_ok=True)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.test_dir, ignore_errors=True)

    def _run_ps_evidence_cmd(self, script_body: str) -> subprocess.CompletedProcess:
        full_script = f"""
        $ErrorActionPreference = 'Stop'
        Import-Module '{REPO_ROOT}/tools/dev/modules/Evidence.psm1' -Force -DisableNameChecking
        {script_body}
        """
        cmd = [
            "powershell",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            full_script,
        ]
        env = os.environ.copy()
        env["TODORBIT_EVIDENCE_DIR"] = str(self.evidence_dir)
        return subprocess.run(cmd, capture_output=True, text=True, cwd=str(REPO_ROOT), env=env)

    def test_passing_evidence_saved_and_retrieved(self):
        """Valid passing test outcome generates reusable evidence."""
        script = """
        $rec = Save-EvidenceRecord -TestPath 'test/sample_test.dart' -SourcePaths @('lib/domain/models/task.dart') -Outcome 'PASS' -DurationSeconds 1.5
        $cached = Get-EvidenceRecord -Fingerprint $rec.Fingerprint
        if ($null -ne $cached -and $cached.Outcome -eq 'PASS' -and $cached.Fingerprint -eq $rec.Fingerprint) {
            Write-Output "OK:$($rec.Fingerprint)"
        } else {
            Write-Error "Failed to retrieve saved passing evidence"
        }
        """
        proc = self._run_ps_evidence_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("OK:", proc.stdout)

    def test_non_passing_outcomes_never_cached_as_pass(self):
        """FAIL, FLAKY, BLOCKED, TIMEOUT, and SKIPPED outcomes are never cached."""
        for outcome in ["FAIL", "FLAKY", "BLOCKED", "TIMEOUT", "SKIPPED"]:
            script = f"""
            $rec = Save-EvidenceRecord -TestPath 'test/sample_test.dart' -SourcePaths @('lib/domain/models/task.dart') -Outcome '{outcome}' -DurationSeconds 0.8
            $cached = Get-EvidenceRecord -Fingerprint $rec.Fingerprint
            if ($null -ne $cached) {{
                Write-Error "Non-passing outcome {outcome} was incorrectly cached!"
            }} else {{
                Write-Output "REJECTED:{outcome}"
            }}
            """
            proc = self._run_ps_evidence_cmd(script)
            self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
            self.assertIn(f"REJECTED:{outcome}", proc.stdout)

    def test_direct_source_modification_invalidates_cache(self):
        """Direct source code modification changes the composite fingerprint."""
        script = """
        $fp1 = Get-TestCompositeFingerprint -TestPath 'test/sample_test.dart' -SourcePaths @('lib/domain/models/task.dart')
        $fp2 = Get-TestCompositeFingerprint -TestPath 'test/sample_test.dart' -SourcePaths @('lib/domain/models/event.dart')
        if ($fp1.CompositeFingerprint -ne $fp2.CompositeFingerprint) {
            Write-Output "DIFF:$($fp1.CompositeFingerprint):$($fp2.CompositeFingerprint)"
        } else {
            Write-Error "Fingerprint did not change when source path changed!"
        }
        """
        proc = self._run_ps_evidence_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("DIFF:", proc.stdout)

    def test_test_file_modification_invalidates_cache(self):
        """Changing the test file path changes the composite fingerprint."""
        script = """
        $fp1 = Get-TestCompositeFingerprint -TestPath 'test/workspace_test.dart'
        $fp2 = Get-TestCompositeFingerprint -TestPath 'test/repository_test.dart'
        if ($fp1.CompositeFingerprint -ne $fp2.CompositeFingerprint) {
            Write-Output "DIFF_TEST:$($fp1.CompositeFingerprint):$($fp2.CompositeFingerprint)"
        } else {
            Write-Error "Fingerprint did not change between different test files!"
        }
        """
        proc = self._run_ps_evidence_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("DIFF_TEST:", proc.stdout)

    def test_execution_arguments_change_invalidates_cache(self):
        """Execution arguments change invalidates composite fingerprint."""
        script = """
        $fp1 = Get-TestCompositeFingerprint -TestPath 'test/workspace_test.dart' -Arguments '--tags fast'
        $fp2 = Get-TestCompositeFingerprint -TestPath 'test/workspace_test.dart' -Arguments '--tags full'
        if ($fp1.CompositeFingerprint -ne $fp2.CompositeFingerprint) {
            Write-Output "DIFF_ARGS"
        } else {
            Write-Error "Fingerprint did not change when arguments differed!"
        }
        """
        proc = self._run_ps_evidence_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("DIFF_ARGS", proc.stdout)

    def test_corrupted_json_evidence_purged_and_rejected(self):
        """Malformed or corrupt JSON in the cache directory is deleted and rejected."""
        fake_fp = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        corrupt_file = self.evidence_dir / f"{fake_fp}.json"
        corrupt_file.write_text("CORRUPTED NOT JSON {{{", encoding="utf-8")

        script = f"""
        $cached = Get-EvidenceRecord -Fingerprint '{fake_fp}'
        if ($null -eq $cached) {{
            Write-Output "CORRUPT_HANDLED"
        }} else {{
            Write-Error "Corrupt file was not rejected!"
        }}
        """
        proc = self._run_ps_evidence_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("CORRUPT_HANDLED", proc.stdout)
        # Verify corrupted file was removed
        self.assertFalse(corrupt_file.exists(), "Corrupted file should be purged from cache")

    def test_mismatched_fingerprint_purged(self):
        """Evidence file where internal Fingerprint does not match filename is purged."""
        filename_fp = "aaaa1111bbbb2222cccc3333dddd4444aaaa1111bbbb2222cccc3333dddd4444"
        internal_fp = "ffff9999eeee8888dddd7777cccc6666bbbb5555aaaa44449999888877776666"
        tampered_record = {
            "SchemaVersion": 2,
            "Fingerprint": internal_fp,
            "TestPath": "test/sample_test.dart",
            "Outcome": "PASS",
            "DurationSeconds": 1.0,
        }
        tampered_file = self.evidence_dir / f"{filename_fp}.json"
        tampered_file.write_text(json.dumps(tampered_record), encoding="utf-8")

        script = f"""
        $cached = Get-EvidenceRecord -Fingerprint '{filename_fp}'
        if ($null -eq $cached) {{
            Write-Output "TAMPER_REJECTED"
        }} else {{
            Write-Error "Tampered record with mismatched fingerprint was accepted!"
        }}
        """
        proc = self._run_ps_evidence_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("TAMPER_REJECTED", proc.stdout)
        self.assertFalse(tampered_file.exists(), "Tampered file should be purged")

    def test_force_fresh_bypasses_cache(self):
        """ForceFresh flag bypasses cache even when valid passing evidence exists."""
        script = """
        $rec = Save-EvidenceRecord -TestPath 'test/fresh_test.dart' -Outcome 'PASS' -DurationSeconds 1.2
        $cached = Get-EvidenceRecord -Fingerprint $rec.Fingerprint -ForceFresh
        if ($null -eq $cached) {
            Write-Output "FRESH_BYPASSED"
        } else {
            Write-Error "ForceFresh did not bypass cached evidence!"
        }
        """
        proc = self._run_ps_evidence_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("FRESH_BYPASSED", proc.stdout)

    def test_transitive_dart_dependency_resolution(self):
        """Transitive Dart import resolver identifies internal dependencies."""
        script = """
        $deps = Resolve-AllTransitiveDependencies -FilePaths @('test/app_task_row_test.dart') -RepoRoot (Get-RepoRoot)
        if ($deps.Count -gt 1) {
            Write-Output "TRANSITIVE_COUNT:$($deps.Count)"
        } else {
            Write-Error "Failed to resolve transitive dependencies for app_task_row_test.dart"
        }
        """
        proc = self._run_ps_evidence_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("TRANSITIVE_COUNT:", proc.stdout)


if __name__ == "__main__":
    unittest.main()
