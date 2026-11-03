"""Opt-in artifact runtime acceptance on a fresh, disposable Android emulator.

Never builds an app or touches a phone. The workflow supplies a hash-verified
candidate and optionally a previous production APK. All interaction creates
synthetic data in an initially absent app; upgrades never uninstall or clear it.
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
    # A failed dump must never reuse a previous screen's XML after an upgrade.
    remote = f'/sdcard/todorbit-runtime-{time.monotonic_ns()}.xml'
    adb('shell', 'uiautomator', 'dump', remote)
    adb('pull', remote, str(ROOT / f'{name}.xml'))
    return ET.parse(ROOT / f'{name}.xml')


def find(label, name, timeout=30):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        try:
            tree = screen(name)
        except (subprocess.CalledProcessError, ET.ParseError):
            # UIAutomator can have no root while Flutter's first frame starts.
            # Keep the existing deadline and require a fresh successful dump.
            time.sleep(2)
            continue
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
    previous = ROOT / 'previous.apk'
    previous_digest = None
    if previous.exists():
        with previous.open('rb') as stream:
            previous_digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        assert previous_digest == os.environ['PREVIOUS_APK_SHA256'], 'Previous APK changed'
    server = adb('shell', 'pidof', 'system_server')
    time.sleep(40)
    assert server and adb('shell', 'pidof', 'system_server') == server, 'System restarted without app'
    no_crashes('no-app-baseline')
    adb('install', str(previous if previous.exists() else package))
    previous_code = None
    if previous.exists():
        previous_code = int(re.search(r'versionCode=(\d+)', adb('shell', 'dumpsys', 'package', PACKAGE))[1])
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
    upgraded_code = None
    if previous.exists():
        adb('shell', 'am', 'force-stop', PACKAGE)
        # The package manager must accept the actual production-signed update.
        # No uninstall, clear-data command or debug-signing fallback is allowed.
        adb('install', '-r', str(package))
        upgraded_code = int(re.search(r'versionCode=(\d+)', adb('shell', 'dumpsys', 'package', PACKAGE))[1])
        assert upgraded_code > previous_code, 'Upgrade code must increase'
        adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
        time.sleep(3)
        tree = screen('upgraded-home')
        tab = next((n for n in tree.iter('node') if n.get('content-desc', '').startswith('Tasks\n')), None)
        if tab is not None:
            tap(tab)
        find(title, 'upgraded-retained-task')
        snapshot('upgraded-retained-task')
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
        'previousApkSha256': previous_digest,
        'previousVersionCode': previous_code, 'upgradedVersionCode': upgraded_code,
        'productionInPlaceUpgradeRetainedTask': previous.exists(),
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
            'failure-main': ('logcat', '-d', '-b', 'main'),
        }.items():
            try:
                (ROOT / f'{name}.log').write_text(adb(*args), encoding='utf-8')
            except (subprocess.SubprocessError, OSError):
                pass
        raise
