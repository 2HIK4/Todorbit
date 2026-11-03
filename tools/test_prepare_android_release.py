"""Failure-path checks for the unpublished Android candidate gate."""
import importlib.util
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('prepare_android', __file__.replace('test_prepare_android_release.py', 'prepare-android-release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class MinimumSdkTests(unittest.TestCase):
    def test_current_and_legacy_badging(self):
        for label in ('minSdkVersion', 'sdkVersion'):
            with self.subTest(label=label):
                self.assertEqual(release.minimum_sdk(f"{label}:'26'\ntargetSdkVersion:'36'\n"), 26)

    def test_preserves_other_minimum_for_policy_rejection(self):
        self.assertEqual(release.minimum_sdk("minSdkVersion:'35'\n"), 35)

    def test_missing_malformed_or_ambiguous_minimum_fails_closed(self):
        for badging in ("targetSdkVersion:'36'\n", "minSdkVersion:'unknown'\n",
                        "sdkVersion:'26'\nminSdkVersion:'35'\n"):
            with self.subTest(badging=badging), self.assertRaises(ValueError):
                release.minimum_sdk(badging)


class VersionGateTests(unittest.TestCase):
    def test_no_android_releases_yet(self):
        with patch.object(release, 'request_json', return_value=[{'tag_name': 'v1.0.18', 'assets': []}]):
            self.assertEqual(release.published_floor(), 0)

    def test_highest_code_includes_prereleases_and_ignores_drafts(self):
        def get(url):
            if 'api.github.com' in url:
                return [
                    {'tag_name': 'v1.0.19', 'assets': [{'name': 'Todorbit-1.0.19-android-update.json', 'browser_download_url': 'https://github.com/2HIK4/Todorbit/releases/download/v1.0.19/Todorbit-1.0.19-android-update.json'}]},
                    {'tag_name': 'v1.0.20-rc.1', 'prerelease': True, 'assets': [{'name': 'Todorbit-1.0.20-rc.1-android-update.json', 'browser_download_url': 'https://github.com/2HIK4/Todorbit/releases/download/v1.0.20-rc.1/Todorbit-1.0.20-rc.1-android-update.json'}]},
                    {'draft': True, 'tag_name': 'v9.0.0'},
                ]
            return {'packageName': 'io.github.hik4.todorbit', 'versionCode': 22 if 'rc.1' in url else 20}
        with patch.object(release, 'request_json', side_effect=get):
            self.assertEqual(release.published_floor(), 22)

    def test_unexpected_source_fails_closed(self):
        with patch.object(release, 'request_json', return_value=[{'tag_name': 'v1.0.19', 'assets': [{'name': 'Todorbit-1.0.19-android-update.json', 'browser_download_url': 'https://evil.example/metadata'}]}]):
            with self.assertRaises(ValueError):
                release.published_floor()

    def test_unavailable_service_never_skips_version_gate(self):
        with patch.object(release, 'request_json', side_effect=TimeoutError):
            with self.assertRaises(TimeoutError):
                release.published_floor()


class ApkVariantTests(unittest.TestCase):
    def verify(self, code=24, abis="'arm64-v8a'", signer='a' * 64):
        badging = (f"package: name='io.github.hik4.todorbit' versionCode='{code}' versionName='1.0.20-beta.1'\n"
                   f"minSdkVersion:'26'\nnative-code: {abis}\n")
        def run(*args):
            if args[0] == 'apksigner':
                return f'Signer #1 certificate SHA-256 digest: {signer}'
            if args[0] == 'aapt2':
                return badging
            return ''
        with patch.object(release, 'run', side_effect=run):
            return release.verify_apk('candidate.apk', '1.0.20-beta.1', 24, 'a' * 64, ['arm64-v8a'])

    def test_arm64_same_code(self):
        self.assertEqual(self.verify(), ['arm64-v8a'])

    def test_flutter_abi_offset_rejected(self):
        with self.assertRaisesRegex(ValueError, 'ABI offsets'):
            self.verify(code=2024)

    def test_wrong_architecture_rejected(self):
        with self.assertRaisesRegex(ValueError, 'architecture'):
            self.verify(abis="'x86_64'")

    def test_wrong_signer_rejected(self):
        with self.assertRaisesRegex(ValueError, 'production identity'):
            self.verify(signer='b' * 64)


class ApkOnlyPreparationTests(unittest.TestCase):
    def test_apk_only_retains_gates_and_emits_only_github_assets(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            apk, notes, output = root/'test.apk', root/'notes.md', root/'output'
            apk.write_bytes(b'synthetic artifact')
            notes.write_text('Experimental test notes', encoding='utf-8')
            argv = ['prepare', '--apk', str(apk), '--apk-only', '--version', '1.0.19-beta.10',
                    '--version-code', '33', '--certificate-sha256', 'a' * 64,
                    '--notes', str(notes), '--output', str(output)]
            with patch('sys.argv', argv), patch.object(release, 'verify_apk', return_value=['arm64-v8a', 'x86_64']) as verify, \
                    patch.object(release, 'published_floor', return_value=32) as floor, \
                    patch.object(release, 'run', side_effect=AssertionError('Unexpected AAB command')), contextlib.redirect_stdout(io.StringIO()):
                release.main()
            verify.assert_called_once_with(apk, '1.0.19-beta.10', 33, 'a' * 64, ['arm64-v8a', 'x86_64'])
            floor.assert_called_once()
            manifest = json.loads((output/'Todorbit-1.0.19-beta.10-android-update.json').read_text())
            self.assertEqual(manifest['versionCode'], 33)
            self.assertEqual(manifest['apks'][0]['sha256'], release.sha256(apk))
            self.assertEqual(len(list(output.iterdir())), 4)
            self.assertFalse(list(output.glob('*.aab')))

    def test_existing_default_still_requires_aab(self):
        with patch('sys.argv', ['prepare', '--apk', 'test.apk', '--version', '1.0.19-beta.10',
                                '--version-code', '33', '--certificate-sha256', 'a' * 64,
                                '--notes', 'notes.md', '--output', 'output']), \
                contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            release.main()

    def test_apk_only_cannot_silently_skip_supplied_aab(self):
        with patch('sys.argv', ['prepare', '--apk', 'test.apk', '--apk-only', '--aab', 'test.aab',
                                '--version', '1.0.19-beta.10', '--version-code', '33',
                                '--certificate-sha256', 'a' * 64, '--notes', 'notes.md', '--output', 'output']), \
                contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            release.main()


if __name__ == '__main__':
    unittest.main()
