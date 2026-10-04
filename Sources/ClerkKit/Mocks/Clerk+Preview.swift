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

  package var transport = FakeTransport.mockDefaults()

  /// Creates a new preview builder.
  public init() {}
}

extension Clerk {
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

    let clerk = Clerk.configure(publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk")

    // Create a minimal API client (won't be used if services are mocked)
    let mockBaseURL = URL(string: "https://mock.clerk.accounts.dev")!
    let mockAPIClient = APIClient(baseURL: mockBaseURL, runtimeScope: clerk.runtimeScope)

    let previewBuilder = PreviewBuilder()
    preview?(previewBuilder)

    let loadedEnvironment = loadEnvironmentFromBundle()
    let mockEnvironment = previewBuilder.environment ?? loadedEnvironment ?? .mock
    let mockClient = previewBuilder.client ?? (previewBuilder.isSignedIn ? Client.mock : Client.mockSignedOut)

    previewBuilder.transport.fallback(ClientAPI.get(), returning: ClientResponse(response: mockClient, client: nil))
    previewBuilder.transport.fallback(EnvironmentAPI.get(), returning: mockEnvironment)

    let container = createMockDependencyContainer(
      apiClient: mockAPIClient,
      transport: previewBuilder.transport,
      services: previewBuilder.services
    )

    clerk.dependencies = container
    clerk.setClientFromIdentityController(mockClient)
    clerk.environment = mockEnvironment

    return clerk
  }

  @MainActor
  private static func loadEnvironmentFromBundle() -> Clerk.Environment? {
    guard let url = Bundle.main.url(forResource: "ClerkEnvironment", withExtension: "json"),
          let loadedEnvironment = try? Clerk.Environment(fromFile: url)
    else {
      return nil
    }
    return loadedEnvironment
  }

  @MainActor
  private static func createMockDependencyContainer(
    apiClient: APIClient,
    transport: FakeTransport,
    services: MockServicesBuilder
  ) -> MockDependencyContainer {
    MockDependencyContainer(
      apiClient: apiClient,
      transport: transport,
      organizationService: services.organizationService,
      billingService: services.billingService
    )
  }
}
