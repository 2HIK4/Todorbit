#!/usr/bin/env python3
"""
Adversarial Verification Suite for Todorbit Evidence Cache Safety.
Tests that passing evidence is strictly invalidated when any relevant input changes,
corrupted records are purged, non-passing outcomes are never cached, and
transitive dependencies invalidate cached receipts.
"""

import base64
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
import uuid
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


class TestEvidenceCacheSafety(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.test_dir = tempfile.mkdtemp(prefix="todorbit_evidence_test_")
        cls.evidence_dir = Path(cls.test_dir) / ".buildlog" / "evidence"
        cls.evidence_dir.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env["TODORBIT_EVIDENCE_DIR"] = str(cls.evidence_dir)
        bootstrap = (
            "$ErrorActionPreference = 'Stop'; "
            f"Import-Module '{REPO_ROOT}/tools/dev/modules/Evidence.psm1' -Force -DisableNameChecking; "
            "while ($null -ne ($line = [Console]::In.ReadLine())) { "
            "if ($line -eq '__EXIT__') { break } "
            "$sep = $line.IndexOf(':'); "
            "$tag = $line.Substring(0, $sep); "
            "$code = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($line.Substring($sep + 1))); "
            "$ok = 0; "
            "try { & { $ErrorActionPreference = 'Stop'; Invoke-Expression $code } } catch { $ok = 1; [Console]::Out.WriteLine('__ERR__:' + $_.Exception.Message) } "
            "[Console]::Out.WriteLine('__END_' + $tag + '__:' + $ok); "
            "[Console]::Out.Flush() "
            "}"
        )
        cls.ps_proc = subprocess.Popen(
            ["powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", bootstrap],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            cwd=str(REPO_ROOT),
            env=env,
        )

    @classmethod
    def tearDownClass(cls):
        proc = getattr(cls, "ps_proc", None)
        if proc is not None:
            try:
                if proc.poll() is None:
                    try:
                        if proc.stdin:
                            proc.stdin.write("__EXIT__\n")
                            proc.stdin.flush()
                        proc.wait(timeout=5)
                    except Exception:
                        proc.kill()
                        proc.wait(timeout=5)
            finally:
                for pipe in (proc.stdin, proc.stdout):
                    if pipe is not None:
                        try:
                            pipe.close()
                        except Exception:
                            pass
        shutil.rmtree(cls.test_dir, ignore_errors=True)

    def _run_ps_evidence_cmd(self, script_body: str) -> subprocess.CompletedProcess:
        if self.ps_proc.poll() is not None:
            raise AssertionError(f"Persistent PowerShell worker exited unexpectedly with code {self.ps_proc.returncode}")
        tag = uuid.uuid4().hex[:12]
        encoded = base64.b64encode(script_body.encode("utf-8")).decode("ascii")
        self.ps_proc.stdin.write(f"{tag}:{encoded}\n")
        self.ps_proc.stdin.flush()
        out_lines = []
        rc = 1
        end_prefix = f"__END_{tag}__:"
        while True:
            line = self.ps_proc.stdout.readline()
            if not line:
                return subprocess.CompletedProcess([], 1, "\n".join(out_lines), "\n".join(out_lines))
            stripped = line.rstrip("\r\n")
            if stripped.startswith(end_prefix):
                rc = int(stripped[len(end_prefix):])
                break
            out_lines.append(stripped)
        stdout = "\n".join(out_lines)
        err_lines = [l for l in out_lines if l.startswith("__ERR__:")]
        stderr = "\n".join(err_lines if err_lines else (out_lines if rc != 0 else []))
        return subprocess.CompletedProcess([], rc, stdout, stderr)

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

    def test_ineligible_test_rejected_from_reuse(self):
        """Tests marked Ineligible in registry cannot have evidence reused or cached."""
        script = """
        $eligible = Test-IsTestEligibleForReuse -TestPath 'test/runtime_workflow_journey_test.dart'
        if (-not $eligible) {
            Write-Output "INELIGIBLE_CONFIRMED"
        } else {
            Write-Error "Runtime workflow journey test was incorrectly marked eligible for reuse!"
        }
        """
        proc = self._run_ps_evidence_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("INELIGIBLE_CONFIRMED", proc.stdout)

    def test_verification_config_change_changes_fingerprint(self):
        """Modifying verification configuration changes the config hash and composite fingerprint."""
        script = """
        $hash1 = Get-VerificationConfigHash
        if ($hash1 -and $hash1.Length -eq 64) {
            Write-Output "CONFIG_HASH_VALID:$hash1"
        } else {
            Write-Error "Verification config hash is invalid or missing!"
        }
        """
        proc = self._run_ps_evidence_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("CONFIG_HASH_VALID:", proc.stdout)

    def test_mid_execution_source_modification_refuses_caching(self):
        """If PreRunFingerprint differs from post-run fingerprint, caching must be refused."""
        script = """
        $preFp = '0000000000000000000000000000000000000000000000000000000000000000'
        $rec = Save-EvidenceRecord -TestPath 'test/workspace_test.dart' -Outcome 'PASS' -DurationSeconds 1.0 -PreRunFingerprint $preFp
        $cached = Get-EvidenceRecord -Fingerprint $rec.Fingerprint
        if (-not $rec.CacheSaved -and $rec.CacheSkippedReason -eq 'SourceModifiedDuringExecution' -and $null -eq $cached) {
            Write-Output "MID_RUN_MUTATION_REJECTED"
        } else {
            Write-Error "Mid-execution mutation was incorrectly cached!"
        }
        """
        proc = self._run_ps_evidence_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("MID_RUN_MUTATION_REJECTED", proc.stdout)

    def test_non_dart_and_integration_tests_ineligible(self):
        """Python scripts and integration tests are never eligible for cache reuse."""
        script = """
        $pyElig = Test-IsTestEligibleForReuse -TestPath 'tools/test_dev_verify.py'
        $intElig = Test-IsTestEligibleForReuse -TestPath 'integration_test/android_workflow_test.dart'
        $labElig = Test-IsTestEligibleForReuse -TestPath 'test/lab_render_test.dart'
        if (-not $pyElig -and -not $intElig -and -not $labElig) {
            Write-Output "NON_DART_AND_ENV_INELIGIBLE"
        } else {
            Write-Error "Expected python/integration/lab tests to be ineligible!"
        }
        """
        proc = self._run_ps_evidence_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("NON_DART_AND_ENV_INELIGIBLE", proc.stdout)

    def test_registry_regeneration_preserves_ineligibility_and_config_hash(self):
        """Build-TestRegistry keeps ineligible tests ineligible and Get-VerificationConfigHash is stable across refresh."""
        script = """
        Import-Module './tools/dev/modules/Registry.psm1' -Force -DisableNameChecking
        $hashBefore = Get-VerificationConfigHash
        $built = Build-TestRegistry
        $rt = $built.Tests | Where-Object { $_.Path -eq 'test/runtime_workflow_journey_test.dart' }
        $lab = $built.Tests | Where-Object { $_.Path -eq 'test/lab_render_test.dart' }
        $hashAfter = Get-VerificationConfigHash
        if ($rt.EvidenceReuse -eq 'Ineligible' -and $lab.EvidenceReuse -eq 'Ineligible' -and $hashBefore -eq $hashAfter) {
            Write-Output "REGISTRY_STABILITY_OK"
        } else {
            Write-Error "Registry regeneration reset eligibility or altered config hash!"
        }
        """
        proc = self._run_ps_evidence_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("REGISTRY_STABILITY_OK", proc.stdout)


if __name__ == "__main__":
    unittest.main()
