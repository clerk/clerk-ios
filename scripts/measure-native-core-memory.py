#!/usr/bin/env python3
"""Collect matched physical baseline/embedded memory samples without a debugger."""
import argparse
import datetime
import gzip
import hashlib
import json
import plistlib
import statistics
import subprocess
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command, stem):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=140)
    except subprocess.TimeoutExpired as error:
        def text(value):
            return value.decode(errors='replace') if isinstance(value, bytes) else (value or '')
        stem.with_suffix('.log').write_text(text(error.stdout) + text(error.stderr))
        raise RuntimeError(f'Timed out; retained {stem}.log; no retry') from error
    stem.with_suffix('.log').write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(f'Command failed; retained {stem}.log; no retry')
    return result.stdout + result.stderr


def summarize(report):
    samples = report['samples']
    phases = {}
    metrics = ['physicalFootprintBytes', 'residentBytes', 'internalBytes', 'externalBytes', 'compressedBytes',
               'processLifetimeFootprintPeakBytes']
    cycle_phases = ['startup', 'warmup', 'steadyWait', 'steady', 'close', 'closedWait', 'closed']
    stress = report.get('mode') == 'stress'
    names = ['before'] + ([f'cycle-{i}-{p}' for i in range(1, report['cycleCount'] + 1) for p in cycle_phases]
                          if stress else cycle_phases)
    for phase in names:
        selected = [s for s in samples if s['phase'] == phase]
        if not selected:
            raise ValueError(f'Missing sampled phase {phase}')
        phases[phase] = {
            'count': len(selected),
            'spanMilliseconds': (selected[-1]['elapsedNanoseconds'] - selected[0]['elapsedNanoseconds']) / 1e6,
            **{metric: {'minimum': min(s[metric] for s in selected),
                        'median': statistics.median(s[metric] for s in selected),
                        'maximum': max(s[metric] for s in selected)} for metric in metrics},
        }
    for name in names:
        if name.endswith(('steady', 'closed')) and phases[name]['spanMilliseconds'] < (400 if stress else 900):
            raise ValueError('Incomplete steady/closed observation windows')
    intervals = [(b['elapsedNanoseconds'] - a['elapsedNanoseconds']) / 1e6 for a, b in zip(samples, samples[1:])]
    if any(v < 0 for v in intervals):
        raise ValueError('Nonmonotonic sampler timestamps')
    return {'phases': phases, 'maximumSamplingGapMilliseconds': max(intervals),
            'medianSamplingGapMilliseconds': statistics.median(intervals),
            'processLifetimeFootprintPeakBytes': max(s['processLifetimeFootprintPeakBytes'] for s in samples)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--model', required=True)
    parser.add_argument('--native-revision', required=True)
    parser.add_argument('--products', required=True, type=Path)
    parser.add_argument('--raw-directory', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--pairs', default=3, type=int)
    parser.add_argument('--stress', action='store_true', help='Twelve sequential owner lifecycles per embedded process')
    args = parser.parse_args()
    cycles = 12 if args.stress else 1
    report_name = 'core-memory-stress.json' if args.stress else 'core-memory.json'
    if args.pairs < 1:
        parser.error('At least one pair is required')
    raw = args.raw_directory.resolve()
    if raw.exists() and any(raw.iterdir()):
        parser.error('Use a new empty raw directory; previous evidence must be retained')
    raw.mkdir(parents=True, exist_ok=True)
    identities = {}
    for variant in ['baseline', 'embedded']:
        app = args.products / f'{variant.title()}.app'
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        bundle_id = f'com.clerk.nativecore.footprint.{variant}'
        if info['CFBundleIdentifier'] != bundle_id:
            raise ValueError(f'Unexpected {variant} app')
        identities[variant] = {'bundleIdentifier': bundle_id, 'executableSHA256': digest(app / info['CFBundleExecutable'])}
    pairs, process_ids = [], set()
    for index in range(args.pairs):
        pair = {'index': index + 1}
        # Alternate order to expose consistent first/second-launch bias.
        order = ['baseline', 'embedded'] if index % 2 == 0 else ['embedded', 'baseline']
        pair['order'] = order
        for variant in order:
            stem = raw / f'pair-{index + 1:02d}-{variant}'
            bundle_id = identities[variant]['bundleIdentifier']
            console = run(['xcrun', 'devicectl', 'device', 'process', 'launch', '--device', args.device,
                           '--console', '--terminate-existing', '--timeout', '130' if args.stress else '55',
                           '--json-output', str(stem.with_suffix('.launch.json')), bundle_id,
                           '--memory-stress' if args.stress else '--memory', '--exit-after-ready'], stem)
            marker = 'CLERK_CORE_MEMORY_STRESS_WRITTEN ' if args.stress else 'CLERK_CORE_MEMORY_WRITTEN '
            if marker not in console or 'CLERK_CORE_FOOTPRINT_READY ' + bundle_id not in console:
                raise RuntimeError(f'{variant} did not complete; retained evidence; no retry')
            destination = stem.with_suffix('.memory.json')
            run(['xcrun', 'devicectl', 'device', 'copy', 'from', '--device', args.device,
                 '--domain-type', 'appDataContainer', '--domain-identifier', bundle_id,
                 '--source', 'Documents/' + report_name, '--destination', str(destination),
                 '--timeout', '30'], raw / f'pair-{index + 1:02d}-{variant}-copy')
            report = json.loads(destination.read_text())
            compressed = destination.with_suffix('.json.gz')
            compressed.write_bytes(gzip.compress(destination.read_bytes(), mtime=0))
            if report['schemaVersion'] != 1 or report['variant'] != variant or report['forcedCollection']:
                raise ValueError('Unexpected memory report')
            if report.get('cycleCount') != cycles or report.get('mode') != ('stress' if args.stress else 'single'):
                raise ValueError('Unexpected workload mode')
            if report['processID'] in process_ids:
                raise ValueError('Expected a fresh process for each measurement')
            process_ids.add(report['processID'])
            if variant == 'embedded' and (report.get('ownerCount') != 1 or not report.get('authenticatedAtReady')
                                         or not report.get('ownerReleasedAfterClose') or report.get('warmupResets') != 50 * cycles):
                raise ValueError('Embedded owner lifecycle was not verified')
            if variant == 'embedded':
                checks = report.get('cycleAssertions', [])
                if len(checks) != cycles or any(not c.get('authenticatedAtReady') or not c.get('ownerReleasedAfterClose')
                                               or not c.get('runtimeReleasedAfterClose') or c.get('warmupResets') != 50
                                               for c in checks):
                    raise ValueError('Per-cycle owner/runtime release was not verified')
            if variant == 'baseline' and report['ownerCount'] != 0:
                raise ValueError('Baseline unexpectedly created an owner')
            pair[variant] = {'collectedAtUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                             'rawFile': destination.name, 'rawSHA256': digest(destination),
                             'compressedRawFile': compressed.name, 'compressedRawSHA256': digest(compressed),
                             'report': {k: v for k, v in report.items() if k != 'samples'},
                             'summary': summarize(report)}
            print(f'Pair {index + 1}/{args.pairs} {variant}: {len(report["samples"])} samples', flush=True)
        baseline, embedded = pair['baseline']['summary'], pair['embedded']['summary']
        selected_phases = ([f'cycle-{i}-{phase}' for i in range(1, cycles + 1) for phase in ['startup', 'steady', 'closed']]
                           if args.stress else ['startup', 'steady', 'closed'])
        pair['incrementalBytes'] = {
            phase: {metric: embedded['phases'][phase][metric][stat] - baseline['phases'][phase][metric][stat]
                    for metric in ['physicalFootprintBytes', 'residentBytes']}
            for phase in selected_phases for stat in ['maximum' if phase.endswith('startup') else 'median']
        }
        pairs.append(pair)
    root = Path(__file__).resolve().parent.parent
    result = {'schemaVersion': 1, 'model': args.model, 'nativeRevision': args.native_revision,
              'harnessSourceSHA256': digest(root / 'Examples/CoreFootprint/CoreFootprintApp.swift'),
              'appIdentities': identities, 'pairCount': args.pairs, 'mode': 'stress' if args.stress else 'single',
              'cyclesPerEmbeddedProcess': cycles, 'pairs': pairs,
              'limitations': ['One physical device; fixture HTTP and in-memory credentials',
                              'Off-main-thread 5 ms requested sampling; gaps retained; sub-sample peaks may be missed',
                              'Process VM categories are not separate Swift and JavaScript heap attribution',
                              'Sampler and retained samples contribute to both app measurements',
                              ('Twelve sequential lifecycles per process do not prove unbounded lifetime stability'
                               if args.stress else 'Single-owner close observations are not a repeated connect/close stress test'),
                              'No forced garbage collection or allocator purge; no debugger',
                              'Memory phases do not measure UI responsiveness or real authentication']}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, sort_keys=True, indent=2) + '\n')
    print(json.dumps([{'pair': p['index'], 'incrementalBytes': p['incrementalBytes']} for p in pairs], indent=2))


if __name__ == '__main__':
    main()
