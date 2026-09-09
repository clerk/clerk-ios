#!/usr/bin/env python3
"""Run the CoreFootprint fixture in fresh, debugger-free iPhone app processes."""
import argparse
import datetime
import hashlib
import plistlib
import statistics
import json
import math
import subprocess
from pathlib import Path

BUNDLE_ID = 'com.clerk.nativecore.footprint.embedded'
MARKER = 'CLERK_CORE_BENCHMARK '


def summary(values):
    ordered = sorted(values)
    return {'count': len(values), 'first': values[0], 'minimum': ordered[0],
            'median': statistics.median(values),
            'p95': ordered[math.ceil(len(ordered) * .95) - 1],
            'p99': ordered[math.ceil(len(ordered) * .99) - 1],
            'maximum': ordered[-1]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True, help='Paired device identifier; not included in report')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--raw-directory', required=True, type=Path)
    parser.add_argument('--model', required=True, help='Device model verified with devicectl device info details')
    parser.add_argument('--native-revision', required=True)
    parser.add_argument('--app-bundle', required=True, type=Path, help='Exact release app installed before this run')
    parser.add_argument('--runs', default=30, type=int)
    args = parser.parse_args()
    if args.runs < 30:
        parser.error('Release measurement requires at least 30 fresh processes')
    args.raw_directory = args.raw_directory.resolve()
    if args.raw_directory.exists() and any(args.raw_directory.iterdir()):
        parser.error('Use a new empty raw directory; previous run evidence must be preserved')
    args.raw_directory.mkdir(parents=True, exist_ok=True)
    app_info = plistlib.loads((args.app_bundle / 'Info.plist').read_bytes())
    if app_info['CFBundleIdentifier'] != BUNDLE_ID:
        raise ValueError('Expected the embedded measurement app')
    app_sha = hashlib.sha256((args.app_bundle / app_info['CFBundleExecutable']).read_bytes()).hexdigest()
    samples = []
    for index in range(args.runs):
        stem = args.raw_directory / f'run-{index + 1:02d}'
        command = ['xcrun', 'devicectl', 'device', 'process', 'launch', '--device', args.device,
                   '--console', '--terminate-existing', '--timeout', '40',
                   '--json-output', str(stem.with_suffix('.json')), BUNDLE_ID,
                   '--benchmark', '--exit-after-ready']
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=50)
        except subprocess.TimeoutExpired as error:
            def decoded(value):
                return value.decode(errors='replace') if isinstance(value, bytes) else (value or '')
            stem.with_suffix('.log').write_text(decoded(error.stdout) + decoded(error.stderr))
            raise RuntimeError(f'Run {index + 1} timed out; raw output retained in {stem}.log') from error
        console = result.stdout + result.stderr
        stem.with_suffix('.log').write_text(console)
        reports = [line.split(MARKER, 1)[1] for line in console.splitlines() if MARKER in line]
        if result.returncode or len(reports) != 1 or 'CLERK_CORE_FOOTPRINT_READY ' + BUNDLE_ID not in console:
            raise RuntimeError(f'Run {index + 1} failed; see {stem}.log. No samples were retried or discarded.')
        sample = json.loads(reports[0])
        sample['collectedAtUTC'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        if len(sample['localResetMilliseconds']) != 10 or sample['httpRequestsAtReady'] != sample['httpRequestsAfterResets']:
            raise RuntimeError(f'Run {index + 1} did not satisfy the operation contract')
        if any(previous['processID'] == sample['processID'] for previous in samples):
            raise RuntimeError('Expected a fresh process ID for each sample')
        samples.append(sample)
        print(f"Run {index + 1}/{args.runs}: startup {sample['startupMilliseconds']:.2f} ms", flush=True)
    for field in ['coreRevision', 'bundleSHA256', 'operatingSystem']:
        if len({sample[field] for sample in samples}) != 1:
            raise RuntimeError(f'Inconsistent {field}')
    starts = [s['startupMilliseconds'] for s in samples]
    calls = [v for s in samples for v in s['localResetMilliseconds']]
    startup_summary, reset_summary = summary(starts), summary(calls)
    report = {
        'schemaVersion': 1, 'model': args.model, 'nativeRevision': args.native_revision,
        'installedAppExecutableSHA256': app_sha,
        'harnessSourceSHA256': hashlib.sha256((Path(__file__).resolve().parent.parent / 'Examples/CoreFootprint/CoreFootprintApp.swift').read_bytes()).hexdigest(),
        'build': 'Release, Swift -O wholemodule, arm64, development signed, no debugger',
        'engine': 'JavaScriptCore (system)', 'coreRevision': samples[0]['coreRevision'],
        'bundleSHA256': samples[0]['bundleSHA256'], 'operatingSystem': samples[0]['operatingSystem'],
        'startupDefinition': 'Clerk.connect: resource read, SHA verification, fresh engine, load, fixture HTTP, native projection',
        'operationDefinition': 'Await generated signIn.reset including projection; verify old group invalidated and zero additional HTTP',
        'startupSummaryMilliseconds': startup_summary, 'localResetSummaryMilliseconds': reset_summary,
        'firstFreshProcessStartupMilliseconds': starts[0],
        'subsequentFreshProcessStartupSummaryMilliseconds': summary(starts[1:]),
        'budgets': {'startupP95Milliseconds': 150, 'localResetP95Milliseconds': 10, 'localResetP99Milliseconds': 16,
                    'startupWithinBudgetForThisDevice': startup_summary['p95'] <= 150,
                    'localResetWithinBudgetForThisDevice': reset_summary['p95'] <= 10 and reset_summary['p99'] <= 16},
        'samples': samples,
        'limitations': ['One physical device; does not establish the slowest supported performance tier',
                       'Fresh processes, not device reboots or guaranteed cold OS filesystem caches',
                       'The first reported process may follow earlier functional smoke launches',
                       'Fixture HTTP and in-memory storage exclude service and secure-storage latency',
                       'One unmeasured reset warms the local path before ten measured resets per process',
                       'No startup peak, steady-state memory, UI responsiveness or real-authentication measurement'],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print(json.dumps({k: report[k] for k in ['startupSummaryMilliseconds', 'localResetSummaryMilliseconds', 'budgets']}, indent=2))


if __name__ == '__main__':
    main()
