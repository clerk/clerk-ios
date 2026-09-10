import { requireNativeModule } from 'expo';
import { getClerkInstance } from '@clerk/expo';

export async function measureNativeResets() {
  const proof = (globalThis as any).__clerkProof;
  if (!(globalThis as any).HermesInternal || !proof) throw new Error('Hermes fixture required');
  const owner = getClerkInstance();
  const requestsBefore = proof.requests.length;
  const gaps: number[] = [];
  let lastTick = performance.now();
  const interval = setInterval(() => {
    const now = performance.now();
    gaps.push(now - lastTick);
    lastTick = now;
  }, 16);
  try {
    const native = await requireNativeModule('ClerkExpo').measureFixtureNativeResets();
    if (proof.requests.length !== requestsBefore) throw new Error('HTTP occurred during local reset measurement');
    if (getClerkInstance() !== owner || !native.sameNativeOwner) throw new Error('Owner changed during measurement');
    if (native.sampleCount !== 300 || native.nativeResetMilliseconds.length !== 300) throw new Error('Incomplete samples');
    const sorted = [...native.nativeResetMilliseconds].sort((a, b) => a - b);
    const report = {
      ...native, engine: 'Hermes', sameJavaScriptOwner: true, httpRequestDelta: 0,
      javaScriptTimerGapsMilliseconds: gaps,
      nativeResetSummary: { median: sorted[149], p95: sorted[284], p99: sorted[296], maximum: sorted[299] },
      limitations: [
        'Diagnostic fixture build; one warm app process, 10 warmups, 300 native calls',
        'Per-call timer includes native to Hermes transport, dispatch, native state application and resumption',
        'Frame and timer gaps are responsiveness diagnostics, not trace-attributed stalls',
        'Process memory snapshots are not incremental memory or startup peak measurements',
        'Core and contract identities require the separate exact application-build receipt',
        'No real service, platform prompts, cold startup or physical-device acceptance implied',
      ],
    };
    console.log('[CLERK_EXPO_NATIVE_MEASUREMENT]', JSON.stringify(report));
    return report;
  } finally { clearInterval(interval); }
}
