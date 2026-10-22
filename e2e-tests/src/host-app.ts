import { join } from 'node:path';

export const BUILD_INPUTS = ['Sources', 'Examples/E2EHost', 'Examples/Quickstart/Quickstart.xcodeproj', 'Package.swift', 'Clerk.xcworkspace'] as const;

export const WORKSPACE = 'Clerk.xcworkspace';
export const SCHEME = 'E2EHost';

export const BUILD_HOST = ['build', '-quiet', '-workspace', WORKSPACE, '-scheme', SCHEME, '-configuration', 'Debug', '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath'] as const;

export const builtHost = (derived: string): string => join(derived, 'Build', 'Products', 'Debug-iphonesimulator', 'E2EHost.app');
