"""Validate the concise developer routing docs, local links and feature catalog."""
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]
DEFAULTS = ['AGENTS.md', 'docs/ARCHITECTURE_MAP.md', 'docs/ARCHITECTURE.md',
            'docs/CODEX_WORKFLOW.md', 'docs/TESTING.md', 'docs/ANDROID.md',
            'docs/ANDROID_SETUP.md', 'docs/ANDROID_GOOGLE_DRIVE.md',
            'docs/ANDROID_RELEASE.md', 'docs/ANDROID_UPDATES.md']


def validate(files=DEFAULTS):
    errors = []
    catalog = json.loads((ROOT / 'tools/dev/features.json').read_text(encoding='utf-8'))
    for feature, group in catalog.items():
        for value in group['paths'] + group['tests']:
            if not (ROOT / value).exists():
                errors.append(f'{feature}: missing {value}')
    for filename in files:
        file = ROOT / filename
        content = file.read_text(encoding='utf-8-sig')
        for target in re.findall(r'\]\(([^)]+)\)', content):
            target = unquote(target.split('#')[0].strip('<>'))
            if not target or re.match(r'\w+://|mailto:', target):
                continue
            if not (file.parent / target).exists():
                errors.append(f'{filename}: broken link {target}')
        if filename == 'docs/ARCHITECTURE_MAP.md':
            for target in re.findall(r'`([^`]+)`', content):
                if '/' in target and not (ROOT / target).exists():
                    errors.append(f'{filename}: missing mapped path {target}')
    return errors


if __name__ == '__main__':
    problems = validate(sys.argv[1:] or DEFAULTS)
    for problem in problems:
        print(problem)
    print(f'Developer links, map and feature catalog: {len(problems)} errors')
    sys.exit(bool(problems))
