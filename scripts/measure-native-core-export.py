#!/usr/bin/env python3
"""Compare Xcode's app-thinning estimates from matched local release exports."""
import argparse
import hashlib
import json
import plistlib
import zipfile
from pathlib import Path


def sha(data):
    return hashlib.sha256(data).hexdigest()


def measure(directory, model, embedded):
    options = plistlib.loads((directory / 'ExportOptions.plist').read_bytes())
    if options['method'] != 'debugging' or options['thinning'] != model:
        raise ValueError('Expected matching model-specific local debugging export')
    report_path = directory / 'app-thinning.plist'
    report = plistlib.loads(report_path.read_bytes())
    matches = [(name, v) for name, v in report['variants'].items()
               if any(d['device'] == model for d in v['variantDescriptors'])]
    if len(matches) != 1:
        raise ValueError('Expected exactly one variant supporting the requested model')
    name, variant = matches[0]
    ipa = directory / name
    with zipfile.ZipFile(ipa) as archive:
        fixture_names = [n for n in archive.namelist() if n.endswith('/fapi.json')]
        if len(fixture_names) != 1:
            raise ValueError('Expected a single packaged fixture')
        fixture_sha = sha(archive.read(fixture_names[0]))
        core_names = [n for n in archive.namelist() if n.endswith('/clerk-core.js')]
        if len(core_names) != (1 if embedded else 0):
            raise ValueError('Unexpected core asset presence')
        core = None
        if embedded:
            core_name = core_names[0]
            manifest = json.loads(archive.read(core_name.rsplit('/', 1)[0] + '/core-manifest.json'))
            if sha(archive.read(core_name)) != manifest['bundleSHA256']:
                raise ValueError('Exported core hash does not match its manifest')
            core = {k: manifest[k] for k in ['coreRevision', 'bundleSHA256', 'contractHash', 'bundleBytes']}
    result = {'ipaBytes': ipa.stat().st_size, 'ipaSHA256': sha(ipa.read_bytes()),
              'thinningReportSHA256': sha(report_path.read_bytes()), 'fixtureSHA256': fixture_sha,
              'matchingDescriptors': [d for d in variant['variantDescriptors'] if d['device'] == model],
              'sizeCompressedApp': variant['sizeCompressedApp'], 'sizeUncompressedApp': variant['sizeUncompressedApp'],
              'sizeCompressedODR': variant['sizeCompressedODR'], 'sizeUncompressedODR': variant['sizeUncompressedODR']}
    if core:
        result['core'] = core
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-export', type=Path, required=True)
    parser.add_argument('--embedded-export', type=Path, required=True)
    parser.add_argument('--model', required=True)
    parser.add_argument('--native-revision', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    baseline = measure(args.baseline_export, args.model, False)
    embedded = measure(args.embedded_export, args.model, True)
    if baseline['fixtureSHA256'] != embedded['fixtureSHA256'] or baseline['matchingDescriptors'] != embedded['matchingDescriptors']:
        raise ValueError('Exports are not matched')
    delta = {key: embedded[key] - baseline[key] for key in ['sizeCompressedApp', 'sizeUncompressedApp']}
    report = {'schemaVersion': 1, 'model': args.model, 'nativeRevision': args.native_revision,
              'method': 'Xcode local debugging export; model-specific thinning; existing development signing; Swift symbols stripped',
              'baseline': baseline, 'embedded': embedded, 'delta': delta,
              'compressedBudgetBytes': 5 * 1024 * 1024,
              'compressedWithinBudgetForThisExportEstimate': delta['sizeCompressedApp'] <= 5 * 1024 * 1024,
              'limitations': ['Xcode app-thinning estimate, not observed App Store download traffic',
                              'Development-signed export; distribution encryption and signing can change sizes',
                              'Uncompressed estimate is not measured physical-device filesystem allocation',
                              'Only the requested model variant is compared; native UI and explicit authentication presenters are excluded']}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, sort_keys=True, indent=2) + '\n')
    print(json.dumps(delta, indent=2))


if __name__ == '__main__':
    main()
