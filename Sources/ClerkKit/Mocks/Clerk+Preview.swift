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
  /// Defaults to `false`.
  public var isSignedIn: Bool = false

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

    // Apply builder closure
    builder?(previewBuilder)

    // Determine which environment to use: loaded from file, or default .mock
    let mockEnvironment = environment ?? .mock

    // Configure only the services that need custom behavior
    // All other services use their default mock implementations
    let clientService = MockClientService {
      // Determine which client to use based on isSignedIn
      return previewBuilder.isSignedIn ? Client.mock : Client.mockSignedOut
    }

    let environmentService = MockEnvironmentService {
      return mockEnvironment
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
    clerk.client = previewBuilder.isSignedIn ? Client.mock : Client.mockSignedOut
    clerk.environment = mockEnvironment

    return clerk
  }
}
