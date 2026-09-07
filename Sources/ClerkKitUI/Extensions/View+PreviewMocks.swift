//
//  View+PreviewMocks.swift
//  Clerk
//
//  Created on 2025-01-27.
//

#if os(iOS) || os(macOS)

import ClerkJSCore
import ClerkKit
import SwiftUI

extension View {
  /// Injects mock environment values for previews.
  ///
  /// This modifier injects mock versions of all Clerk environment observables:
  /// - `ClerkKit.Clerk.preview` for `@Environment(Clerk.self)`
  /// - A snapshot-backed runtime for ClerkKitUI auth views
  /// - `AuthState()` for `@Environment(AuthState.self)`
  /// - `AuthNavigation()` for `@Environment(AuthNavigation.self)`
  /// - `CodeLimiter()` for `@Environment(CodeLimiter.self)`
  /// - `UserProfileSheetNavigation()` for `@Environment(UserProfileSheetNavigation.self)`
  /// - `OrganizationSheetNavigation()` for `@Environment(OrganizationSheetNavigation.self)`
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
  public func clerkPreview(isSignedIn: Bool = true) -> some View {
    if EnvironmentDetection.isRunningInPreviews {
      // Configure Clerk.shared so views that access it directly don't fail
      let clerk = ClerkKit.Clerk.preview { builder in
        builder.isSignedIn = isSignedIn
      }
      let runtime = jsCorePreviewClerk(isSignedIn: isSignedIn)
      ClerkRuntimeStore.register(runtime, for: clerk.publishableKey, alreadyLoaded: true)
      ClerkRuntimeStore.publish(runtime, onto: clerk)

      return AnyView(
        environment(clerk)
          .environment(runtime)
          .environment(CodeLimiter())
          .environment(UserProfileSheetNavigation())
          .environment(AuthState())
          .environment(AuthNavigation())
      )
    }
    return AnyView(self)
  }
}

@MainActor
private func jsCorePreviewClerk(isSignedIn: Bool) -> ClerkJSCore.Clerk {
  let clerk = ClerkJSCore.Clerk(publishableKey: "pk_test_preview")
  if let environment = try? ClerkJSCore.Clerk.snapshotEnvironment() {
    clerk.publishEnvironment(environment)
  }
  if isSignedIn, let data = try? ClerkJSCore.Clerk.snapshotSignedInClient() {
    try? clerk.publishClient(data)
  }
  return clerk
}

#endif
