"""Execute workflow shell contracts with inert tools; actionlint owns YAML semantics."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(os.environ.get('INFRA_WORKFLOW_ROOT', Path(__file__).resolve().parents[1]))
GIT_BASH = Path('C:/Program Files/Git/bin/bash.exe')
BASH = str(GIT_BASH) if os.name == 'nt' and GIT_BASH.exists() else shutil.which('bash')
PWSH = shutil.which('pwsh')
HOST_GROUPS = ('flutter-regression', 'calendar-recurrence', 'persistence-sync', 'all-host')


def run_block(workflow, step):
    # Deliberately limited to the plain run: | blocks used in these workflows.
    # This is not a YAML validator; validate the full call graph with actionlint.
    lines = (ROOT / '.github/workflows' / workflow).read_text(encoding='utf-8-sig').splitlines()
    start = next(i for i, line in enumerate(lines) if line.strip() == '- name: ' + step)
    run = next(i for i in range(start + 1, len(lines)) if lines[i].strip() == 'run: |')
    indent = len(lines[run]) - len(lines[run].lstrip()) + 2
    block = []
    for line in lines[run + 1:]:
        if line.strip() and len(line) - len(line.lstrip()) < indent:
            break
        block.append(line[indent:])
    return '\n'.join(block) + '\n'


@unittest.skipUnless(BASH, 'Bash required for workflow shell contracts')
class WorkflowShellTests(unittest.TestCase):
    def test_each_declared_group_selects_exactly_one_worker(self):
        text = (ROOT / '.github/workflows/manual-verification.yml').read_text()
        groups = [line.strip()[3:-1] for line in text.splitlines()
                  if line.strip().startswith("- '")]
        self.assertEqual(set(groups), set((*HOST_GROUPS, 'windows-verification', 'android-verification')))
        for group in groups:
            selected = []
            for worker in ('host-verification', 'windows-verification', 'android-verification'):
                block = re.split(r'\n  (?=\S)', text.split('\n  ' + worker + ':\n', 1)[1], maxsplit=1)[0]
                # Job conditions are one line with exactly these two operators.
                condition = next(line.strip()[4:] for line in block.splitlines()
                                 if line.strip().startswith('if: '))
                terms = []
                for term in condition.split(' && '):
                    lhs, operator, rhs = term.split(' ')
                    self.assertEqual(lhs, 'inputs.test_group')
                    self.assertIn(operator, ('==', '!='))
                    equal = group == rhs.strip("'")
                    terms.append(equal if operator == '==' else not equal)
                if all(terms):
                    selected.append(worker)
            self.assertEqual(selected, [group if group.endswith('-verification') else 'host-verification'])

    def execute(self, block, group, fail_match='', results=None):
        with tempfile.TemporaryDirectory(prefix='todorbit-ci-contract-') as temporary:
            root = Path(temporary)
            binary = root / 'bin'
            binary.mkdir()
            (root / '.buildlog/verification').mkdir(parents=True)
            for tool in ('flutter', 'python'):
                stub = binary / tool
                stub.write_text('''#!/usr/bin/env bash
command="$(basename "$0") $*"
printf '%s\\n' "$command" >> "$TRACE"
printf 'Synthetic command: %s\\n' "$command"
if [[ -n "$FAIL_MATCH" && "$command" == "$FAIL_MATCH"* ]]; then exit 17; fi
''', encoding='utf-8')
                stub.chmod(0o755)
            env = dict(os.environ)
            env.update(TEST_GROUP=group, FAIL_MATCH=fail_match,
                       TRACE=(root / 'trace').as_posix(),
                       GITHUB_STEP_SUMMARY=(root / 'summary').as_posix(),
                       GITHUB_SHA='synthetic-sha', GITHUB_REF='refs/heads/synthetic')
            env.update(results or {})
            env['PATH'] = str(binary) + os.pathsep + env['PATH']
            script = root / 'script.sh'
            # Model the baseline workflow's resolved choice without evaluating
            # any actual GitHub expression or accepting shell fragments.
            script.write_text(block.replace('${{ inputs.test_group }}', '$TEST_GROUP'), encoding='utf-8')
            completed = subprocess.run([BASH, '--noprofile', '--norc', '-e', '-o', 'pipefail',
                                        script.as_posix()], cwd=root, env=env,
                                       capture_output=True, text=True, timeout=30)
            trace = (root / 'trace').read_text().splitlines() if (root / 'trace').exists() else []
            log = root / '.buildlog/verification/selected-group.log'
            summary = (root / 'summary').read_text() if (root / 'summary').exists() else ''
            return completed, trace, log.read_text() if log.exists() else '', summary

    def test_host_groups_execute_only_the_selected_work(self):
        block = run_block('manual-verification.yml', 'Execute selected verification group')
        for group in HOST_GROUPS:
            with self.subTest(group=group):
                done, trace, log, _ = self.execute(block, group)
                self.assertEqual(done.returncode, 0, done.stderr)
                self.assertEqual(len(trace), 4 if group == 'all-host' else 1)
                self.assertTrue(log, 'Selected command output must reach the diagnostic artifact')
                if group == 'calendar-recurrence':
                    self.assertIn('test/calendar_series_integrity_review_test.dart', trace[0])
                    self.assertNotIn('test/sync_apply_repository_test.dart', trace[0])
                if group == 'persistence-sync':
                    self.assertIn('test/sync_apply_repository_test.dart', trace[0])
                    self.assertNotIn('test/calendar_test.dart', trace[0])

    def test_each_all_host_failure_stops_later_commands_and_survives_tee(self):
        block = run_block('manual-verification.yml', 'Execute selected verification group')
        for index, command in enumerate(('flutter analyze', 'python tools/dev/check-docs.py',
                                         'python -m unittest', 'flutter test')):
            with self.subTest(command=command):
                done, trace, log, _ = self.execute(block, 'all-host', command)
                self.assertEqual(done.returncode, 17, done.stderr)
                self.assertEqual(len(trace), index + 1)
                self.assertTrue(log)

    def test_rollup_uses_selected_result_and_rejects_failure_cancel_or_skip(self):
        block = run_block('manual-verification.yml', 'Report selected group outcome')
        for group in (*HOST_GROUPS, 'windows-verification', 'android-verification'):
            selected = 'WINDOWS_RESULT' if group == 'windows-verification' else (
                'ANDROID_RESULT' if group == 'android-verification' else 'HOST_RESULT')
            for outcome in ('success', 'failure', 'cancelled', 'skipped'):
                with self.subTest(group=group, outcome=outcome):
                    states = dict.fromkeys(('HOST_RESULT', 'WINDOWS_RESULT', 'ANDROID_RESULT'), 'skipped')
                    states[selected] = outcome
                    done, _, _, summary = self.execute(block, group, results=states)
                    self.assertEqual(done.returncode == 0, outcome == 'success', done.stderr)
                    self.assertIn('**' + outcome + '**', summary)


@unittest.skipUnless(PWSH, 'PowerShell required for the Windows CI failure contract')
class WindowsFailureTests(unittest.TestCase):
    def test_first_python_failure_is_not_hidden_by_second_suite(self):
        block = run_block('windows-ci.yml', 'Validate developer routes and verification helper')
        with tempfile.TemporaryDirectory(prefix='todorbit-ci-pwsh-') as temporary:
            root = Path(temporary)
            (root / 'tools').mkdir()
            (root / 'tools/test_dev_verify.py').write_text(
                'import unittest\nclass Failure(unittest.TestCase):\n def test_failure(self): self.fail("synthetic")\n')
            (root / 'tools/test_background_sync_schema.py').write_text(
                'import unittest\nprint("SECOND_SUITE_EXECUTED")\nclass Success(unittest.TestCase):\n def test_success(self): pass\n')
            script = root / 'step.ps1'
            script.write_text("$ErrorActionPreference='Stop'\n" + block + '\nexit $LASTEXITCODE\n')
            result = subprocess.run([PWSH, '-NoProfile', '-NonInteractive', '-File', str(script)],
                                    cwd=root, capture_output=True, text=True, timeout=30)
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('synthetic', result.stdout + result.stderr)
            self.assertNotIn('SECOND_SUITE_EXECUTED', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
