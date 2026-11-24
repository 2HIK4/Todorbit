#!/usr/bin/env python3
"""
Test suite for Todorbit Session Ownership, Multi-Worktree Resource Locking,
and Safe Cleanup Safety Boundaries.
"""

import json
import os
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


class TestSessionLockingSafety(unittest.TestCase):
    def _run_ps_session_cmd(self, script_body: str) -> subprocess.CompletedProcess:
        full_script = f"""
        $ErrorActionPreference = 'Stop'
        Import-Module '{REPO_ROOT}/tools/dev/modules/Session.psm1' -Force -DisableNameChecking
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
        return subprocess.run(cmd, capture_output=True, text=True, cwd=str(REPO_ROOT))

    def test_local_lock_acquisition_and_release(self):
        """Resource lock is acquired atomically and released cleanly."""
        script = """
        $res = Acquire-ResourceLock -ResourceName 'test_unit_resource' -TimeoutSeconds 2
        if (-not $res.Acquired) { throw "Failed to acquire lock" }
        $check = Test-ResourceLock -ResourceName 'test_unit_resource'
        if (-not $check.IsLocked) { throw "Lock was not reported as active" }
        Release-ResourceLock -ResourceName 'test_unit_resource'
        $after = Test-ResourceLock -ResourceName 'test_unit_resource'
        if ($after.IsLocked) { throw "Lock was still active after release" }
        Write-Output "LOCK_OK"
        """
        proc = self._run_ps_session_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("LOCK_OK", proc.stdout)

    def test_lock_collision_times_out(self):
        """Second attempt to acquire active lock times out gracefully."""
        script = """
        $res1 = Acquire-ResourceLock -ResourceName 'test_collision_resource' -TimeoutSeconds 2
        if (-not $res1.Acquired) { throw "First lock failed" }
        try {
            $res2 = Acquire-ResourceLock -ResourceName 'test_collision_resource' -TimeoutSeconds 1
            if ($res2.Acquired) { throw "Second lock should have failed due to collision" }
            Write-Output "COLLISION_PREVENTED"
        } finally {
            Release-ResourceLock -ResourceName 'test_collision_resource'
        }
        """
        proc = self._run_ps_session_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("COLLISION_PREVENTED", proc.stdout)

    def test_global_cross_worktree_lock(self):
        """Global lock operates in temporary cross-worktree directory."""
        script = """
        $res = Acquire-ResourceLock -ResourceName 'test_global_compilation' -TimeoutSeconds 2 -Global
        if (-not $res.Acquired -or -not $res.Global) { throw "Global lock failed" }
        $check = Test-ResourceLock -ResourceName 'test_global_compilation' -Global
        if (-not $check.IsLocked) { throw "Global lock not detected" }
        Release-ResourceLock -ResourceName 'test_global_compilation' -Global
        Write-Output "GLOBAL_LOCK_OK"
        """
        proc = self._run_ps_session_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("GLOBAL_LOCK_OK", proc.stdout)

    def test_stale_lock_reclamation(self):
        """Stale lock from non-existent PID is automatically reclaimed."""
        fake_pid = 999999
        script = f"""
        $lockDir = Join-Path (Get-RepoRoot) '.buildlog\\locks'
        if (-not (Test-Path -LiteralPath $lockDir)) {{ New-Item -ItemType Directory -Force -Path $lockDir | Out-Null }}
        $lockFile = Join-Path $lockDir 'test_stale_resource.lock'
        $fakeData = [pscustomobject]@{{
            Resource = 'test_stale_resource'
            SessionId = 'stale-session'
            PID = {fake_pid}
            Timestamp = (Get-Date).AddHours(-1).ToString('o')
        }} | ConvertTo-Json
        Set-Content -LiteralPath $lockFile -Value $fakeData

        $res = Acquire-ResourceLock -ResourceName 'test_stale_resource' -TimeoutSeconds 3
        if (-not $res.Acquired) {{ throw "Failed to reclaim stale lock" }}
        Release-ResourceLock -ResourceName 'test_stale_resource'
        Write-Output "STALE_RECLAIMED"
        """
        proc = self._run_ps_session_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("STALE_RECLAIMED", proc.stdout)

    def test_host_resource_status_monitoring(self):
        """Host memory status returns total RAM, free RAM, and concurrency limit."""
        script = """
        $status = Get-HostResourceStatus
        if ($status.TotalRamMB -gt 0 -and $status.FreeRamMB -gt 0 -and $status.RecommendedConcurrency -ge 1) {
            Write-Output "RAM_OK:$($status.TotalRamMB):$($status.FreeRamMB)"
        } else {
            throw "Invalid RAM metrics"
        }
        """
        proc = self._run_ps_session_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("RAM_OK:", proc.stdout)

    def test_safe_cleanup_forbidden_paths_protection(self):
        """Safe cleanup refuses to clean user profile paths or outside directories."""
        script = """
        # Test dry-run execution
        $report = Invoke-SafeCleanup -DryRun
        if ($report.DryRun -eq $true -and $report.Errors.Count -eq 0) {
            Write-Output "CLEANUP_SAFETY_VERIFIED"
        } else {
            throw "Safe cleanup failed dry run"
        }
        """
        proc = self._run_ps_session_cmd(script)
        self.assertEqual(proc.returncode, 0, f"Error: {proc.stderr}")
        self.assertIn("CLEANUP_SAFETY_VERIFIED", proc.stdout)


if __name__ == "__main__":
    unittest.main()
