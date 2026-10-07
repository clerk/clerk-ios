import { join } from 'node:path';

export const BUILD_HOST = ['build', '-quiet', '-workspace', 'Clerk.xcworkspace', '-scheme', 'E2EHost', '-configuration', 'Debug', '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath'] as const;

export const builtHost = (derived: string): string => join(derived, 'Build', 'Products', 'Debug-iphonesimulator', 'E2EHost.app');
