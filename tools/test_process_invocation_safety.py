"""Regression tests for non-interactive process invocation and executable resolution safety.

Prevents Windows 'Pick an app' (OpenWith) dialogs caused by:
1. Executing extensionless Unix scripts (e.g. flutter, dart) instead of Windows .bat/.exe binaries.
2. Missing -NonInteractive flag in automated PowerShell invocations.
3. Unquoted or comma-joined argument arrays causing shell parameter misbinding.
4. ProcessStartInfo invocations with UseShellExecute=true.
"""
import os
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHELL = shutil.which('pwsh') or shutil.which('powershell')


class ProcessInvocationSafetyTest(unittest.TestCase):
    def test_cli_launchers_enforce_non_interactive_powershell(self):
        """Verify dev.cmd and dev.ps1 pass -NonInteractive to prevent interactive prompts."""
        dev_cmd = (ROOT / 'dev.cmd').read_text(encoding='utf-8')
        dev_ps1 = (ROOT / 'dev.ps1').read_text(encoding='utf-8')

        self.assertIn('-NonInteractive', dev_cmd, "dev.cmd must pass -NonInteractive to powershell.exe")
        self.assertIn('-NonInteractive', dev_ps1, "dev.ps1 must pass -NonInteractive to powershell.exe")

    def test_verify_script_step_passes_non_interactive(self):
        """Verify tools/dev/verify.ps1 Add-ScriptStep uses -NonInteractive."""
        verify_ps1 = (ROOT / 'tools/dev/verify.ps1').read_text(encoding='utf-8')
        self.assertIn('-NonInteractive', verify_ps1, "Add-ScriptStep in verify.ps1 must pass -NonInteractive")

    def test_doctor_avoids_bare_flutter_or_dart_calls(self):
        """Verify Doctor.psm1 invokes flutter/dart via Resolve-TodorbitTool rather than bare commands."""
        doctor_psm1 = (ROOT / 'tools/dev/modules/Doctor.psm1').read_text(encoding='utf-8')
        self.assertNotRegex(doctor_psm1, r'&\s+(?:flutter|dart)\b',
                            "Doctor.psm1 must not invoke bare '& flutter' or '& dart' without Resolve-TodorbitTool")

    @unittest.skipUnless(os.name == 'nt' and SHELL is not None, 'Windows PowerShell required for Windows .bat/.exe resolution test')
    def test_tool_resolution_strictly_avoids_extensionless_files(self):
        """Verify Resolve-TodorbitTool strictly returns .bat or .exe on Windows."""
        ps_command = """
        Import-Module ./tools/dev/modules/Doctor.psm1 -DisableNameChecking -Force
        $flutter = Resolve-TodorbitTool 'flutter'
        $dart = Resolve-TodorbitTool 'dart'
        Write-Output "FLUTTER:$flutter"
        Write-Output "DART:$dart"
        """
        result = subprocess.run([SHELL, '-NoProfile', '-NonInteractive', '-Command', ps_command],
                                cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

        flutter_match = re.search(r'FLUTTER:(.*)', result.stdout)
        dart_match = re.search(r'DART:(.*)', result.stdout)

        self.assertIsNotNone(flutter_match)
        self.assertIsNotNone(dart_match)

        flutter_path = flutter_match.group(1).strip()
        dart_path = dart_match.group(1).strip()

        self.assertTrue(flutter_path.endswith(('.bat', '.cmd', '.exe')),
                        f"Resolved flutter must have executable extension, got: {flutter_path}")
        self.assertTrue(dart_path.endswith(('.bat', '.cmd', '.exe')),
                        f"Resolved dart must have executable extension, got: {dart_path}")

    def test_dev_ps1_uses_native_hashtable_splatting_for_verify(self):
        """Verify dev.ps1 invokes verify.ps1 via native splatting rather than string-joined arguments."""
        dev_script = (ROOT / 'tools/dev/dev.ps1').read_text(encoding='utf-8')
        self.assertIn('& $verifyScript @verifyArgs', dev_script,
                      "dev.ps1 must invoke verify.ps1 using native hashtable splatting to preserve array types")
        self.assertNotIn("($ChangedPaths -join ',')", dev_script,
                         "dev.ps1 must not join ChangedPaths with commas across process boundaries")

    def test_toolchain_hash_is_cached_and_bounded(self):
        """Verify Evidence.psm1 caches toolchain hash and avoids repeated external process calls."""
        evidence_psm1 = (ROOT / 'tools/dev/modules/Evidence.psm1').read_text(encoding='utf-8')
        self.assertIn('$script:CachedToolchainHash', evidence_psm1,
                      "Evidence.psm1 must cache toolchain hash in a script-level variable")
        self.assertIn('Resolve-TodorbitTool', evidence_psm1,
                      "Evidence.psm1 must resolve tools through Resolve-TodorbitTool")


if __name__ == '__main__':
    unittest.main()
