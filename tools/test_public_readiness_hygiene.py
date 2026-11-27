"""Public readiness, docs/FEATURES integrity, TDAT worktree hygiene, and website regression tests."""
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PublicReadinessHygieneTests(unittest.TestCase):
    def test_features_catalogue_counts_match_summary(self):
        features_doc = (ROOT / 'docs/FEATURES.md').read_text(encoding='utf-8')
        row_ids = re.findall(r'\|\s+\*\*(F\d+)\*\*\s+\|', features_doc)
        self.assertGreaterEqual(len(row_ids), 50)
        self.assertEqual(len(row_ids), len(set(row_ids)), 'Duplicate feature IDs in docs/FEATURES.md')
        total_match = re.search(
            r'\|\s+\*\*Total\*\*\s+\|\s+\*\*(\d+)\s+Feature Areas\*\*\s+\|\s+\*\*(\d+)\*\*\s+\|',
            features_doc,
        )
        self.assertIsNotNone(total_match, 'Missing Total summary row in docs/FEATURES.md')
        self.assertEqual(int(total_match.group(2)), len(row_ids))

    def test_public_docs_and_website_contain_no_local_paths(self):
        public_paths = [
            ROOT / 'README.md',
            ROOT / 'CONTRIBUTING.md',
            ROOT / 'SECURITY.md',
            ROOT / 'docs/FEATURES.md',
            ROOT / 'docs/OPEN_SOURCE_EVIDENCE.md',
            ROOT / 'docs/OPEN_SOURCE_READINESS.md',
            ROOT / 'docs/PLATFORM_SUPPORT.md',
            ROOT / 'docs/CONTRIBUTOR_TASKS.md',
            ROOT / 'docs/INSTALLATION.md',
            ROOT / 'docs/ROADMAP.md',
            ROOT / 'docs/PRIVACY.md',
            *sorted((ROOT / 'website/dist').rglob('*.html')),
            *sorted((ROOT / 'website/dist').rglob('*.css')),
        ]
        for path in public_paths:
            content = path.read_text(encoding='utf-8')
            self.assertFalse(
                re.search(r'AI_Projects|C:\\Users|C:/Users', content, re.I),
                f'Personal/local workstation path leaked in public file: {path.relative_to(ROOT)}',
            )

    def test_doctor_and_runtime_worktree_safety_guards(self):
        doctor = (ROOT / 'tools/dev/modules/Doctor.psm1').read_text(encoding='utf-8')
        self.assertIn('-C', doctor)
        self.assertIn('HEAD', doctor)
        runtime = (ROOT / 'tools/dev/modules/Runtime.psm1').read_text(encoding='utf-8')
        self.assertIn('prepare-windows-plugins.ps1', runtime)

    def test_website_static_verification_passes(self):
        result = subprocess.run(
            [sys.executable, 'website/verify.py'],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
