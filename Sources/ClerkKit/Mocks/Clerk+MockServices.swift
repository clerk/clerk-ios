//
//  Clerk+MockServices.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Builder for configuring mock services in previews and tests.
///
/// Use this builder to configure custom behaviors for service methods.
/// You can create and assign mock services inline in the preview closure.
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
/// ```
@MainActor
public final class MockServicesBuilder {
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

  /// Creates a new mock services builder.
  ///
  /// Services are not pre-initialized. Assign them in the configuration closure
  /// to only configure the services you need.
  public init() {}
}

extension Clerk {
  /// Configures Clerk.shared with mock services.
  ///
  /// This function allows you to inject custom mock services (like `MockClientService`) to control
  /// the behavior of service methods without making real API calls. This is useful for SwiftUI previews
  /// and testing scenarios.
  ///
  /// - Parameters:
  ///   - publishableKey: The publishable key to use for configuration. Defaults to a mock key.
  ///   - configureServices: An optional closure that receives a `MockServicesBuilder` for configuring mock services.
  ///                        If not provided, all services will use their default mock implementations.
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
  /// ```
  @MainActor
  @discardableResult
  public static func configureWithMocks(
    publishableKey: String = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk",
    configureServices: ((MockServicesBuilder) -> Void)? = nil
  ) -> Clerk {
    // Configure Clerk.shared if not already configured
    var clerk = Clerk.configure(publishableKey: publishableKey)

    // Create a minimal API client (won't be used if services are mocked)
    let mockBaseURL = URL(string: "https://mock.clerk.accounts.dev")!
    let mockAPIClient = APIClient(baseURL: mockBaseURL)

    // Create mock services builder
    let builder = MockServicesBuilder()
    configureServices?(builder)

    // Create mock dependency container with mock services (only pass configured ones)
    let container = MockDependencyContainer(
      apiClient: mockAPIClient,
      clientService: builder.clientService,
      userService: builder.userService,
      signInService: builder.signInService,
      signUpService: builder.signUpService,
      sessionService: builder.sessionService,
      passkeyService: builder.passkeyService,
      organizationService: builder.organizationService,
      environmentService: builder.environmentService,
      clerkService: builder.clerkService,
      emailAddressService: builder.emailAddressService,
      phoneNumberService: builder.phoneNumberService,
      externalAccountService: builder.externalAccountService
    )

    // Replace dependencies with mock services
    clerk.dependencies = container
    clerk.client = .mock
    clerk.environment = .mock

    return clerk
  }
}

