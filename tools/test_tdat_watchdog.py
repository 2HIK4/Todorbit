"""Deterministic regression tests for TDAT bounded timeouts, stall watchdogs, checkpoints, and scoped cleanup."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHELL = shutil.which('pwsh') or shutil.which('powershell')


@unittest.skipUnless(os.name == 'nt' and SHELL is not None, 'Windows PowerShell required for TDAT watchdog tests')
class TdatWatchdogTests(unittest.TestCase):
    def test_bounded_process_terminates_stalled_subprocess_tree_and_preserves_scope(self):
        with tempfile.TemporaryDirectory(prefix='todorbit-watchdog-test-') as tmp:
            log_file = Path(tmp) / 'stall.log'
            script = f"""
            $ErrorActionPreference = 'Stop'
            Import-Module '{ROOT}/tools/dev/modules/Session.psm1' -Force -DisableNameChecking
            $pyExe = (Get-Command python).Source
            $res = Invoke-BoundedProcess `
                -FilePath $pyExe `
                -Arguments @('-c', 'import time; time.sleep(30)') `
                -WorkingDirectory '{ROOT}' `
                -LogFile '{log_file}' `
                -TimeoutSeconds 2 `
                -InactivityTimeoutSeconds 2 `
                -RepoRoot '{ROOT}'
            Write-Output ($res | ConvertTo-Json -Depth 4 -Compress)
            """
            proc = subprocess.run(
                [SHELL, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', script],
                cwd=ROOT, capture_output=True, text=True, timeout=30,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)
            payload = json.loads(proc.stdout.strip())
            self.assertEqual(payload['ExitCode'], 124)
            self.assertIn(payload['Status'], ('TIMEOUT', 'STALLED'))
            self.assertTrue(payload['TimedOut'] or payload['Stalled'])
            self.assertIn('[TDAT-WATCHDOG]', log_file.read_text(encoding='utf-8'))

    def test_verify_supports_checkpoint_resume_without_rerunning_passed_suite(self):
        with tempfile.TemporaryDirectory(prefix='todorbit-resume-test-') as tmp:
            temp_dir = Path(tmp)
            marker_a = temp_dir / 'ran_a.txt'
            marker_b = temp_dir / 'ran_b.txt'
            suite_a = ROOT / '.buildlog/temp_suite_a_test.dart'
            suite_b = ROOT / '.buildlog/temp_suite_b_test.dart'
            suite_a.write_text('// synthetic suite A\n', encoding='utf-8')
            suite_b.write_text('// synthetic suite B\n', encoding='utf-8')
            try:
                # Stub flutter.cmd that fails only on suite_b on first run, passes on second
                bin_dir = temp_dir / 'bin'
                bin_dir.mkdir()
                flag_pass = temp_dir / 'pass_b.flag'
                flutter_cmd = bin_dir / 'flutter.cmd'
                flutter_cmd.write_text(f'''@echo off
if "%~1"=="analyze" exit /b 0
echo %* | findstr /C:"temp_suite_a_test.dart" >nul
if %errorlevel%==0 (
  echo ran>>"{marker_a}"
  exit /b 0
)
echo %* | findstr /C:"temp_suite_b_test.dart" >nul
if %errorlevel%==0 (
  echo ran>>"{marker_b}"
  if exist "{flag_pass}" exit /b 0
  exit /b 19
)
exit /b 0
''', encoding='utf-8')
                (bin_dir / 'dart.cmd').write_text('@echo off\nexit /b 0\n', encoding='utf-8')
                env = dict(
                    os.environ,
                    PATH=str(bin_dir) + os.pathsep + os.environ['PATH'],
                    TODORBIT_EVIDENCE_DIR=str(temp_dir / 'evidence'),
                )
                verify_script = str(ROOT / 'tools/dev/verify.ps1')
                first = subprocess.run(
                    [
                        SHELL, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
                        '-Command',
                        f"& '{verify_script}' -Mode Quick -ChangedPaths @('lib/main.dart') -Tests @('.buildlog/temp_suite_a_test.dart', '.buildlog/temp_suite_b_test.dart')",
                    ],
                    cwd=ROOT, env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=60,
                )
                self.assertNotEqual(first.returncode, 0, first.stdout + first.stderr)
                self.assertEqual(len(marker_a.read_text().splitlines()), 1, first.stdout)
                self.assertEqual(len(marker_b.read_text().splitlines()), 1, first.stdout)

                flag_pass.write_text('ok', encoding='utf-8')
                resumed = subprocess.run(
                    [
                        SHELL, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
                        '-Command',
                        f"& '{verify_script}' -Mode Quick -Resume -ChangedPaths @('lib/main.dart') -Tests @('.buildlog/temp_suite_a_test.dart', '.buildlog/temp_suite_b_test.dart')",
                    ],
                    cwd=ROOT, env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=60,
                )
                self.assertEqual(resumed.returncode, 0, resumed.stderr + resumed.stdout)
                # Suite A was checkpointed/reused and NOT re-executed!
                self.assertEqual(len(marker_a.read_text().splitlines()), 1)
                self.assertEqual(len(marker_b.read_text().splitlines()), 2)
                self.assertIn('[REUSED]', resumed.stdout)
            finally:
                for p in (suite_a, suite_b):
                    if p.exists():
                        p.unlink()

    def test_runtime_adb_uses_bounded_watchdog_and_writes_blocker_receipts(self):
        runtime = (ROOT / 'tools/dev/modules/Runtime.psm1').read_text(encoding='utf-8')
        self.assertIn('Invoke-BoundedProcess', runtime)
        self.assertIn('Save-RuntimeBlockerReceipt', runtime)
        session = (ROOT / 'tools/dev/modules/Session.psm1').read_text(encoding='utf-8')
        self.assertIn(r'\\AppData\\Local\\Programs\\Life Manager', session)


if __name__ == '__main__':
    unittest.main()
