#!/usr/bin/env python3
"""Compare matched signed iOS release .app bundles; not an App Store size estimate."""
import argparse
import gzip
import hashlib
import io
import json
import plistlib
import subprocess
import zipfile
from pathlib import Path


def sha(data):
    return hashlib.sha256(data).hexdigest()


def measure(path):
    info = plistlib.loads((path / 'Info.plist').read_bytes())
    executable = path / info['CFBundleExecutable']
    architecture = subprocess.check_output(['xcrun', 'lipo', '-archs', str(executable)], text=True).strip()
    if architecture != 'arm64':
        raise ValueError(f'Expected arm64 release app, got {architecture}')
    if b'__DWARF' in subprocess.check_output(['xcrun', 'otool', '-l', str(executable)]):
        raise ValueError('Debug sections must not be included in the measured app')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(path)], check=True, capture_output=True)
    files = []
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as output:
        for file in sorted(path.rglob('*')):
            if not file.is_file():
                continue
            if file.is_symlink():
                raise ValueError('This arm64 app measurement expects ordinary files, not symlinks')
            relative = str(file.relative_to(path))
            data = file.read_bytes()
            files.append({'path': relative, 'bytes': len(data), 'sha256': sha(data)})
            entry = zipfile.ZipInfo('Payload/App.app/' + relative, date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = (0o100755 if file == executable else 0o100644) << 16
            output.writestr(entry, data, compresslevel=9)
    return {'bundleIdentifier': info['CFBundleIdentifier'], 'architecture': architecture,
            'minimumOSVersion': info['MinimumOSVersion'], 'logicalFileBytes': sum(f['bytes'] for f in files),
            'executableBytes': executable.stat().st_size, 'deterministicZIPBytes': len(archive.getvalue()),
            'deterministicZIPSHA256': sha(archive.getvalue()), 'files': files}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', required=True, type=Path)
    parser.add_argument('--embedded', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--native-revision', required=True)
    args = parser.parse_args()
    if (args.baseline / 'fapi.json').read_bytes() != (args.embedded / 'fapi.json').read_bytes():
        raise ValueError('Both apps must contain the identical fixture asset')
    if list(args.baseline.rglob('clerk-core.js')):
        raise ValueError('Baseline unexpectedly includes Clerk core')
    core_paths = list(args.embedded.rglob('clerk-core.js'))
    if len(core_paths) != 1:
        raise ValueError('Expected exactly one shipped core bundle')
    core = core_paths[0].read_bytes()
    manifest = json.loads(core_paths[0].with_name('core-manifest.json').read_text())
    if sha(core) != manifest['bundleSHA256']:
        raise ValueError('Core does not match the shipped manifest')
    baseline, embedded = measure(args.baseline), measure(args.embedded)
    if baseline['minimumOSVersion'] != embedded['minimumOSVersion']:
        raise ValueError('Mismatched deployment targets')
    report = {'schemaVersion': 1, 'nativeRevision': args.native_revision,
              'xcode': subprocess.check_output(['xcodebuild', '-version'], text=True).strip(),
              'build': 'Release, Swift -O wholemodule, dead stripping, arm64, development signed',
              'baseline': baseline, 'embedded': embedded,
              'core': {'revision': manifest['coreRevision'], 'sha256': sha(core), 'bytes': len(core),
                       'gzipLevel9Bytes': len(gzip.compress(core, compresslevel=9, mtime=0)),
                       'contractHash': manifest['contractHash']},
              'delta': {key: embedded[key] - baseline[key] for key in ['logicalFileBytes', 'executableBytes', 'deterministicZIPBytes']},
              'limitations': ['Logical app-file bytes are not device filesystem allocation or Settings storage usage',
                              'Deterministic ZIP is a diagnostic, not App Store compressed delivery or thinning estimate',
                              'Development signatures and provisioning profiles are included; distribution signing differs',
                              'Core API and default platform factory are linked; ClerkKitUI and explicit platform presenters are not exercised',
                              'System JavaScriptCore is supplied by iOS and is not copied into either app',
                              'Does not close installed-size or App Store download release gates']}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, sort_keys=True, indent=2) + '\n')
    print(json.dumps({'delta': report['delta'], 'core': report['core']}, indent=2))


if __name__ == '__main__':
    main()
