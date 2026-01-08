//
//  View+ImagePrefetching.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

private struct ClerkImagePrefetchingModifier: ViewModifier {
  @Environment(Clerk.self) private var clerk

  func body(content: Content) -> some View {
    content
      .task(id: clerk.environment) {
        if clerk.environment != nil {
          ClerkImagePrefetcher.prefetchImages()
        }
      }
  }
}

public extension View {
  /// Prefetches ClerkKitUI images when the Clerk environment loads.
  func clerkImagePrefetching() -> some View {
    modifier(ClerkImagePrefetchingModifier())
  }
}

#endif
