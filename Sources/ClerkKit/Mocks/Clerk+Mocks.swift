//
//  Clerk+Mocks.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Builder for configuring mock services and environment in previews and tests.
///
/// Use this builder to configure custom behaviors for service methods and environment properties.
/// You can modify handler properties directly on the default services or replace entire services.
///
/// Example:
/// ```swift
/// // Modify handler properties directly (recommended)
/// builder.signInService.createHandler = { _, _ in
///   try? await Task.sleep(for: .seconds(2))
///   return .mock
/// }
///
/// builder.userService.getSessionsHandler = { user in
///   try? await Task.sleep(for: .seconds(1))
///   return [Session.mock, Session.mock2]
/// }
///
/// // Or replace entire services
/// builder.clientService = MockClientService {
///   try? await Task.sleep(for: .seconds(1))
///   return Client.mock
/// }
///
/// // Load environment from JSON file (recommended for previews)
/// let url = Bundle.main.url(forResource: "environment", withExtension: "json")!
/// builder.environment = try! Clerk.Environment(fromFile: url)
///
/// // Customize client properties like sessions
/// var client = Client.mock
/// client.sessions = [Session.mock, Session.mock2]
/// builder.client = client
/// ```
@MainActor
package final class MockBuilder {
  /// Mock client service for customizing `Client.get()` behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var clientService: MockClientService = .init()

  /// Mock user service for customizing `User` service methods behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var userService: MockUserService = .init()

  /// Mock sign-in service for customizing sign-in behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var signInService: MockSignInService = .init()

  /// Mock sign-up service for customizing sign-up behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var signUpService: MockSignUpService = .init()

  /// Mock session service for customizing session behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var sessionService: MockSessionService = .init()

  /// Mock passkey service for customizing passkey behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var passkeyService: MockPasskeyService = .init()

  /// Mock organization service for customizing organization behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var organizationService: MockOrganizationService = .init()

  /// Mock environment service for customizing `Environment.get()` behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var environmentService: MockEnvironmentService = .init()

  /// Mock email address service for customizing email address behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var emailAddressService: MockEmailAddressService = .init()

  /// Mock phone number service for customizing phone number behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var phoneNumberService: MockPhoneNumberService = .init()

  /// Mock external account service for customizing external account behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var externalAccountService: MockExternalAccountService = .init()

  /// Custom mock environment for configuring environment properties.
  /// If set, this environment will be used instead of the default `.mock` environment.
  ///
  /// The recommended approach is to load your environment from a JSON file:
  /// ```swift
  /// let url = Bundle.main.url(forResource: "environment", withExtension: "json")!
  /// builder.environment = try! Clerk.Environment(fromFile: url)
  /// ```
  package var environment: Clerk.Environment?

  /// Custom mock client for configuring client properties like sessions and user data.
  /// If set, this client will be used instead of the default `.mock` client.
  /// Assign a `Client` instance to configure it.
  ///
  /// Example:
  /// ```swift
  /// var client = Client.mock
  /// client.sessions = [Session.mock, Session.mock2]
  /// builder.client = client
  /// ```
  package var client: Client?

  /// Creates a new mock builder.
  ///
  /// All services are pre-initialized with default mock implementations.
  /// You can modify handler properties directly or replace entire services in the configuration closure.
  package init() {}
}

package extension Clerk {
  /// Configures Clerk.shared with mock services and environment.
  ///
  /// This function allows you to inject custom mock services (like `MockClientService`) and configure
  /// environment properties to control behavior without making real API calls. This is useful for SwiftUI previews
  /// and testing scenarios.
  ///
  /// **Important:** This function only works when compiled with DEBUG configuration. In release builds,
  /// it returns `Clerk.shared` if already configured, or configures Clerk with an empty publishable key.
  ///
  /// - Parameters:
  ///   - builder: An optional closure that receives a `MockBuilder` for configuring mock services, environment, and client.
  ///                        If not provided, all services, environment, and client will use their default mock implementations.
  ///
  /// Example:
  /// ```swift
  /// // Use default mock services
  /// Clerk.configureWithMocks()
  ///
  /// // Or customize specific service handlers
  /// Clerk.configureWithMocks { builder in
  ///   builder.signInService.createHandler = { _, _ in
  ///     try? await Task.sleep(for: .seconds(2))
  ///     return .mock
  ///   }
  ///
  ///   builder.userService.getSessionsHandler = { user in
  ///     try? await Task.sleep(for: .seconds(1))
  ///     return [Session.mock, Session.mock2]
  ///   }
  /// }
  ///
  /// // Load environment from JSON file for previews
  /// Clerk.configureWithMocks { builder in
  ///   let url = Bundle.main.url(forResource: "environment", withExtension: "json")!
  ///   builder.environment = try! Clerk.Environment(fromFile: url)
  ///
  ///   // Customize client
  ///   var client = Client.mock
  ///   client.sessions = [Session.mock, Session.mock2]
  ///   builder.client = client
  /// }
  /// ```
  ///
  /// To reuse a mock configuration across multiple previews, create a helper function:
  /// ```swift
  /// @MainActor
  /// func createPreviewClerk() -> Clerk {
  ///   Clerk.configureWithMocks { builder in
  ///     let url = Bundle.main.url(forResource: "environment", withExtension: "json")!
  ///     builder.environment = try! Clerk.Environment(fromFile: url)
  ///   }
  /// }
  ///
  /// #Preview {
  ///   MyView()
  ///     .environment(createPreviewClerk())
  /// }
  /// ```
  @MainActor
  @discardableResult
  static func configureWithMocks(
    builder: ((MockBuilder) -> Void)? = nil
  ) -> Clerk {
    #if DEBUG
    // Configure Clerk.shared if not already configured
    let clerk = Clerk.configure(publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk")

    // Create a minimal API client (won't be used if services are mocked)
    let mockBaseURL = URL(string: "https://mock.clerk.accounts.dev")!
    let mockAPIClient = APIClient(baseURL: mockBaseURL)

    // Create mock builder
    let mockBuilder = MockBuilder()

    // Try to load ClerkEnvironment.json from bundle, fall back to .mock if it fails
    if let url = Bundle.main.url(forResource: "ClerkEnvironment", withExtension: "json"),
       let environment = try? Clerk.Environment(fromFile: url)
    {
      mockBuilder.environment = environment
    }

    builder?(mockBuilder)

    // Determine which environment to use: custom from builder, or default .mock
    let mockEnvironment = mockBuilder.environment ?? .mock

    // Determine which client to use: custom from builder, or default .mock
    let mockClient = mockBuilder.client ?? .mock

    // If builder has a custom environment, update the environmentService to return it
    let environmentService: MockEnvironmentService = if mockBuilder.environment != nil {
      MockEnvironmentService {
        mockEnvironment
      }
    } else {
      mockBuilder.environmentService
    }

    // If builder has a custom client, update the clientService to return it
    let clientService: MockClientService = if mockBuilder.client != nil {
      MockClientService {
        mockClient
      }
    } else {
      mockBuilder.clientService
    }

    // Create mock dependency container with mock services
    let container = MockDependencyContainer(
      apiClient: mockAPIClient,
      clientService: clientService,
      userService: mockBuilder.userService,
      signInService: mockBuilder.signInService,
      signUpService: mockBuilder.signUpService,
      sessionService: mockBuilder.sessionService,
      passkeyService: mockBuilder.passkeyService,
      organizationService: mockBuilder.organizationService,
      environmentService: environmentService,
      emailAddressService: mockBuilder.emailAddressService,
      phoneNumberService: mockBuilder.phoneNumberService,
      externalAccountService: mockBuilder.externalAccountService
    )

    // Replace dependencies with mock services
    clerk.dependencies = container
    clerk._auth = nil // Force auth to reinitialize with new mock services
    clerk.client = mockClient
    clerk.environment = mockEnvironment

    return clerk
    #else
    // In release builds, return Clerk.shared
    return Clerk.shared
    #endif
  }
}
