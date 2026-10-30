"""Failure-path checks for the unpublished Android candidate gate."""
import importlib.util
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('prepare_android', __file__.replace('test_prepare_android_release.py', 'prepare-android-release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


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


if __name__ == '__main__':
    unittest.main()
