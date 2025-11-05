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

  // MARK: - Initialization

  /// Creates a new dependency container with the provided configuration.
  ///
  /// - Parameters:
  ///   - publishableKey: The publishable key from Clerk Dashboard.
  ///   - options: Configuration options for the Clerk instance.
  ///   - baseURL: The base URL for API requests (derived from publishable key or proxy).
  init(
    publishableKey: String,
    options: Clerk.ClerkOptions,
    baseURL: URL
  ) {
    // Phase 1: Core infrastructure (no dependencies)
    networkingPipeline = .clerkDefault
    keychain = SystemKeychain(
      service: options.keychainConfig.service,
      accessGroup: options.keychainConfig.accessGroup
    )

    // Phase 2: API client (depends on networkingPipeline)
    let pipeline = networkingPipeline
    apiClient = APIClient(baseURL: baseURL) { configuration in
      configuration.pipeline = pipeline
      configuration.decoder = .clerkDecoder
      configuration.encoder = .clerkEncoder
      configuration.sessionConfiguration.httpAdditionalHeaders = [
        "Content-Type": "application/x-www-form-urlencoded",
        "clerk-api-version": Clerk.apiVersion,
        "x-ios-sdk-version": Clerk.sdkVersion,
        "x-mobile": "1"
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
