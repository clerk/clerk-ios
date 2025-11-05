//
//  View+PreviewMocks.swift
//  Clerk
//
//  Created on 2025-01-27.
//

#if os(iOS)

import ClerkKit
import SwiftUI

/// Preview test publishable key that decodes to mock.clerk.accounts.dev
/// Used for configuring Clerk.shared in SwiftUI previews.
private let previewTestPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

extension View {
  /// Injects mock environment values for previews.
  ///
  /// This modifier injects mock versions of all Clerk environment observables:
  /// - `Clerk.mock` for `@Environment(Clerk.self)`
  /// - `AuthState()` for `@Environment(AuthState.self)`
  /// - `UserProfileView.SharedState()` for `@Environment(UserProfileView.SharedState.self)`
  ///
  /// Note: `ClerkTheme` has a default value and doesn't need to be injected.
  ///
  /// Usage:
  /// ```swift
  /// #Preview {
  ///     MyView()
  ///         .clerkPreviewMocks()
  /// }
  /// ```
  @MainActor
  public func clerkPreviewMocks(isSignedIn: Bool = true) -> some View {
    // Configure Clerk.shared so views that access it directly don't fail
    let clerk = Clerk.configureWithMocks()
    if !isSignedIn { Task { try? await clerk.signOut() } }

    return
      self
      .environment(clerk)
      .environment(AuthState())
      .environment(UserProfileView.SharedState())
  }

  /// Preview with custom mock service behaviors.
  ///
  /// This modifier allows you to configure mock services (like `Client.get()`) to have custom behaviors
  /// such as delays or custom return values. This is useful for testing loading states and async behavior.
  ///
  /// - Parameter configureServices: A closure that receives a `MockServicesBuilder` for configuring mock services.
  ///
  /// Usage:
  /// ```swift
  /// #Preview {
  ///     MyView()
  ///         .clerkPreviewMocks { builder in
  ///             builder.clientService.getHandler = {
  ///                 try? await Task.sleep(for: .seconds(1))
  ///                 return Client.mock
  ///             }
  ///         }
  /// }
  /// ```
  @MainActor
  public func clerkPreviewMocks(configureServices: @escaping (MockServicesBuilder) -> Void) -> some View {
    // Configure Clerk.shared with mock services (using default preview publishable key)
    Clerk.configureWithMocks(configureServices: configureServices)

    return
      self
      .environment(Clerk.mock)
      .environment(AuthState())
      .environment(UserProfileView.SharedState())
  }
}

#endif
