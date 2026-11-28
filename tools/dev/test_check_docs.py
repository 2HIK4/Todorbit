import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

SPEC = importlib.util.spec_from_file_location("check_docs", Path(__file__).with_name("check-docs.py"))
check_docs = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(check_docs)


class PublicDocumentationLinksTest(unittest.TestCase):
    def test_local_images_paths_and_duplicate_github_headings(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "Example Guide.md").write_text("# Focus & time!\n## Focus & time!\n", encoding="utf-8")
            (root / "Screenshot.png").touch()
            (root / "README.md").write_text(
                '[Guide](<Example Guide.md#focus--time-1>)\n'
                '<img src="Screenshot.png" alt="Planner">\n'
                '[Wrong case](screenshot.png)\n'
                '[Missing anchor](Example%20Guide.md#other)\n'
                '[Outside](../outside.md)\n'
                '[Network](https://example.org/file)\n'
                '~~~markdown\n[Example](missing.md)\n~~~\n',
                encoding="utf-8",
            )
            receipt = check_docs.validate(root, ("README.md",))
            self.assertEqual(receipt["local_destinations"], 5)
            self.assertEqual(receipt["errors"], [
                "README.md: broken path or case mismatch: screenshot.png",
                "README.md: missing heading: Example%20Guide.md#other",
                "README.md: broken path or case mismatch: ../outside.md",
            ])


if __name__ == "__main__":
    unittest.main()
