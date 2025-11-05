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
  public func clerkPreviewMocks() -> some View {
    // Configure Clerk.shared so views that access it directly don't fail
    Clerk.configure(publishableKey: previewTestPublishableKey)

    return self
      .environment(Clerk.mock)
      .environment(AuthState())
      .environment(UserProfileView.SharedState())
  }

  /// Preview with signed-out state.
  ///
  /// - Parameter signedOut: If `true`, injects `Clerk.mockSignedOut` instead of `Clerk.mock`.
  ///
  /// Usage:
  /// ```swift
  /// #Preview("Signed Out") {
  ///     AuthView()
  ///         .clerkPreviewMocks(signedOut: true)
  /// }
  /// ```
  @MainActor
  public func clerkPreviewMocks(signedOut: Bool) -> some View {
    // Configure Clerk.shared so views that access it directly don't fail
    Clerk.configure(publishableKey: previewTestPublishableKey)

    let clerk = signedOut ? Clerk.mockSignedOut : Clerk.mock
    return
      self
      .environment(clerk)
      .environment(AuthState())
      .environment(UserProfileView.SharedState())
  }

  /// Preview with custom Clerk instance.
  ///
  /// - Parameter customize: A closure that customizes the Clerk instance.
  ///
  /// Usage:
  /// ```swift
  /// #Preview {
  ///     AuthView()
  ///         .clerkPreviewMocks { clerk in
  ///             // Customize clerk properties that are accessible from ClerkKitUI
  ///         }
  /// }
  /// ```
  // @MainActor
  // public func clerkPreviewMocks(customize: @escaping (inout Clerk) -> Void) -> some View {
  //   // Configure Clerk.shared so views that access it directly don't fail
  //   Clerk.configure(publishableKey: previewTestPublishableKey)

  //   var clerk = Clerk.mock
  //   customize(&clerk)
  //   return
  //     self
  //     .environment(clerk)
  //     .environment(AuthState())
  //     .environment(UserProfileView.SharedState())
  // }

  /// Preview with custom Clerk instance.
  ///
  /// - Parameter clerk: The Clerk instance to inject into the preview environment.
  ///
  /// Usage:
  /// ```swift
  /// #Preview {
  ///     let customClerk = Clerk.mock
  ///     // customize clerk...
  ///
  ///     MyView()
  ///         .clerkPreviewMocks(customClerk)
  /// }
  /// ```
  @MainActor
  public func clerkPreviewMocks(_ clerk: Clerk) -> some View {
    // Configure Clerk.shared so views that access it directly don't fail
    Clerk.configure(publishableKey: previewTestPublishableKey)

    return self
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

    return self
      .environment(Clerk.mock)
      .environment(AuthState())
      .environment(UserProfileView.SharedState())
  }
}

#endif
