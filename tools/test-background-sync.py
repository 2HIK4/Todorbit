"""Run the exact Windows worker against disposable barrier-only profiles."""
import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import tempfile
import time


def digest(file):
    return hashlib.sha256(file.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--executable', required=True, type=Path)
    parser.add_argument('--schema', required=True, type=int)
    args = parser.parse_args()
    executable = args.executable.resolve(strict=True)
    if os.name != 'nt':
        raise RuntimeError('This check requires the Windows Release runner.')
    user32 = ctypes.WinDLL('user32', use_last_error=True)
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user32.EnumWindows.argtypes = [callback_type, wintypes.LPARAM]
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.IsWindowVisible.argtypes = [wintypes.HWND]
    results = []
    for barrier in ('missing', 'migration', 'protected', 'restore'):
        with tempfile.TemporaryDirectory(prefix='todorbit-worker-') as temporary:
            root = Path(temporary).resolve()
            roaming, local = root / 'Roaming', root / 'Local'
            roaming.mkdir()
            local.mkdir()
            profile = roaming / 'TodoPilot'
            if (executable.parent / 'PORTABLE-MODE').exists():
                key = hashlib.sha256(str(executable.parent).lower().encode()).hexdigest()[:16]
                profile /= 'portable-' + key
            database = profile / 'life_manager.sqlite'
            if barrier != 'missing':
                profile.mkdir(parents=True)
                with sqlite3.connect(database) as connection:
                    connection.execute('CREATE TABLE sentinel(value TEXT)')
                    connection.execute("INSERT INTO sentinel VALUES('Synthetic retained work')")
                    connection.execute(f'PRAGMA user_version={22 if barrier == "migration" else args.schema}')
                if barrier == 'protected':
                    (profile / 'privacy-settings.json').write_text('{"enabled":true}', encoding='utf-8')
                if barrier == 'restore':
                    (profile / 'pending-restore.json').write_text('{"synthetic":true}', encoding='utf-8')
            before = {str(p.relative_to(root)): digest(p) for p in root.rglob('*') if p.is_file()}
            environment = dict(os.environ, APPDATA=str(roaming), LOCALAPPDATA=str(local))
            child = subprocess.Popen([str(executable), '--sync-background'], env=environment,
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                     creationflags=subprocess.CREATE_NO_WINDOW)
            visible = []

            @callback_type
            def inspect_window(window, _):
                owner = wintypes.DWORD()
                user32.GetWindowThreadProcessId(window, ctypes.byref(owner))
                if owner.value == child.pid and user32.IsWindowVisible(window):
                    visible.append(int(window))
                return True

            try:
                deadline = time.monotonic() + 45
                while child.poll() is None and time.monotonic() < deadline:
                    user32.EnumWindows(inspect_window, 0)
                    time.sleep(0.025)
                if child.poll() is None:
                    raise RuntimeError(f'{barrier}: worker exceeded its bounded startup check')
                if child.returncode != 0 or visible:
                    raise RuntimeError(f'{barrier}: worker failed or displayed a window')
            finally:
                if child.poll() is None:
                    child.kill()
                    child.wait()
            after = {str(p.relative_to(root)): digest(p) for p in root.rglob('*') if p.is_file()}
            if after != before:
                raise RuntimeError(f'{barrier}: background barrier changed the disposable profile')
            results.append({'barrier': barrier, 'profileUnchanged': True, 'visibleWindowsObserved': 0})
    print(json.dumps({'executableSha256': digest(executable), 'checks': results}, indent=2))


if __name__ == '__main__':
    main()
