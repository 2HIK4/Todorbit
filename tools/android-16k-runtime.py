"""Opt-in artifact runtime acceptance on a fresh, disposable Android emulator.

Never builds an app or touches a phone. The workflow supplies a hash-verified
candidate. All interaction creates synthetic data in an initially absent app.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET


ROOT = Path('.buildlog/16k-runtime')
PACKAGE = 'io.github.hik4.todorbit'
ADB = ['adb', '-s', 'emulator-5554']


def adb(*args):
    return subprocess.check_output(ADB + list(args), timeout=30).decode(errors='replace').strip()


def screen(name):
    remote = '/sdcard/todorbit-runtime.xml'
    adb('shell', 'uiautomator', 'dump', remote)
    adb('pull', remote, str(ROOT / f'{name}.xml'))
    return ET.parse(ROOT / f'{name}.xml')


def find(label, name, timeout=30):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        tree = screen(name)
        for node in tree.iter('node'):
            if node.get('enabled') == 'true' and any(
                label == node.get(key, '') or label in node.get(key, '').split('\n')
                for key in ('text', 'content-desc')
            ):
                return node
        time.sleep(2)
    raise AssertionError(f'Visible control/text not found: {label}; see {name}.xml')


def tap(node):
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.get('bounds')))
    adb('shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2))


def snapshot(name):
    screen(name)
    (ROOT / f'{name}.png').write_bytes(subprocess.check_output(ADB + ['exec-out', 'screencap', '-p']))


def no_crashes(name):
    crash = adb('logcat', '-d', '-b', 'crash')
    (ROOT / f'{name}.log').write_text(crash, encoding='utf-8')
    assert not crash or crash == '--------- beginning of crash', f'Crash buffer not empty: {name}.log'


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    assert adb('shell', 'getprop', 'ro.kernel.qemu') == '1', 'Disposable emulator required'
    assert adb('shell', 'getconf', 'PAGE_SIZE') == '16384', 'Real 16 KiB page size required'
    assert not adb('shell', 'pm', 'list', 'packages', PACKAGE), 'Fresh guest without Todorbit required'
    package = ROOT / 'candidate.apk'
    with package.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    assert digest == os.environ['APK_SHA256'], 'Candidate changed'
    server = adb('shell', 'pidof', 'system_server')
    time.sleep(40)
    assert server and adb('shell', 'pidof', 'system_server') == server, 'System restarted without app'
    no_crashes('no-app-baseline')
    adb('install', str(package))
    adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
    tap(find('New task', 'home', timeout=60))
    title = 'Beta2 sixteen KiB acceptance'
    tree = screen('task-editor')
    fields = [n for n in tree.iter('node') if n.get('class') == 'android.widget.EditText']
    assert fields, 'Task title input missing'
    tap(fields[0])
    adb('shell', 'input', 'text', title.replace(' ', '%s'))
    adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
    # The production editor uses Save task or Save depending on compact layout.
    tree = screen('task-filled')
    save = next((n for n in tree.iter('node') if any(
        n.get(k) in ('Save task', 'Save', 'Add task', 'Create task')
        for k in ('text', 'content-desc')) and n.get('enabled') == 'true'), None)
    assert save is not None, 'Enabled save control missing'
    tap(save)
    # Newly created tasks can be unscheduled; inspect the Tasks tab.
    time.sleep(2)
    tree = screen('saved')
    task_tab = next((n for n in tree.iter('node') if n.get('content-desc', '').startswith('Tasks\n')), None)
    if task_tab is not None:
        tap(task_tab)
    find(title, 'persisted-task')
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
    time.sleep(3)
    tree = screen('cold-reopen')
    tab = next((n for n in tree.iter('node') if n.get('content-desc', '').startswith('Tasks\n')), None)
    if tab is not None:
        tap(tab)
    find(title, 'sqlite-reopen')
    tap(find('Complete ' + title, 'task-interaction'))
    time.sleep(2)
    snapshot('completed')
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
    time.sleep(3)
    snapshot('completed-reopen')
    no_crashes('post-app-crashes')
    events = adb('logcat', '-d', '-b', 'events')
    (ROOT / 'events.log').write_text(events, encoding='utf-8')
    assert not any(PACKAGE in line and ('am_crash' in line or 'am_anr' in line) for line in events.splitlines()), 'Todorbit crash/ANR event'
    (ROOT / 'receipt.json').write_text(json.dumps({
        'apkSha256': digest, 'pageSize': 16384, 'systemImage': adb('shell', 'getprop', 'ro.build.fingerprint'),
        'noAppBaselineSeconds': 40, 'systemStableWithoutApp': True,
        'flutterRendered': True, 'taskCreatedAndRetainedAfterRestart': True,
        'taskCompletionInteraction': True, 'noCrashOrAnrObserved': True,
    }, indent=2) + '\n', encoding='utf-8')
    print('16 KiB artifact runtime passed:', digest)


if __name__ == '__main__':
    try:
        main()
    except Exception as failure:
        ROOT.mkdir(parents=True, exist_ok=True)
        (ROOT / 'failure.json').write_text(json.dumps({'failure': str(failure)}, indent=2), encoding='utf-8')
        for name, args in {
            'failure-crash': ('logcat', '-d', '-b', 'crash'),
            'failure-events': ('logcat', '-d', '-b', 'events'),
            'failure-system': ('logcat', '-d', '-t', '1000'),
        }.items():
            try:
                (ROOT / f'{name}.log').write_text(adb(*args), encoding='utf-8')
            except (subprocess.SubprocessError, OSError):
                pass
        raise
