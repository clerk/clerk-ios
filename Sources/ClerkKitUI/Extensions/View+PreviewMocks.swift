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
    if signedOut {
      self
        .environment(Clerk.mockSignedOut)
        .environment(AuthState())
        .environment(UserProfileView.SharedState())
    } else {
      clerkPreviewMocks()
    }
  }

  /// Preview with custom user.
  ///
  /// - Parameter user: The user to inject into the preview environment.
  ///
  /// Usage:
  /// ```swift
  /// #Preview("Custom User") {
  ///     var user = User.mock
  ///     user.firstName = "Alice"
  ///
  ///     UserProfileView()
  ///         .clerkPreviewMocks(user: user)
  /// }
  /// ```
  @MainActor
  public func clerkPreviewMocks(user: User) -> some View {
    var clerk = Clerk.mock
    clerk.client = Client.mock
    if var client = clerk.client {
      var session = Session.mock
      session.user = user
      client.sessions = [session]
      clerk.client = client
    }

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
  ///             clerk.client = Client.mockSignedOut
  ///         }
  /// }
  /// ```
  @MainActor
  public func clerkPreviewMocks(customize: @escaping (inout Clerk) -> Void) -> some View {
    var clerk = Clerk.mock
    customize(&clerk)

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

