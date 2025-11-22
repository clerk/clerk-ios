//
//  Clerk+Preview.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Builder for configuring preview-specific settings.
///
/// Use this builder to configure preview behavior, such as whether the user is signed in.
@MainActor
public final class PreviewBuilder {
  /// Whether the user should be signed in for the preview.
  /// Defaults to `true`.
  public var isSignedIn: Bool = true

  /// The environment to use for the preview.
  /// If set, this environment will be used instead of loading from `ClerkEnvironment.json` or the default `.mock` environment.
  ///
  /// Example:
  /// ```swift
  /// Clerk.preview { builder in
  ///   builder.environment = Clerk.Environment.mock
  /// }
  /// ```
  public var environment: Clerk.Environment?

  /// Custom mock client for configuring client properties like sessions and user data.
  /// If set, this client will be used instead of the default client based on `isSignedIn`.
  /// Assign a `Client` instance to configure it.
  ///
  /// Example:
  /// ```swift
  /// Clerk.preview { builder in
  ///   var client = Client.mock
  ///   client.sessions = [Session.mock, Session.mock2]
  ///   builder.client = client
  /// }
  /// ```
  public var client: Client?

  /// Creates a new preview builder.
  public init() {}
}

public extension Clerk {
  /// Configures Clerk for SwiftUI previews with simplified API.
  ///
  /// This method provides a simpler API specifically designed for SwiftUI previews.
  /// It automatically configures all async operations to return mock values immediately,
  /// and allows you to configure whether the user is signed in.
  ///
  /// **Environment Loading:**
  /// This method automatically looks for a `ClerkEnvironment.json` file in the main bundle.
  /// If found, it loads the environment from that file. If not found, or if you set a custom
  /// environment via the `PreviewBuilder`, it uses the provided environment or falls back to `.mock`.
  ///
  /// **Important:** This method only works when running in SwiftUI previews. When used outside of previews,
  /// it returns `Clerk.shared` if already configured, or configures Clerk with an empty publishable key.
  ///
  /// - Parameter preview: An optional closure that receives a `PreviewBuilder` for configuring preview settings.
  ///
  /// Example:
  /// ```swift
  /// #Preview {
  ///   ContentView()
  ///     .environment(Clerk.preview { preview in
  ///       preview.isSignedIn = true
  ///     })
  /// }
  /// ```
  ///
  /// You can also set a custom environment:
  /// ```swift
  /// #Preview {
  ///   ContentView()
  ///     .environment(Clerk.preview { preview in
  ///       preview.isSignedIn = true
  ///       preview.environment = Clerk.Environment.mock
  ///     })
  /// }
  /// ```
  ///
  /// You can customize the client object:
  /// ```swift
  /// #Preview {
  ///   ContentView()
  ///     .environment(Clerk.preview { preview in
  ///       var client = Client.mock
  ///       client.sessions = [Session.mock, Session.mock2]
  ///       preview.client = client
  ///     })
  /// }
  /// ```
  @MainActor
  @discardableResult
  static func preview(
    preview: ((PreviewBuilder) -> Void)? = nil
  ) -> Clerk {
    // Check if running in SwiftUI preview
    guard EnvironmentDetection.isRunningInPreviews else {
      return Clerk.shared
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

    // Apply preview closure
    preview?(previewBuilder)

    // Determine which environment to use: from builder, loaded from file, or default .mock
    let mockEnvironment = previewBuilder.environment ?? environment ?? .mock

    // Determine which client to use: custom from builder, or based on isSignedIn
    let mockClient = previewBuilder.client ?? (previewBuilder.isSignedIn ? Client.mock : Client.mockSignedOut)

    // Configure only the services that need custom behavior
    // All other services use their default mock implementations
    let clientService = MockClientService {
      mockClient
    }

    let environmentService = MockEnvironmentService {
      mockEnvironment
    }

    // Use default mock services for everything else
    let clerkService = MockClerkService()
    let userService = MockUserService()
    let signInService = MockSignInService()
    let signUpService = MockSignUpService()
    let sessionService = MockSessionService()
    let passkeyService = MockPasskeyService()
    let organizationService = MockOrganizationService()
    let emailAddressService = MockEmailAddressService()
    let phoneNumberService = MockPhoneNumberService()
    let externalAccountService = MockExternalAccountService()

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
