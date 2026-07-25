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

  package var services: MockServicesBuilder = .init()

  /// Creates a new preview builder.
  public init() {}
}

extension Clerk {
  private static let previewPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

  /// Configures Clerk for SwiftUI previews with simplified API.
  ///
  /// This method provides a simpler API specifically designed for SwiftUI previews.
  /// It automatically configures all async operations to return mock values immediately,
  /// and allows you to configure whether the user is signed in.
  ///
  /// Advanced service customization is available only within this package.
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
  public static func preview(
    preview: ((PreviewBuilder) -> Void)? = nil
  ) -> Clerk {
    guard EnvironmentDetection.isRunningInPreviews else {
      return Clerk.shared
    }

    return makePreview(preview: preview)
  }

  @MainActor
  static func makePreview(
    preview: ((PreviewBuilder) -> Void)? = nil,
    installAsShared: Bool = true
  ) -> Clerk {
    let previewBuilder = PreviewBuilder()
    preview?(previewBuilder)

    let loadedEnvironment = loadEnvironmentFromBundle()
    let mockEnvironment = previewBuilder.environment ?? loadedEnvironment ?? .mock
    let mockClient = previewBuilder.client ?? (previewBuilder.isSignedIn ? Client.mock : Client.mockSignedOut)

    if previewBuilder.services.clientService.getHandler == nil {
      previewBuilder.services.clientService.getHandler = { mockClient }
    }
    if previewBuilder.services.environmentService.getHandler == nil {
      previewBuilder.services.environmentService.getHandler = { mockEnvironment }
    }

    let makeDependencies: (Clerk) -> any Dependencies = { clerk in
      guard let mockBaseURL = URL(string: "https://mock.clerk.accounts.dev") else {
        fatalError("Clerk preview URL is invalid.")
      }
      let mockAPIClient = APIClient(
        baseURL: mockBaseURL,
        runtimeScope: clerk.runtimeScope
      )
      let container = createMockDependencyContainer(
        apiClient: mockAPIClient,
        services: previewBuilder.services
      )
      do {
        try container.configurationManager.configure(
          publishableKey: previewPublishableKey,
          options: .init()
        )
      } catch {
        assertionFailure(
          "Failed to configure Clerk preview dependencies: \(error.localizedDescription)"
        )
      }
      return container
    }
    let clerk: Clerk
    if installAsShared {
      clerk = configureForPreview(dependencies: makeDependencies)
    } else {
      clerk = Clerk()
      clerk.dependencies = makeDependencies(clerk)
    }

    clerk.setClientFromIdentityController(mockClient)
    clerk.environment = mockEnvironment

    return clerk
  }

  /// Loads the Clerk environment from ClerkEnvironment.json in the main bundle.
  @MainActor
  private static func loadEnvironmentFromBundle() -> Clerk.Environment? {
    guard let url = Bundle.main.url(forResource: "ClerkEnvironment", withExtension: "json"),
          let loadedEnvironment = try? Clerk.Environment(fromFile: url)
    else {
      return nil
    }
    return loadedEnvironment
  }

  /// Creates a mock dependency container with all mock services configured.
  @MainActor
  private static func createMockDependencyContainer(
    apiClient: APIClient,
    services: MockServicesBuilder
  ) -> MockDependencyContainer {
    // Use the services from the builder directly - this allows users to customize
    // individual service behaviors (like adding delays for loading states).
    MockDependencyContainer(
      apiClient: apiClient,
      clientService: services.clientService,
      userService: services.userService,
      signInService: services.signInService,
      signUpService: services.signUpService,
      sessionService: services.sessionService,
      passkeyService: services.passkeyService,
      organizationService: services.organizationService,
      environmentService: services.environmentService,
      emailAddressService: services.emailAddressService,
      phoneNumberService: services.phoneNumberService,
      externalAccountService: services.externalAccountService
    )
  }
}
