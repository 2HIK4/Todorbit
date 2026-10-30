"""Check explicit verification plans and fail-closed command execution."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHELL = shutil.which('pwsh') or shutil.which('powershell')


class CatalogTest(unittest.TestCase):
    def test_local_device_harness_keeps_the_disposable_installation(self):
        harness = (ROOT / 'tools/test-android-update.ps1').read_text()
        self.assertIn("'drive','--keep-app-running'", harness)
        self.assertIn('AllowDebugDowngrade', harness)
        self.assertNotIn("'uninstall'", harness)

    def test_document_routes_and_feature_paths_exist(self):
        spec = importlib.util.spec_from_file_location('doc_check', ROOT / 'tools/dev/check-docs.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertEqual(module.validate(), [])


@unittest.skipUnless(SHELL, 'PowerShell is required for verification helper checks')
class VerifyTest(unittest.TestCase):
    def run_helper(self, *args, env=None):
        return subprocess.run([SHELL, '-NoProfile', '-File', 'tools/dev/verify.ps1', *args],
                              cwd=ROOT, env=env, capture_output=True, text=True)

    def plan(self, *args):
        result = self.run_helper(*args, '-Plan')
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_quick_refuses_to_guess_tests(self):
        result = self.run_helper('-Mode', 'Quick', '-ChangedPaths', 'lib/main.dart', '-Plan')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('tests are never guessed', result.stderr)

    def test_every_feature_plan_uses_its_explicit_tests(self):
        catalog = json.loads((ROOT / 'tools/dev/features.json').read_text())
        for feature, group in catalog.items():
            with self.subTest(feature=feature):
                steps = self.plan('-Mode', 'Feature', '-Feature', feature)
                tests = next(s['arguments'] for s in steps if s['tool'] == 'flutter' and s['arguments'][0] == 'test')
                self.assertTrue(set(group['tests']).issubset(tests))
                self.assertNotIn('test', tests[1:])

    def test_full_includes_independent_suite_and_platform_gates(self):
        steps = self.plan('-Mode', 'Full', '-Platform', 'All', '-Device', 'emulator-5580')
        tests = next(s['arguments'] for s in steps if s['tool'] == 'flutter' and s['arguments'][0] == 'test')
        self.assertIn('test', tests[1:])
        flat = json.dumps(steps)
        for name in ('test-android-update.ps1', 'build-windows-release.ps1', 'native-self-test.ps1', 'test_prepare_android_release.py'):
            self.assertIn(name, flat)
        self.assertNotIn('clean', flat)

    def test_android_requires_explicit_disposable_emulator(self):
        result = self.run_helper('-Mode', 'Full', '-Platform', 'Android', '-Device', 'personal-phone', '-Plan')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('isolated disposable AVD', result.stderr)

    @unittest.skipUnless(os.name == 'nt', 'Uses Windows native-command fixtures')
    def test_failing_selected_tests_stop_the_pipeline(self):
        with tempfile.TemporaryDirectory(prefix='todorbit-verify-command-') as directory:
            directory = Path(directory)
            (directory / 'dart.cmd').write_text('@echo off\nexit /b 0\n')
            (directory / 'flutter.cmd').write_text('@echo off\nif "%1"=="test" exit /b 17\nexit /b 0\n')
            env = dict(os.environ, PATH=str(directory) + os.pathsep + os.environ['PATH'])
            result = self.run_helper('-Mode', 'Quick', '-ChangedPaths', 'lib/data/profile_fingerprint.dart',
                                     '-Tests', 'test/cloud/cloud_transfer_history_test.dart', env=env)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn('exit=17', result.stdout)
            self.assertNotIn('git diff --check', result.stdout)

    @unittest.skipUnless(os.name == 'nt', 'Uses Windows native-command fixtures')
    def test_native_warnings_are_retained_and_nonzero_exit_still_fails(self):
        with tempfile.TemporaryDirectory(prefix='todorbit-native-command-') as directory:
            tool = Path(directory) / 'fixture.cmd'
            script = "$ErrorActionPreference='Stop'; . ./tools/dev/native-command.ps1; Invoke-TodorbitNative -Command $env:TODORBIT_NATIVE_FIXTURE"
            env = dict(os.environ, TODORBIT_NATIVE_FIXTURE=str(tool))
            for code in (0, 17):
                tool.write_text(f'@echo off\necho expected warning 1>&2\nexit /b {code}\n')
                result = subprocess.run([SHELL, '-NoProfile', '-Command', script], cwd=ROOT,
                                        env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, code == 0, result.stderr)
                self.assertIn('expected warning', result.stdout)
                if code:
                    self.assertIn('(17)', result.stderr)


if __name__ == '__main__':
    unittest.main()
