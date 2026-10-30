"""Create negative signed APK fixtures for a disposable Android emulator only."""
import argparse
from pathlib import Path
import shutil
import subprocess
import zipfile
import hashlib
import json
import re


def run(*args):
    result = subprocess.run([shutil.which(args[0]) or args[0], *map(str, args[1:])],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if result.returncode:
        raise RuntimeError(f'Test fixture tool failed ({args[0]}):\n{result.stdout}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk', type=Path, required=True)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--debug-keystore', type=Path, required=True)
    parser.add_argument('--baseline-version-code', type=int, default=19)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not 1 <= args.baseline_version_code < 2100000000:
        raise ValueError('Invalid disposable baseline version code')
    candidate_code = args.baseline_version_code + 1
    if not args.debug_keystore.is_file():
        raise ValueError('Debug keystore is missing; use the Store path from the githubDebug signingReport')
    args.output.mkdir(parents=True, exist_ok=True)
    build_tools = args.sdk / 'build-tools/36.0.0'
    aapt = str(build_tools / ('aapt2.exe' if __import__('os').name == 'nt' else 'aapt2'))
    signer = str(build_tools / ('apksigner.bat' if __import__('os').name == 'nt' else 'apksigner'))
    untrusted = args.output / 'untrusted-test-only.jks'
    if not untrusted.exists():
        run('keytool', '-genkeypair', '-keystore', untrusted, '-storepass', 'android', '-keypass', 'android',
            '-alias', 'untrusted', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '30',
            '-dname', 'CN=Untrusted test fixture only')
    shutil.copyfile(args.candidate, args.output / 'candidate.apk')
    badging = subprocess.check_output([aapt, 'dump', 'badging', str(args.candidate)], text=True)
    identity = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging)
    if not identity or identity[1] != 'io.github.hik4.todorbit' or int(identity[2]) != candidate_code:
        raise ValueError('Acceptance candidate must be Todorbit with baseline version code + 1')
    with args.candidate.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    (args.output / 'candidate.json').write_text(json.dumps({'versionName': identity[3], 'versionCode': candidate_code,
        'size': args.candidate.stat().st_size, 'sha256': digest}), encoding='utf-8')
    for name in ['wrong-package', 'wrong-signer', 'wrong-abi', 'newer-sdk', 'older']:
        package = 'io.github.hik4.wrong' if name == 'wrong-package' else 'io.github.hik4.todorbit'
        code = args.baseline_version_code if name == 'older' else candidate_code
        sdk = 36 if name == 'newer-sdk' else 26
        abi = 'armeabi-v7a' if name == 'wrong-abi' else 'x86_64'
        manifest = args.output / 'AndroidManifest.xml'
        manifest.write_text(f'<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{package}" android:versionCode="{code}" android:versionName="{identity[3]}"><uses-sdk android:minSdkVersion="{sdk}" android:targetSdkVersion="36"/><application android:hasCode="false" android:label="Todorbit verification fixture"/></manifest>', encoding='utf-8')
        apk = args.output / f'{name}.apk'
        run(aapt, 'link', '-o', apk, '-I', args.sdk / 'platforms/android-36/android.jar', '--manifest', manifest)
        with zipfile.ZipFile(apk, 'a') as archive:
            archive.writestr(f'lib/{abi}/libflutter.so', b'Not executable: verification fixture only')
        run(signer, 'sign', '--ks', untrusted if name == 'wrong-signer' else args.debug_keystore,
            '--ks-key-alias', 'untrusted' if name == 'wrong-signer' else 'androiddebugkey',
            '--ks-pass', 'pass:android', '--key-pass', 'pass:android', apk)
    shutil.copyfile(args.output / 'candidate.apk', args.output / 'tampered.apk')
    # Alter signed bytes without resigning; the outer expected SHA will be
    # recomputed by the test, so only signature integrity can reject this case.
    with zipfile.ZipFile(args.output / 'tampered.apk', 'a') as archive:
        archive.writestr('tampered.txt', b'Unauthenticated substitution')
    print(f'Prepared test-only signed fixtures in {args.output}; never install the negative fixtures.')


if __name__ == '__main__':
    main()
