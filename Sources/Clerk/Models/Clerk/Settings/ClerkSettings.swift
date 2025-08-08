//
//  ClerkSettings.swift
//  Clerk
//
//  Created by Mike Pitre on 6/30/25.
//

import Foundation

extension Clerk {

    /// A configuration object that can be passed to `Clerk.configure()` to customize various aspects of the Clerk SDK behavior.
    public struct Settings: Sendable {

        /// Enable additional debugging signals and logging. Defaults to false.
        public let debugMode: Bool

        /// Enable development telemetry collection. Defaults to true.
        public let telemetryEnabled: Bool

        /// Configuration for keychain storage behavior.
        public let keychainConfig: KeychainConfig

        /// Configuration for OAuth redirect URLs and callback handling.
        public let redirectConfig: RedirectConfig

        /// Initializes a ``Settings`` instance.
        /// - Parameters:
        ///   - debugMode: Enable additional debugging signals and logging. Defaults to false.
        ///   - keychainConfig: Configuration for keychain storage behavior. Defaults to a new KeychainConfig instance.
        ///   - redirectConfig: Configuration for OAuth redirect URLs and callback handling. Defaults to a new RedirectConfig instance.
        public init(
            debugMode: Bool = false,
            telemetryEnabled: Bool = true,
            keychainConfig: KeychainConfig = .init(),
            redirectConfig: RedirectConfig = .init()
        ) {
            self.debugMode = debugMode
            self.telemetryEnabled = telemetryEnabled
            self.keychainConfig = keychainConfig
            self.redirectConfig = redirectConfig
        }
    }

}
