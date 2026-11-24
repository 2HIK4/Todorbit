#!/usr/bin/env python3
"""Cross-platform validation of tools/dev/registry.json completeness and cache-eligibility invariants."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY_PATH = ROOT / "tools" / "dev" / "registry.json"

INELIGIBLE_DART_PATTERN = re.compile(
    r"(runtime_workflow_journey_test\.dart|startup_recovery_journeys_test\.dart|"
    r"resource_journeys_test\.dart|native_widget_launch_integration_test\.dart|"
    r"performance_benchmark_test\.dart|lab_render_test\.dart)$"
)


class RegistrySyncTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.registry = json.loads(REGISTRY_PATH.read_text(encoding="utf-8-sig"))
        cls.entries = cls.registry.get("Tests", [])
        cls.by_path = {e["Path"]: e for e in cls.entries}

    def test_all_registered_files_exist_on_disk(self):
        missing = [e["Path"] for e in self.entries if not (ROOT / e["Path"]).exists()]
        self.assertEqual(missing, [], f"Registry references missing files: {missing}")

    def test_no_unregistered_dart_or_integration_or_tool_tests(self):
        dart_tests = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "test").rglob("*_test.dart"))
        int_tests = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "integration_test").rglob("*.dart"))
        py_tests = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "tools").rglob("test_*.py"))

        expected = set(dart_tests + int_tests + py_tests + ["tools/dev/check-docs.py"])
        missing_from_registry = sorted(expected - set(self.by_path))
        self.assertEqual(
            missing_from_registry,
            [],
            f"Unregistered test files found (run '.\\dev registry refresh'): {missing_from_registry}",
        )

    def test_non_cacheable_tests_remain_ineligible(self):
        violations = []
        for entry in self.entries:
            path = entry["Path"]
            must_be_ineligible = (
                entry.get("Type") in ("integration_test", "python_test", "python_script")
                or bool(INELIGIBLE_DART_PATTERN.search(path))
            )
            if must_be_ineligible and entry.get("EvidenceReuse") != "Ineligible":
                violations.append((path, entry.get("EvidenceReuse")))
        self.assertEqual(violations, [], f"Cache-ineligible tests marked eligible: {violations}")


if __name__ == "__main__":
    unittest.main()
