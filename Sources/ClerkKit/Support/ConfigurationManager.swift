//
//  ConfigurationManager.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import FactoryKit
import Foundation
import RegexBuilder

/// Manages Clerk configuration including API client setup, keychain registration, and options management.
///
/// This class centralizes configuration logic to avoid cascading didSet observers and provides
/// a single point for configuring the Clerk SDK.
@MainActor
final class ConfigurationManager {
    
    /// Configuration state for the Clerk instance.
    struct ConfigurationState {
        var publishableKey: String = ""
        var frontendApiUrl: String = ""
        var proxyUrl: URL?
        var proxyConfiguration: ProxyConfiguration?
        var options: Clerk.ClerkOptions = .init()
        var isConfigured: Bool = false
    }
    
    private var state = ConfigurationState()
    
    /// Configures the Clerk instance with the provided publishable key and options.
    ///
    /// - Parameters:
    ///   - publishableKey: The publishable key from Clerk Dashboard.
    ///   - options: Configuration options for the Clerk instance.
    ///
    /// - Throws: `ClerkInitializationError` if the publishable key is invalid or configuration fails.
    func configure(publishableKey: String, options: Clerk.ClerkOptions) throws {
        // Validate publishable key early for fail-fast behavior
        try validatePublishableKey(publishableKey)
        
        state.publishableKey = publishableKey
        state.options = options
        
        // Extract frontend API URL from publishable key
        state.frontendApiUrl = try extractFrontendApiUrl(from: publishableKey)
        
        // Set proxy URL from options
        state.proxyUrl = options.proxyUrl
        state.proxyConfiguration = ProxyConfiguration(url: state.proxyUrl)
        
        // Register options and keychain in container
        registerOptions()
        registerKeychain()
        
        // Configure API client
        configureAPIClient()
        
        // Register telemetry collector
        registerTelemetryCollector()
        
        state.isConfigured = true
    }
    
    /// Updates the proxy URL configuration.
    ///
    /// - Parameter proxyUrl: The new proxy URL, or nil to remove proxy configuration.
    func updateProxyUrl(_ proxyUrl: URL?) {
        state.proxyUrl = proxyUrl
        state.proxyConfiguration = ProxyConfiguration(url: proxyUrl)
        
        if state.isConfigured {
            configureAPIClient()
        }
    }
    
    /// Updates the frontend API URL and reconfigures the API client.
    ///
    /// - Parameter frontendApiUrl: The new frontend API URL.
    func updateFrontendApiUrl(_ frontendApiUrl: String) {
        state.frontendApiUrl = frontendApiUrl
        
        if state.isConfigured {
            configureAPIClient()
        }
    }
    
    /// Returns the current frontend API URL.
    var frontendApiUrl: String {
        state.frontendApiUrl
    }
    
    /// Returns the current proxy configuration.
    var proxyConfiguration: ProxyConfiguration? {
        state.proxyConfiguration
    }
    
    /// Returns the current proxy URL.
    var proxyUrl: URL? {
        state.proxyUrl
    }
    
    /// Returns the current publishable key.
    var publishableKey: String {
        state.publishableKey
    }
    
    /// Returns the current configuration options.
    var options: Clerk.ClerkOptions {
        state.options
    }
    
    /// Returns the instance environment type based on the publishable key.
    var instanceType: InstanceEnvironmentType {
        if state.publishableKey.starts(with: "pk_live_") {
            return .production
        }
        return .development
    }
    
    /// Validates the publishable key format and throws an error if invalid.
    ///
    /// - Parameter key: The publishable key to validate.
    /// - Throws: `ClerkInitializationError` if the key is empty or has an invalid format.
    private func validatePublishableKey(_ key: String) throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedKey.isEmpty else {
            throw ClerkInitializationError.missingPublishableKey
        }
        
        guard trimmedKey.starts(with: "pk_test_") || trimmedKey.starts(with: "pk_live_") else {
            throw ClerkInitializationError.invalidPublishableKeyFormat(key: trimmedKey)
        }
    }
    
    /// Extracts the frontend API URL from a publishable key.
    ///
    /// The publishable key contains encoded information that can be used to derive the API URL.
    /// Assumes the publishable key has already been validated.
    ///
    /// - Parameter publishableKey: The publishable key to extract the URL from (must be validated).
    /// - Returns: The extracted frontend API URL.
    /// - Throws: `ClerkInitializationError.invalidPublishableKeyFormat` if the key format is invalid.
    private func extractFrontendApiUrl(from publishableKey: String) throws -> String {
        let liveRegex = Regex {
            "pk_live_"
            Capture {
                OneOrMore(.any)
            }
        }
        
        let testRegex = Regex {
            "pk_test_"
            Capture {
                OneOrMore(.any)
            }
        }
        
        guard let match = publishableKey.firstMatch(of: liveRegex)?.output.1 ?? publishableKey.firstMatch(of: testRegex)?.output.1,
              let apiUrl = String(match).base64String()
        else {
            throw ClerkInitializationError.invalidPublishableKeyFormat(key: publishableKey)
        }
        
        return "https://\(apiUrl.dropLast())"
    }
    
    /// Registers the options in the container.
    private func registerOptions() {
        Container.shared.clerkOptions.register { [options = state.options] in
            options
        }
    }
    
    /// Registers the keychain in the container based on options.
    private func registerKeychain() {
        let keychainConfig = state.options.keychainConfig
        Container.shared.keychain.register {
            SystemKeychain(
                service: keychainConfig.service,
                accessGroup: keychainConfig.accessGroup
            ) as any KeychainStorage
        }
    }
    
    /// Configures the API client with the current configuration state.
    private func configureAPIClient() {
        guard let baseUrl = state.proxyConfiguration?.baseURL ?? URL(string: state.frontendApiUrl) else {
            ClerkLogger.error("Failed to configure API client: invalid base URL")
            return
        }
        
        Container.shared.apiClient.register { [baseUrl] in
            APIClient(baseURL: baseUrl) { configuration in
                configuration.pipeline = Container.shared.networkingPipeline()
                configuration.decoder = .clerkDecoder
                configuration.encoder = .clerkEncoder
                configuration.sessionConfiguration.httpAdditionalHeaders = [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "clerk-api-version": "2025-04-10",
                    "x-ios-sdk-version": Clerk.version,
                    "x-mobile": "1"
                ]
            }
        }
    }
    
    /// Registers the telemetry collector in the container based on options.
    private func registerTelemetryCollector() {
        if state.options.telemetryEnabled {
            let telemetryOptions = TelemetryCollectorOptions(
                samplingRate: 1.0,
                maxBufferSize: 5,
                flushInterval: 30.0,
                disableThrottling: state.options.debugMode
            )
            Container.shared.telemetryCollector.register {
                TelemetryCollector(options: telemetryOptions)
            }
        }
    }
}

