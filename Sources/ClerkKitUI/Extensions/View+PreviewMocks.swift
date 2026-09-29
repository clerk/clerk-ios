//
//  View+PreviewMocks.swift
//  Clerk
//
//  Created on 2025-01-27.
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

extension View {
  @MainActor
  package func clerkPreview(isSignedIn: Bool = true) -> some View {
    if EnvironmentDetection.isRunningInPreviews {
      // Configure Clerk.shared so views that access it directly don't fail
      let clerk = Clerk.preview { builder in
        builder.isSignedIn = isSignedIn
      }

      return AnyView(
        environment(clerk)
          .environment(CodeLimiter())
          .environment(UserProfileSheetNavigation())
          .environment(AuthState())
          .environment(AuthNavigation())
      )
    }
    return AnyView(self)
  }
}

#endif
