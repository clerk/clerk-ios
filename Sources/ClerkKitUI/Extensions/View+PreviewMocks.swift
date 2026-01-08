//
//  View+PreviewMocks.swift
//  Clerk
//
//  Created on 2025-01-27.
//

#if os(iOS)

import ClerkKit
import SwiftUI

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
    if EnvironmentDetection.isRunningInPreviews {
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
}

#endif
