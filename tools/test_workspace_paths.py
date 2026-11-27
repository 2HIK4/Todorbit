#!/usr/bin/env python3
"""Prevention checks ensuring active configs, tools, skills, workflows, and core docs avoid stale hardcoded workspace paths."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

STALE_WORKSPACE_PATTERNS = [
    re.compile(r"file:///+[A-Za-z]:/AI_Projects/life_manager", re.IGNORECASE),
    re.compile(r"[A-Za-z]:[/\\]{1,2}AI_Projects[/\\]{1,2}life_manager", re.IGNORECASE),
    re.compile(r"AI_Projects[/\\]{1,2}life_manager", re.IGNORECASE),
    re.compile(r"C:[/\\]{1,2}Users[/\\]{1,2}[^/\\]+[/\\]{1,2}(?:\.codex|Documents[/\\]{1,2}Codex)[/\\]{1,2}", re.IGNORECASE),
]

ACTIVE_FILES = [
    "AGENTS.md",
    "README.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    ".vscode/settings.json",
    "docs/ARCHITECTURE.md",
    "docs/ARCHITECTURE_MAP.md",
    "docs/DEVELOPER_AUTOMATION_TOOLKIT.md",
    "docs/DEVELOPMENT.md",
    "docs/TESTING.md",
    "docs/CODEX_WORKFLOW.md",
    "docs/ANDROID.md",
    "docs/ANDROID_SETUP.md",
    "docs/HISTORICAL_TEST_TRACEABILITY.md",
    "docs/CALENDAR_PLATFORM_ARCHITECTURE_RECOMMENDATION.md",
    "docs/windows-widget.md",
    "docs/FEATURES.md",
    "docs/INSTALLATION.md",
]

SCAN_DIRS = (
    ROOT / ".agents" / "skills",
    ROOT / ".github",
    ROOT / "tools" / "dev",
    ROOT / "experiments" / "widget-shell-probe",
)

EXTENSIONS = {".md", ".ps1", ".psm1", ".py", ".json", ".cmd", ".yml", ".yaml", ".cs", ".csproj"}


SKIP_DIR_NAMES = {"obj", "bin", "__pycache__", ".dart_tool", ".buildlog", "build"}


def find_stale_workspace_paths(repo_root: Path = ROOT) -> list[str]:
    files_to_scan = [repo_root / rel for rel in ACTIVE_FILES if (repo_root / rel).exists()]
    for directory in SCAN_DIRS:
        if directory.exists():
            for path in directory.rglob("*"):
                if any(part in SKIP_DIR_NAMES for part in path.parts):
                    continue
                if path.is_file() and path.suffix.lower() in EXTENSIONS:
                    files_to_scan.append(path)
    for py_tool in (repo_root / "tools").glob("*.py"):
        if py_tool.name != "test_workspace_paths.py":
            files_to_scan.append(py_tool)

    violations = []
    for path in sorted(set(files_to_scan)):
        rel = path.relative_to(repo_root).as_posix()
        text = path.read_text(encoding="utf-8-sig", errors="ignore")
        for lineno, line in enumerate(text.splitlines(), 1):
            for pattern in STALE_WORKSPACE_PATTERNS:
                if pattern.search(line):
                    violations.append(f"{rel}:{lineno}: {line.strip()}")
                    break
    return violations


class WorkspacePathHygieneTest(unittest.TestCase):
    def test_vscode_settings_uses_portable_workspace_folder(self):
        vscode_settings = ROOT / ".vscode" / "settings.json"
        if vscode_settings.exists():
            data = json.loads(vscode_settings.read_text(encoding="utf-8-sig"))
            cmake_dir = str(data.get("cmake.sourceDirectory", ""))
            self.assertNotIn("AI_Projects", cmake_dir)
            if cmake_dir:
                self.assertIn("${workspaceFolder}", cmake_dir)

    def test_active_docs_tools_and_skills_avoid_stale_hardcoded_workspace_paths(self):
        violations = find_stale_workspace_paths(ROOT)
        self.assertEqual(
            violations,
            [],
            "Stale hardcoded workspace paths found (use repo-relative paths or dynamic git root):\n"
            + "\n".join(violations),
        )


if __name__ == "__main__":
    unittest.main()
