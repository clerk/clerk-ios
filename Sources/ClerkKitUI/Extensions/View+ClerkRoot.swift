//
//  View+ClerkRoot.swift
//  Clerk
//

#if os(iOS)

import SwiftUI

private struct ClerkRootViewModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .prefetchClerkImages()
      .clerkForceUpdateOverlay()
  }
}

extension View {
  /// Applies ClerkKitUI global behaviors to the app root.
  ///
  /// Add this once to your root content view before injecting `Clerk.shared`.
  public func clerkRootView() -> some View {
    modifier(ClerkRootViewModifier())
  }
}

#endif
