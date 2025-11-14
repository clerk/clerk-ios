//
//  DependencyContainer.swift
//  Clerk
//
//  Created by Mike Pitre on 2025-01-27.
//

import Foundation

/// Container that holds all dependencies for the Clerk SDK.
///
/// This class manages the lifecycle of all dependencies and provides them
/// through the `Dependencies` protocol for dependency injection.
final class DependencyContainer: Dependencies {
  // MARK: - Core Dependencies

  let networkingPipeline: NetworkingPipeline
  let keychain: any KeychainStorage
  let configurationManager: ConfigurationManager
  let apiClient: APIClient
  let telemetryCollector: any TelemetryCollectorProtocol

  // MARK: - Services

  let clientService: ClientServiceProtocol
  let userService: UserServiceProtocol
  let signInService: SignInServiceProtocol
  let signUpService: SignUpServiceProtocol
  let sessionService: SessionServiceProtocol
  let passkeyService: PasskeyServiceProtocol
  let organizationService: OrganizationServiceProtocol
  let environmentService: EnvironmentServiceProtocol
  let clerkService: ClerkServiceProtocol
  let emailAddressService: EmailAddressServiceProtocol
  let phoneNumberService: PhoneNumberServiceProtocol
  let externalAccountService: ExternalAccountServiceProtocol

  // MARK: - Logging

  let sessionStatusLogger: SessionStatusLogger

  // MARK: - Initialization

  /// Creates a new dependency container with the provided configuration.
  ///
  /// - Parameters:
  ///   - publishableKey: The publishable key from Clerk Dashboard.
  ///   - options: Configuration options for the Clerk instance.
  ///
  /// - Throws: `ClerkInitializationError` if the publishable key is invalid or configuration fails.
  @MainActor
  init(
    publishableKey: String,
    options: Clerk.ClerkOptions
  ) throws {
    // Phase 1: Core infrastructure (no dependencies)
    // Create and configure ConfigurationManager first (needed to determine baseURL)
    configurationManager = ConfigurationManager()

    // Only configure if publishableKey is not empty (temporary containers use empty key)
    // For temporary containers, ConfigurationManager will remain in its default unconfigured state
    if !publishableKey.isEmpty {
      try configurationManager.configure(publishableKey: publishableKey, options: options)
    }

    sessionStatusLogger = SessionStatusLogger()

    // Determine baseURL from configured manager (use default if not configured)
    let baseURL: URL
    if !publishableKey.isEmpty, !configurationManager.frontendApiUrl.isEmpty {
      baseURL = configurationManager.proxyConfiguration?.baseURL ?? URL(string: configurationManager.frontendApiUrl)!
    } else {
      // Temporary container fallback
      baseURL = URL(string: "https://clerk.clerk.dev")!
    }

    networkingPipeline = .clerkDefault
    keychain = SystemKeychain(
      service: options.keychainConfig.service,
      accessGroup: options.keychainConfig.accessGroup
    )

    // Phase 2: API client (depends on networkingPipeline)
    let pipeline = networkingPipeline
    apiClient = APIClient(baseURL: baseURL) { @Sendable configuration in
      configuration.pipeline = pipeline
      configuration.decoder = .clerkDecoder
      configuration.encoder = .clerkEncoder
      configuration.sessionConfiguration.httpAdditionalHeaders = [
        "Content-Type": "application/x-www-form-urlencoded",
        "clerk-api-version": Clerk.apiVersion,
        "x-ios-sdk-version": Clerk.sdkVersion,
        "x-mobile": "1",
      ]
    }

    // Phase 3: Telemetry collector (depends on options)
    if options.telemetryEnabled {
      let telemetryOptions = TelemetryCollectorOptions(
        samplingRate: 1.0,
        maxBufferSize: 5,
        flushInterval: 30.0,
        disableThrottling: options.debugMode
      )

      // Determine instance type from publishable key
      let instanceType: InstanceEnvironmentType = publishableKey.starts(with: "pk_live_") ? .production : .development

      telemetryCollector = TelemetryCollector(
        options: telemetryOptions,
        networkRequester: URLSession.shared,
        environment: StandaloneTelemetryEnvironment(
          publishableKey: publishableKey,
          instanceType: instanceType,
          telemetryEnabled: options.telemetryEnabled,
          debugMode: options.debugMode
        )
      )
    } else {
      telemetryCollector = NoOpTelemetryCollector()
    }

    // Phase 4: Services (depend on apiClient and other dependencies)
    // Pass apiClient directly to services
    clientService = ClientService(apiClient: apiClient)
    userService = UserService(apiClient: apiClient)
    signInService = SignInService(apiClient: apiClient)
    signUpService = SignUpService(apiClient: apiClient)
    sessionService = SessionService(apiClient: apiClient)
    passkeyService = PasskeyService(apiClient: apiClient)
    organizationService = OrganizationService(apiClient: apiClient)
    environmentService = EnvironmentService(apiClient: apiClient)
    clerkService = ClerkService(apiClient: apiClient)
    emailAddressService = EmailAddressService(apiClient: apiClient)
    phoneNumberService = PhoneNumberService(apiClient: apiClient)
    externalAccountService = ExternalAccountService(apiClient: apiClient)
  }
}
