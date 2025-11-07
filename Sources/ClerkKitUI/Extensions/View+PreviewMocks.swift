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

package extension View {
  /// Injects mock environment values for previews.
  ///
  /// This modifier injects mock versions of all Clerk environment observables:
  /// - `Clerk.mock` for `@Environment(Clerk.self)`
  /// - `AuthState()` for `@Environment(AuthState.self)`
  /// - `UserProfileView.SharedState()` for `@Environment(UserProfileView.SharedState.self)`
  ///
  /// Note: `ClerkTheme` has a default value and doesn't need to be injected.
  ///
  /// **Important:** This modifier only works when running in SwiftUI previews. When used outside of previews,
  /// it returns the view unchanged without applying any mock configuration.
  ///
  /// Usage:
  /// ```swift
  /// #Preview {
  ///     MyView()
  ///         .clerkPreview()
  /// }
  /// ```
  @MainActor
  func clerkPreview(isSignedIn: Bool = true) -> some View {
    if PreviewUtils.isRunningInPreview {
      // Configure Clerk.shared so views that access it directly don't fail
      let clerk = Clerk.preview { builder in
        builder.isSignedIn = isSignedIn
      }

      return AnyView(
        environment(clerk)
          .environment(AuthState())
          .environment(UserProfileView.SharedState())
      )
    }
    return AnyView(self)
  }

  /// Preview with custom mock service behaviors.
  ///
  /// This modifier allows you to configure mock services (like `Client.get()`) to have custom behaviors
  /// such as delays or custom return values. This is useful for testing loading states and async behavior.
  ///
  /// - Parameter configureServices: A closure that receives a `MockBuilder` for configuring mock services.
  ///
  /// **Important:** This modifier only works when running in SwiftUI previews. When used outside of previews,
  /// it returns the view unchanged without applying any mock configuration.
  ///
  /// Usage:
  /// ```swift
  /// #Preview {
  ///     MyView()
  ///         .clerkPreview { builder in
  ///             builder.clientService = MockClientService {
  ///                 try? await Task.sleep(for: .seconds(1))
  ///                 return Client.mock
  ///             }
  ///         }
  /// }
  /// ```
  @MainActor
  func clerkPreview(preview: @escaping (MockBuilder) -> Void) -> some View {
    if PreviewUtils.isRunningInPreview {
      // Configure Clerk.shared with mock services (using default preview publishable key)
      // Note: This still uses configureWithMocks internally for advanced customization
      let clerk = Clerk.configureWithMocks { builder in
        // Allow user's closure to override or further configure
        preview(builder)
      }

      return AnyView(
        environment(clerk)
          .environment(AuthState())
          .environment(UserProfileView.SharedState())
      )
    }
    return AnyView(self)
  }
}

#endif
