"""Verify signed Android candidates and prepare unpublished GitHub assets.

Requires Android SDK build-tools on PATH and the expected durable certificate.
Never signs packages, creates keys, modifies tags, or publishes a release.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.request


def run(*args):
    executable = shutil.which(args[0])
    if executable is None:
        raise ValueError(f'Required tool is not on PATH: {args[0]}')
    return subprocess.check_output((executable, *args[1:]), text=True, stderr=subprocess.STDOUT)


def sha256(file):
    with file.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def minimum_sdk(badging):
    # Recent aapt2 uses minSdkVersion; older builds emit sdkVersion.
    values = re.findall(r"^(?:minSdkVersion|sdkVersion):'(\d+)'\s*$", badging, re.MULTILINE)
    if len(values) != 1:
        raise ValueError('Expected exactly one APK minimum SDK declaration')
    return int(values[0])


def verify_apk(file, version, code, expected, expected_abis):
    signature = run('apksigner', 'verify', '--verbose', '--print-certs', str(file))
    certs = re.findall(r'Signer #\d+ certificate SHA-256 digest: ([a-fA-F0-9]+)', signature)
    if len(certs) != 1 or certs[0].lower() != expected or 'CN=Android Debug' in signature:
        raise ValueError('APK signer is not the approved production identity')
    badging = run('aapt2', 'dump', 'badging', str(file))
    identity = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging)
    if not identity or identity.groups() != ('io.github.hik4.todorbit', str(code), version):
        raise ValueError('APK package/version does not match requested release (ABI offsets are forbidden)')
    if 'application-debuggable' in badging:
        raise ValueError('Debuggable APK cannot be a production release')
    abi_line = re.search(r'native-code: ([^\n]+)', badging)
    abis = re.findall(r"'([^']+)'", abi_line[1]) if abi_line else []
    if set(abis) != set(expected_abis) or minimum_sdk(badging) != 26:
        raise ValueError('APK architecture/minimum SDK does not match requested artifact')
    run('python', str(Path(__file__).with_name('verify-android-artifact.py')), str(file))
    return abis


def verify_bundle(file, version, code):
    cache = Path(os.environ.get('GRADLE_USER_HOME', Path.home() / '.gradle')) / 'caches/modules-2/files-2.1'
    jars = []
    for module in ['com.android.tools.build/bundletool', 'com.android.tools.build/aapt2-proto', 'com.google.protobuf/protobuf-java']:
        candidates = list((cache / module).glob('*/*/*.jar'))
        if not candidates:
            raise ValueError(f'Build dependencies missing for AAB verification: {module}')
        jars.append(max(candidates, key=lambda p: tuple(map(int, re.findall(r'\d+', p.parent.parent.name)))))
    return run('java', '--class-path', os.pathsep.join(map(str, jars)),
               str(Path(__file__).with_name('VerifyAndroidBundle.java')), str(file), version, str(code))


def request_json(url):
    headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'Todorbit-Android-Release'}
    if os.environ.get('GH_TOKEN'):
        headers['Authorization'] = 'Bearer ' + os.environ['GH_TOKEN']
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as response:
        data = response.read(8 * 1024 * 1024 + 1)
    if len(data) > 8 * 1024 * 1024:
        raise ValueError('Release response too large')
    return json.loads(data)


def published_floor():
    floor = 0
    # Include prereleases: versionCode cannot go backwards when changing channel.
    for page in range(1, 11):
        releases = request_json(f'https://api.github.com/repos/2HIK4/Todorbit/releases?per_page=100&page={page}')
        if not isinstance(releases, list):
            raise ValueError('Invalid GitHub releases response')
        for release in releases:
            if release.get('draft'):
                continue
            tag = release.get('tag_name', '')
            name = f'Todorbit-{tag.removeprefix("v")}-android-update.json'
            for asset in release.get('assets', []):
                if asset.get('name') != name:
                    continue
                url = asset.get('browser_download_url')
                if url != f'https://github.com/2HIK4/Todorbit/releases/download/{tag}/{name}':
                    raise ValueError('Unexpected published Android metadata source')
                manifest = request_json(url)
                code = manifest.get('versionCode')
                if not isinstance(code, int) or manifest.get('packageName') != 'io.github.hik4.todorbit':
                    raise ValueError('Invalid published Android version metadata')
                floor = max(floor, code)
        if len(releases) < 100:
            return floor
    raise ValueError('Release pagination exceeded; inspect version-code history manually')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--arm64-apk', type=Path)
    parser.add_argument('--x64-apk', type=Path)
    parser.add_argument('--aab', type=Path, required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--version-code', type=int, required=True)
    parser.add_argument('--certificate-sha256', required=True)
    parser.add_argument('--notes', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?', args.version):
        raise ValueError('Version must match the shared release tag without v')
    expected = args.certificate_sha256.replace(':', '').lower()
    if not re.fullmatch(r'[a-f0-9]{64}', expected):
        raise ValueError('Expected production certificate SHA-256 is required')
    abis = verify_apk(args.apk, args.version, args.version_code, expected, ['arm64-v8a', 'x86_64'])
    splits = []
    for arch, file, apk_abis in [('arm64', args.arm64_apk, ['arm64-v8a']), ('x64', args.x64_apk, ['x86_64'])]:
        if file:
            verify_apk(file, args.version, args.version_code, expected, apk_abis)
            splits.append((arch, file, apk_abis))
    run('python', str(Path(__file__).with_name('verify-android-artifact.py')), str(args.aab))
    # jarsigner establishes bundle integrity; keytool establishes its signer.
    bundle_result = run('jarsigner', '-verify', str(args.aab))
    if 'jar verified.' not in bundle_result:
        raise ValueError('AAB signature verification failed')
    bundle_cert = run('keytool', '-printcert', '-jarfile', str(args.aab))
    fingerprint = re.search(r'SHA256:\s*([A-Fa-f0-9:]+)', bundle_cert)
    if not fingerprint or fingerprint[1].replace(':', '').lower() != expected:
        raise ValueError('AAB certificate differs from the approved production identity')
    print(verify_bundle(args.aab, args.version, args.version_code))
    if args.version_code <= published_floor():
        raise ValueError('Android version code must exceed every published stable/pre-release code')
    if not args.notes.read_text(encoding='utf-8').strip():
        raise ValueError('Markdown release notes must not be empty')
    args.output.mkdir(parents=True, exist_ok=True)
    apk_name = f'Todorbit-{args.version}-android-universal.apk'
    aab_name = f'Todorbit-{args.version}-android-play.aab'
    shutil.copyfile(args.apk, args.output / apk_name)
    shutil.copyfile(args.aab, args.output / aab_name)
    manifest = {'formatVersion': 1, 'packageName': 'io.github.hik4.todorbit',
                'versionName': args.version, 'versionCode': args.version_code,
                'minSdk': 26, 'apks': [{'name': apk_name, 'abis': abis,
                'size': args.apk.stat().st_size, 'sha256': sha256(args.apk)}]}
    split_files = []
    for arch, file, apk_abis in splits:
        name = f'Todorbit-{args.version}-android-{arch}.apk'
        shutil.copyfile(file, args.output / name)
        split_files.append(args.output / name)
        manifest['apks'].insert(0, {'name': name, 'abis': apk_abis,
                                  'size': file.stat().st_size, 'sha256': sha256(file)})
    manifest_path = args.output / f'Todorbit-{args.version}-android-update.json'
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    shutil.copyfile(args.notes, args.output / 'ANDROID-RELEASE-NOTES.md')
    files = [args.output / name for name in (apk_name, aab_name, manifest_path.name, 'ANDROID-RELEASE-NOTES.md')] + split_files
    (args.output / 'ANDROID-SHA256SUMS.txt').write_text(''.join(f'{sha256(f)}  {f.name}\n' for f in files), encoding='utf-8')
    for file in files:
        assert sha256(file) in (args.output / 'ANDROID-SHA256SUMS.txt').read_text()
    print(f'Prepared verified, unpublished Android {args.version} ({args.version_code}) in {args.output}')


if __name__ == '__main__':
    main()
