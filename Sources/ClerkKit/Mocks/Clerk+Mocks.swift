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
public final class MockBuilder {
  /// Mock client service for customizing `Client.get()` behavior.
  /// You can modify handler properties directly or replace the entire service.
  public var clientService: MockClientService = MockClientService()

  /// Mock user service for customizing `User` service methods behavior.
  /// You can modify handler properties directly or replace the entire service.
  public var userService: MockUserService = MockUserService()

  /// Mock sign-in service for customizing sign-in behavior.
  /// You can modify handler properties directly or replace the entire service.
  public var signInService: MockSignInService = MockSignInService()

  /// Mock sign-up service for customizing sign-up behavior.
  /// You can modify handler properties directly or replace the entire service.
  public var signUpService: MockSignUpService = MockSignUpService()

  /// Mock session service for customizing session behavior.
  /// You can modify handler properties directly or replace the entire service.
  public var sessionService: MockSessionService = MockSessionService()

  /// Mock passkey service for customizing passkey behavior.
  /// You can modify handler properties directly or replace the entire service.
  public var passkeyService: MockPasskeyService = MockPasskeyService()

  /// Mock organization service for customizing organization behavior.
  /// You can modify handler properties directly or replace the entire service.
  public var organizationService: MockOrganizationService = MockOrganizationService()

  /// Mock environment service for customizing `Environment.get()` behavior.
  /// You can modify handler properties directly or replace the entire service.
  public var environmentService: MockEnvironmentService = MockEnvironmentService()

  /// Mock clerk service for customizing clerk operations.
  /// You can modify handler properties directly or replace the entire service.
  public var clerkService: MockClerkService = MockClerkService()

  /// Mock email address service for customizing email address behavior.
  /// You can modify handler properties directly or replace the entire service.
  public var emailAddressService: MockEmailAddressService = MockEmailAddressService()

  /// Mock phone number service for customizing phone number behavior.
  /// You can modify handler properties directly or replace the entire service.
  public var phoneNumberService: MockPhoneNumberService = MockPhoneNumberService()

  /// Mock external account service for customizing external account behavior.
  /// You can modify handler properties directly or replace the entire service.
  public var externalAccountService: MockExternalAccountService = MockExternalAccountService()

  /// Custom mock environment for configuring environment properties.
  /// If set, this environment will be used instead of the default `.mock` environment.
  ///
  /// The recommended approach is to load your environment from a JSON file:
  /// ```swift
  /// let url = Bundle.main.url(forResource: "environment", withExtension: "json")!
  /// builder.environment = try! Clerk.Environment(fromFile: url)
  /// ```
  ///
  /// You can also create an environment from JSON string:
  /// ```swift
  /// builder.environment = try! Clerk.Environment(fromJSON: """
  /// {
  ///   "auth_config": {...},
  ///   "display_config": {...},
  ///   "user_settings": {...}
  /// }
  /// """)
  /// ```
  public var environment: Clerk.Environment?

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
  public var client: Client?

  /// Creates a new mock builder.
  ///
  /// All services are pre-initialized with default mock implementations.
  /// You can modify handler properties directly or replace entire services in the configuration closure.
  public init() {}
}

public extension Clerk {
  /// Configures Clerk.shared with mock services and environment.
  ///
  /// This function allows you to inject custom mock services (like `MockClientService`) and configure
  /// environment properties to control behavior without making real API calls. This is useful for SwiftUI previews
  /// and testing scenarios.
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
    // Configure Clerk.shared if not already configured
    let clerk = Clerk.configure(publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk")

    // Create a minimal API client (won't be used if services are mocked)
    let mockBaseURL = URL(string: "https://mock.clerk.accounts.dev")!
    let mockAPIClient = APIClient(baseURL: mockBaseURL)

    // Create mock builder
    let mockBuilder = MockBuilder()
    builder?(mockBuilder)

    // Determine which environment to use: custom from builder, or default .mock
    let mockEnvironment = mockBuilder.environment ?? .mock

    // Determine which client to use: custom from builder, or default .mock
    let mockClient = mockBuilder.client ?? .mock

    // If builder has a custom environment, update the environmentService to return it
    let environmentService: MockEnvironmentService
    if mockBuilder.environment != nil {
      environmentService = MockEnvironmentService {
        mockEnvironment
      }
    } else {
      environmentService = mockBuilder.environmentService
    }

    // If builder has a custom client, update the clientService to return it
    let clientService: MockClientService
    if mockBuilder.client != nil {
      clientService = MockClientService {
        mockClient
      }
    } else {
      clientService = mockBuilder.clientService
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
      clerkService: mockBuilder.clerkService,
      emailAddressService: mockBuilder.emailAddressService,
      phoneNumberService: mockBuilder.phoneNumberService,
      externalAccountService: mockBuilder.externalAccountService
    )

    // Replace dependencies with mock services
    clerk.dependencies = container
    clerk.client = mockClient
    clerk.environment = mockEnvironment

    return clerk
  }
}
