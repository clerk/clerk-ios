//
//  ClerkOptions.swift
//  Clerk
//
//  Created by Mike Pitre on 6/30/25.
//

import Foundation

extension Clerk {

    /// A configuration object that can be passed to `Clerk.configure()` to customize various aspects of the Clerk SDK behavior.
    public struct ClerkOptions: Sendable {

        /// Enable additional debugging signals and logging. Defaults to false.
        public let debugMode: Bool

        /// Enable development telemetry collection. Defaults to true.
        public let telemetryEnabled: Bool

        /// Configuration for keychain storage behavior.
        public let keychainConfig: KeychainConfig

        /// Your Clerk app's proxy URL. Required for applications that run behind a reverse proxy. Must be a full URL (for example, https://proxy.example.com/__clerk).
        public let proxyUrl: URL?

        /// Configuration for OAuth redirect URLs and callback handling.
        public let redirectConfig: RedirectConfig

        /// Initializes a ``ClerkOptions`` instance.
        /// - Parameters:
        ///   - debugMode: Enable additional debugging signals and logging. Defaults to false.
        ///   - telemetryEnabled: Enable development telemetry collection. Defaults to true.
        ///   - keychainConfig: Configuration for keychain storage behavior. Defaults to a new KeychainConfig instance.
        ///   - proxyUrl: Your Clerk app's proxy URL. Required for applications that run behind a reverse proxy—must be a full URL (e.g. https://proxy.example.com/__clerk). Defaults to nil.
        ///   - redirectConfig: Configuration for OAuth redirect URLs and callback handling. Defaults to a new RedirectConfig instance.
        public init(
            debugMode: Bool = false,
            telemetryEnabled: Bool = true,
            keychainConfig: KeychainConfig = .init(),
            proxyUrl: String? = nil,
            redirectConfig: RedirectConfig = .init()
        ) {
            self.debugMode = debugMode
            self.telemetryEnabled = telemetryEnabled
            self.keychainConfig = keychainConfig
            self.proxyUrl = proxyUrl.flatMap { URL(string: $0) }
            self.redirectConfig = redirectConfig
        }
    }

}
