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

  /// Mock environment service for customizing `Environment.get()` behavior.
  /// Assign a `MockEnvironmentService` instance to configure it.
  public var environmentService: MockEnvironmentService?

  /// Mock user service for customizing `User` service methods behavior.
  /// Assign a `MockUserService` instance to configure it.
  public var userService: MockUserService?

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
  ///   - configureServices: A closure that receives a `MockServicesBuilder` for configuring mock services.
  ///
  /// Example:
  /// ```swift
  /// #Preview {
  ///   Clerk.configureWithMocks { builder in
  ///     builder.clientService = MockClientService {
  ///       try? await Task.sleep(for: .seconds(1))
  ///       return Client.mock
  ///     }
  ///
  ///     builder.userService = MockUserService(
  ///       getSessions: { user in
  ///         try? await Task.sleep(for: .seconds(1))
  ///         return [Session.mock, Session.mock2]
  ///       }
  ///     )
  ///   }
  ///
  ///   MyView()
  ///     .clerkPreviewMocks()
  /// }
  /// ```
  @MainActor
  @discardableResult
  public static func configureWithMocks(
    publishableKey: String = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk",
    configureServices: (MockServicesBuilder) -> Void
  ) -> Clerk {
    // Configure Clerk.shared if not already configured
    Clerk.configure(publishableKey: publishableKey)

    // Create a minimal API client (won't be used if services are mocked)
    let mockBaseURL = URL(string: "https://mock.clerk.accounts.dev")!
    let mockAPIClient = APIClient(baseURL: mockBaseURL)

    // Create mock services builder
    let builder = MockServicesBuilder()
    configureServices(builder)

    // Create mock dependency container with mock services (only pass configured ones)
    let container = MockDependencyContainer(
      apiClient: mockAPIClient,
      clientService: builder.clientService,
      userService: builder.userService,
      environmentService: builder.environmentService
    )

    // Replace Clerk.shared dependencies with mock services
    Clerk.shared.dependencies = container

    return Clerk.shared
  }
}

