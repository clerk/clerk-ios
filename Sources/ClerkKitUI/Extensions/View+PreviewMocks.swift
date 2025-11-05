//
//  View+PreviewMocks.swift
//  Clerk
//
//  Created on 2025-01-27.
//

#if os(iOS)

import ClerkKit
import SwiftUI

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
    self
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
  @MainActor
  public func clerkPreviewMocks(customize: @escaping (inout Clerk) -> Void) -> some View {
    var clerk = Clerk.mock
    customize(&clerk)
    return
      self
      .environment(clerk)
      .environment(AuthState())
      .environment(UserProfileView.SharedState())
  }

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
    self
      .environment(clerk)
      .environment(AuthState())
      .environment(UserProfileView.SharedState())
  }
}

#endif
