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

/// Builder for configuring preview-specific settings.
///
/// Use this builder to configure preview behavior, such as whether the user is signed in.
@MainActor
public final class PreviewBuilder {
  /// Whether the user should be signed in for the preview.
  /// Defaults to `true`.
  public var isSignedIn: Bool = true

  /// Creates a new preview builder.
  public init() {}
}

public extension Clerk {
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
  package static func configureWithMocks(
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
    #else
    // In release builds, return Clerk.shared
    return Clerk.shared
    #endif
  }

  /// Configures Clerk for SwiftUI previews with simplified API.
  ///
  /// This method provides a simpler API specifically designed for SwiftUI previews.
  /// It automatically configures all async operations to sleep for 1 second and return mock values,
  /// and allows you to configure whether the user is signed in.
  ///
  /// **Important:** This method only works when running in SwiftUI previews. When used outside of previews,
  /// it returns `Clerk.shared` if already configured, or configures Clerk with an empty publishable key.
  ///
  /// - Parameter builder: An optional closure that receives a `PreviewBuilder` for configuring preview settings.
  ///
  /// Example:
  /// ```swift
  /// #Preview {
  ///   ContentView()
  ///     .environment(Clerk.preview { builder in
  ///       builder.isSignedIn = false
  ///     })
  /// }
  /// ```
  @MainActor
  @discardableResult
  static func preview(
    builder: ((PreviewBuilder) -> Void)? = nil
  ) -> Clerk {
    // Check if running in SwiftUI preview
    let isRunningInPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    guard isRunningInPreview else {
      // If not in preview, configure with empty key (configure will return existing if already configured)
      return Clerk.configure(publishableKey: "")
    }

    // Configure Clerk.shared if not already configured
    let clerk = Clerk.configure(publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk")

    // Create a minimal API client (won't be used if services are mocked)
    let mockBaseURL = URL(string: "https://mock.clerk.accounts.dev")!
    let mockAPIClient = APIClient(baseURL: mockBaseURL)

    // Create preview builder
    let previewBuilder = PreviewBuilder()

    // Try to load ClerkEnvironment.json from bundle, fall back to .mock if it fails
    var environment: Clerk.Environment?
    if let url = Bundle.main.url(forResource: "ClerkEnvironment", withExtension: "json"),
      let loadedEnvironment = try? Clerk.Environment(fromFile: url)
    {
      environment = loadedEnvironment
    }

    // Apply builder closure
    builder?(previewBuilder)

    // Determine which environment to use: loaded from file, or default .mock
    let mockEnvironment = environment ?? .mock

    // Determine which client to use based on isSignedIn
    let mockClient = previewBuilder.isSignedIn ? Client.mock : Client.mockSignedOut

    // Configure all mock services with 1 second delay and mock return values
    let clientService = MockClientService {
      try? await Task.sleep(for: .seconds(1))
      return mockClient
    }

    let environmentService = MockEnvironmentService {
      try? await Task.sleep(for: .seconds(1))
      return mockEnvironment
    }

    let userService = MockUserService(
      getSessions: { _ in
        try? await Task.sleep(for: .seconds(1))
        return [.mock, .mock2]
      },
      reload: {
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      update: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      createBackupCodes: {
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      createEmailAddress: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      createPhoneNumber: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      createExternalAccount: { _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mockVerified
      },
      createExternalAccountToken: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mockVerified
      },
      createTotp: {
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      verifyTotp: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      disableTotp: {
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      getOrganizationInvitations: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
      },
      getOrganizationMemberships: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
      },
      getOrganizationSuggestions: { _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
      },
      updatePassword: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      setProfileImage: { _ in
        try? await Task.sleep(for: .seconds(1))
        return ImageResource(id: "mock-image-id", name: "mock-image", publicUrl: nil)
      },
      deleteProfileImage: {
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      delete: {
        try? await Task.sleep(for: .seconds(1))
        return .mock
      }
    )

    #if canImport(AuthenticationServices) && !os(watchOS)
    userService.setCreatePasskey {
      try? await Task.sleep(for: .seconds(1))
      return .mock
    }
    #endif

    let signInService = MockSignInService(
      create: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      createWithParams: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      resetPassword: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      prepareFirstFactor: { _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      attemptFirstFactor: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      prepareSecondFactor: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      attemptSecondFactor: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      get: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      }
    )

    #if !os(tvOS) && !os(watchOS)
    signInService.setAuthenticateWithRedirect { (strategy: SignIn.AuthenticateWithRedirectStrategy, _: Bool) in
      try? await Task.sleep(for: .seconds(1))
      return .signIn(.mock)
    }
    #endif

    #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
    signInService.setGetCredentialForPasskey { _, _, _ in
      try? await Task.sleep(for: .seconds(1))
      return "mock-credential"
    }
    signInService.setAuthenticateWithIdToken { _, _ in
      try? await Task.sleep(for: .seconds(1))
      return .signIn(.mock)
    }
    #endif

    let signUpService = MockSignUpService(
      create: { _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      createWithParams: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      update: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      prepareVerification: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      attemptVerification: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      get: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      }
    )

    #if !os(tvOS) && !os(watchOS)
    signUpService.setAuthenticateWithRedirect { (strategy: SignUp.AuthenticateWithRedirectStrategy, _: Bool) in
      try? await Task.sleep(for: .seconds(1))
      return .signUp(.mock)
    }
    #endif

    #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
    signUpService.setAuthenticateWithIdToken { _, _ in
      try? await Task.sleep(for: .seconds(1))
      return .signUp(.mock)
    }
    #endif

    let sessionService = MockSessionService { _ in
      try? await Task.sleep(for: .seconds(1))
      return .mock
    }

    let passkeyService = MockPasskeyService(
      create: {
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      update: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      attemptVerification: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      delete: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      }
    )

    let organizationService = MockOrganizationService(
      updateOrganization: { _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      destroyOrganization: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      setOrganizationLogo: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      getOrganizationRoles: { _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
      },
      getOrganizationMemberships: { _, _, _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
      },
      addOrganizationMember: { _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mockWithUserData
      },
      updateOrganizationMember: { _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mockWithUserData
      },
      removeOrganizationMember: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mockWithUserData
      },
      getOrganizationInvitations: { _, _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
      },
      inviteOrganizationMember: { _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      createOrganizationDomain: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      getOrganizationDomains: { _, _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
      },
      getOrganizationDomain: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      getOrganizationMembershipRequests: { _, _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
      },
      deleteOrganizationDomain: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      prepareOrganizationDomainAffiliationVerification: { _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      attemptOrganizationDomainAffiliationVerification: { _, _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      revokeOrganizationInvitation: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      destroyOrganizationMembership: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mockWithUserData
      },
      acceptUserOrganizationInvitation: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      acceptOrganizationSuggestion: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      acceptOrganizationMembershipRequest: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      rejectOrganizationMembershipRequest: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      }
    )

    let clerkService = MockClerkService(
      signOut: { _ in
        try? await Task.sleep(for: .seconds(1))
        clerk.client = .mockSignedOut
      },
      setActive: { _, _ in
        try? await Task.sleep(for: .seconds(1))
      }
    )

    let emailAddressService = MockEmailAddressService(
      create: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      prepareVerification: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      attemptVerification: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      destroy: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      }
    )

    let phoneNumberService = MockPhoneNumberService(
      create: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      delete: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      prepareVerification: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      attemptVerification: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      makeDefaultSecondFactor: { _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      },
      setReservedForSecondFactor: { _, _ in
        try? await Task.sleep(for: .seconds(1))
        return .mock
      }
    )

    let externalAccountService = MockExternalAccountService { _ in
      try? await Task.sleep(for: .seconds(1))
      return .mock
    }

    // Create mock dependency container with mock services
    let container = MockDependencyContainer(
      apiClient: mockAPIClient,
      clientService: clientService,
      userService: userService,
      signInService: signInService,
      signUpService: signUpService,
      sessionService: sessionService,
      passkeyService: passkeyService,
      organizationService: organizationService,
      environmentService: environmentService,
      clerkService: clerkService,
      emailAddressService: emailAddressService,
      phoneNumberService: phoneNumberService,
      externalAccountService: externalAccountService
    )

    // Replace dependencies with mock services
    clerk.dependencies = container
    clerk.client = mockClient
    clerk.environment = mockEnvironment

    return clerk
  }
}
