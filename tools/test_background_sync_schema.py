"""Prevent a stale schema from bypassing privacy/restore worker barriers."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("worker_check", Path(__file__).with_name("test-background-sync.py"))
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


class SchemaTest(unittest.TestCase):
    def test_current_schema_is_derived(self):
        self.assertEqual(worker.checked_schema(), 27)
        self.assertEqual(worker.checked_schema(27), 27)

    def test_old_schema_is_rejected(self):
        with self.assertRaises(ValueError):
            worker.checked_schema(26)


if __name__ == "__main__":
    unittest.main()
