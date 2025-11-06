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
/// You can create and assign mock services and customize environment settings inline in the preview closure.
///
/// Example:
/// ```swift
/// builder.clientService = MockClientService {
///   try? await Task.sleep(for: .seconds(1))
///   return Client.mock
/// }
///
/// builder.userService = MockUserService(
///   getSessions: { user in
///     try? await Task.sleep(for: .seconds(1))
///     return [Session.mock, Session.mock2]
///   }
/// )
///
/// // Customize environment properties like application name
/// var env = Clerk.Environment.mock
/// if var displayConfig = env.displayConfig {
///   displayConfig.applicationName = "My App"
///   displayConfig.supportEmail = "support@myapp.com"
///   env.displayConfig = displayConfig
/// }
/// builder.environment = env
///
/// // Customize client properties like sessions
/// var client = Client.mock
/// client.sessions = [Session.mock, Session.mock2]
/// builder.client = client
/// ```
@MainActor
public final class MockBuilder {
  /// Mock client service for customizing `Client.get()` behavior.
  /// Assign a `MockClientService` instance to configure it.
  public var clientService: MockClientService?

  /// Mock user service for customizing `User` service methods behavior.
  /// Assign a `MockUserService` instance to configure it.
  public var userService: MockUserService?

  /// Mock sign-in service for customizing sign-in behavior.
  /// Assign a `MockSignInService` instance to configure it.
  public var signInService: MockSignInService?

  /// Mock sign-up service for customizing sign-up behavior.
  /// Assign a `MockSignUpService` instance to configure it.
  public var signUpService: MockSignUpService?

  /// Mock session service for customizing session behavior.
  /// Assign a `MockSessionService` instance to configure it.
  public var sessionService: MockSessionService?

  /// Mock passkey service for customizing passkey behavior.
  /// Assign a `MockPasskeyService` instance to configure it.
  public var passkeyService: MockPasskeyService?

  /// Mock organization service for customizing organization behavior.
  /// Assign a `MockOrganizationService` instance to configure it.
  public var organizationService: MockOrganizationService?

  /// Mock environment service for customizing `Environment.get()` behavior.
  /// Assign a `MockEnvironmentService` instance to configure it.
  public var environmentService: MockEnvironmentService?

  /// Mock clerk service for customizing clerk operations.
  /// Assign a `MockClerkService` instance to configure it.
  public var clerkService: MockClerkService?

  /// Mock email address service for customizing email address behavior.
  /// Assign a `MockEmailAddressService` instance to configure it.
  public var emailAddressService: MockEmailAddressService?

  /// Mock phone number service for customizing phone number behavior.
  /// Assign a `MockPhoneNumberService` instance to configure it.
  public var phoneNumberService: MockPhoneNumberService?

  /// Mock external account service for customizing external account behavior.
  /// Assign a `MockExternalAccountService` instance to configure it.
  public var externalAccountService: MockExternalAccountService?

  /// Custom mock environment for configuring environment properties like application name.
  /// If set, this environment will be used instead of the default `.mock` environment.
  /// Assign a `Clerk.Environment` instance to configure it.
  ///
  /// Example:
  /// ```swift
  /// var env = Clerk.Environment.mock
  /// if var displayConfig = env.displayConfig {
  ///   displayConfig.applicationName = "My App"
  ///   displayConfig.supportEmail = "support@myapp.com"
  ///   env.displayConfig = displayConfig
  /// }
  /// builder.environment = env
  /// ```
  ///
  /// You can also create an environment from a real API response JSON:
  /// ```swift
  /// builder.environment = try! Clerk.Environment(fromJSON: """
  /// {
  ///   "auth_config": {...},
  ///   "display_config": {...},
  ///   "user_settings": {...}
  /// }
  /// """)
  /// ```
  ///
  /// Or load from a JSON file:
  /// ```swift
  /// let url = Bundle.main.url(forResource: "environment", withExtension: "json")!
  /// builder.environment = try! Clerk.Environment(fromFile: url)
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
  /// Services, environment, and client are not pre-initialized. Assign them in the configuration closure
  /// to only configure what you need.
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
  ///   - publishableKey: The publishable key to use for configuration. Defaults to a mock key.
  ///   - configureServices: An optional closure that receives a `MockBuilder` for configuring mock services, environment, and client.
  ///                        If not provided, all services, environment, and client will use their default mock implementations.
  ///
  /// Example:
  /// ```swift
  /// // Use default mock services
  /// Clerk.configureWithMocks()
  ///
  /// // Or customize specific services
  /// Clerk.configureWithMocks { builder in
  ///   builder.clientService = MockClientService {
  ///     try? await Task.sleep(for: .seconds(1))
  ///     return Client.mock
  ///   }
  ///
  ///   builder.userService = MockUserService(
  ///     getSessions: { user in
  ///       try? await Task.sleep(for: .seconds(1))
  ///       return [Session.mock, Session.mock2]
  ///     }
  ///   )
  /// }
  ///
  /// // Customize environment properties for previews
  /// Clerk.configureWithMocks { builder in
  ///   var env = Clerk.Environment.mock
  ///   if var displayConfig = env.displayConfig {
  ///     displayConfig.applicationName = "My App"
  ///     displayConfig.supportEmail = "support@myapp.com"
  ///     displayConfig.logoImageUrl = "https://example.com/logo.png"
  ///     env.displayConfig = displayConfig
  ///   }
  ///   builder.environment = env
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
  ///     var env = Clerk.Environment.mock
  ///     if var displayConfig = env.displayConfig {
  ///       displayConfig.applicationName = "My App"
  ///       env.displayConfig = displayConfig
  ///     }
  ///     builder.environment = env
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
    publishableKey: String = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk",
    configureServices: ((MockBuilder) -> Void)? = nil
  ) -> Clerk {
    // Configure Clerk.shared if not already configured
    let clerk = Clerk.configure(publishableKey: publishableKey)

    // Create a minimal API client (won't be used if services are mocked)
    let mockBaseURL = URL(string: "https://mock.clerk.accounts.dev")!
    let mockAPIClient = APIClient(baseURL: mockBaseURL)

    // Create mock builder
    let builder = MockBuilder()
    configureServices?(builder)

    // Determine which environment to use: custom from builder, or default .mock
    let mockEnvironment = builder.environment ?? .mock

    // Determine which client to use: custom from builder, or default .mock
    let mockClient = builder.client ?? .mock

    // If builder has a custom environment but no custom environmentService,
    // create a MockEnvironmentService that returns the custom environment
    let environmentService: MockEnvironmentService?
    if builder.environment != nil && builder.environmentService == nil {
      environmentService = MockEnvironmentService {
        mockEnvironment
      }
    } else {
      environmentService = builder.environmentService
    }

    // If builder has a custom client but no custom clientService,
    // create a MockClientService that returns the custom client
    let clientService: MockClientService?
    if builder.client != nil && builder.clientService == nil {
      clientService = MockClientService {
        mockClient
      }
    } else {
      clientService = builder.clientService
    }

    // Create mock dependency container with mock services (only pass configured ones)
    let container = MockDependencyContainer(
      apiClient: mockAPIClient,
      clientService: clientService,
      userService: builder.userService,
      signInService: builder.signInService,
      signUpService: builder.signUpService,
      sessionService: builder.sessionService,
      passkeyService: builder.passkeyService,
      organizationService: builder.organizationService,
      environmentService: environmentService,
      clerkService: builder.clerkService,
      emailAddressService: builder.emailAddressService,
      phoneNumberService: builder.phoneNumberService,
      externalAccountService: builder.externalAccountService
    )

    // Replace dependencies with mock services
    clerk.dependencies = container
    clerk.client = mockClient
    clerk.environment = mockEnvironment

    return clerk
  }
}
