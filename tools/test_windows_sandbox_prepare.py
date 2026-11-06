"""Exercise Sandbox staging with inert packages; never install on the host."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHELL = shutil.which('pwsh') or shutil.which('powershell')


@unittest.skipUnless(SHELL, 'PowerShell required')
class SandboxPreparationTest(unittest.TestCase):
    def stage(self, version, *, bad_digest=False, schema=26):
        temporary = tempfile.TemporaryDirectory(prefix='todorbit-sandbox-prepare-')
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        (root/'tools').mkdir()
        (root/'lib/data').mkdir(parents=True)
        (root/'pubspec.yaml').write_text(f'name: fixture\nversion: {version}+31\n')
        (root/'lib/data/app_database.dart').write_text(f'const currentSchemaVersion = {schema};')
        for name in ('prepare-windows-sandbox-acceptance.ps1', 'windows-sandbox-acceptance.ps1'):
            shutil.copyfile(ROOT/'tools'/name, root/'tools'/name)
        packages = root/'packages'
        packages.mkdir()
        for suffix in ('setup.exe', 'portable.zip'):
            name = f'Todorbit-{version}-win-x64-{suffix}'
            data = b'inert fixture: never executable'
            (packages/name).write_bytes(data)
            digest = '0'*64 if bad_digest else hashlib.sha256(data).hexdigest()
            (packages/(name+'.sha256')).write_text(f'{digest}  {name}\n')
        result = subprocess.run([SHELL, '-NoProfile', '-File',
            str(root/'tools/prepare-windows-sandbox-acceptance.ps1'),
            '-PackagesDirectory', str(packages)], capture_output=True, text=True)
        return root, result

    def test_prerelease_assets_keep_beta_identity_and_numeric_installer_identity(self):
        root, result = self.stage('1.0.19-beta.8')
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads(next(root.glob('.buildlog/*/payload/packages.json')).read_text(encoding='utf-8-sig'))
        self.assertEqual(manifest['version'], '1.0.19-beta.8')
        self.assertEqual(manifest['installerVersion'], '1.0.19')
        self.assertEqual(manifest['schemaVersion'], 26)
        self.assertEqual(manifest['tableCount'], 52)
        self.assertEqual(len(manifest['hashes']), 2)
        configuration = next(root.glob('.buildlog/*/*.wsb')).read_text(encoding='utf-8-sig')
        self.assertIn('<ReadOnly>true</ReadOnly>', configuration)
        self.assertNotIn(str(ROOT), configuration)

    def test_stable_assets_remain_compatible(self):
        root, result = self.stage('1.0.18')
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads(next(root.glob('.buildlog/*/payload/packages.json')).read_text(encoding='utf-8-sig'))
        self.assertEqual(manifest['version'], manifest['installerVersion'])

    def test_tampered_package_sidecar_fails_before_vm_configuration(self):
        root, result = self.stage('1.0.19-beta.8', bad_digest=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Package sidecar mismatch', result.stderr)
        self.assertEqual(list(root.glob('.buildlog/*/*.wsb')), [])

    def test_schema27_counts_the_named_checklist_group_table(self):
        root, result = self.stage('1.0.19-beta.12', schema=27)
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads(next(root.glob('.buildlog/*/payload/packages.json')).read_text(encoding='utf-8-sig'))
        self.assertEqual(manifest['schemaVersion'], 27)
        self.assertEqual(manifest['tableCount'], 53)

    def test_unreviewed_schema_cannot_emit_a_vm_configuration(self):
        root, result = self.stage('1.0.19-beta.12', schema=28)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Review the Sandbox table count', result.stderr)
        self.assertEqual(list(root.glob('.buildlog/*/*.wsb')), [])


if __name__ == '__main__':
    unittest.main()
