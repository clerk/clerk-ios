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
}

#endif

