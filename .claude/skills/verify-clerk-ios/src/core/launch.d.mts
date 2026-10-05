export function ensureRuntime(): Promise<void>;
export function chooseEgress(observed: { readonly proxyListens: boolean; readonly directConnects: boolean; readonly tokenStatusDirect: number | null }): { readonly proxy: boolean; readonly why: string };
